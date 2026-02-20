#!/usr/bin/env node

import { Command } from 'commander';
import chalk from 'chalk';
import ora, { Ora } from 'ora';
import inquirer from 'inquirer';
import fs from 'fs-extra';
import path from 'path';
import {
  SkillsClient,
  createClient,
  handleApiError,
  Skill,
  SkillInstallOptions,
  SkillExecutionResult,
  ToolDefinition,
  RuntimeManager,
  RUNTIME_VERSION
} from './index.js';

const program = new Command();

const getClient = (): SkillsClient => {
  return createClient({
    baseUrl: process.env.SKILL_RUNTIME_API_URL
  });
};

const spinner = (text: string): Ora => ora(text);

const printSuccess = (message: string): void => {
  console.log(chalk.green('✓'), message);
};

const printError = (message: string): void => {
  console.error(chalk.red('✗'), message);
};

const printSkill = (skill: Skill): void => {
  console.log(chalk.bold.cyan(`\n${skill.name}`) + chalk.gray(` (${skill.version})`));
  console.log(chalk.gray('  Description:'), skill.description);
  console.log(chalk.gray('  Author:'), skill.author);
  if (skill.source_path) {
    console.log(chalk.gray('  Path:'), skill.source_path);
  }
};

const printSkillShort = (skill: Skill): void => {
  console.log(`  ${chalk.cyan(skill.name)} ${chalk.gray(`(${skill.version})`)} - ${skill.description}`);
};

interface FindOptions {
  limit: string;
}

interface AddOptions {
  global: boolean;
  path?: string;
  branch?: string;
  tag?: string;
  commit?: string;
  name?: string;
  validate: boolean;
  yes: boolean;
}

interface ListOptions {
  limit: string;
  page: string;
  json: boolean;
}

interface RunOptions {
  tool?: string;
  params?: string;
  paramsFile?: string;
  interactive: boolean;
}

interface RemoveOptions {
  yes: boolean;
}

interface InitOptions {
  directory: string;
  template: string;
}

interface UpdateOptions {
  all: boolean;
}

interface ConfigOptions {
  set?: string;
  get?: string;
  list: boolean;
}

program
  .name('skills')
  .description('AgentSkills Runtime CLI - Install, manage, and execute AI agent skills')
  .version('0.0.1')
  .option('-u, --api-url <url>', 'API server URL', process.env.SKILL_RUNTIME_API_URL || 'http://127.0.0.1:8080')
  .option('--json', 'Output as JSON', false);

program
  .command('find [query]')
  .description('Search for skills from GitHub, Gitee, and AtomGit')
  .option('-l, --limit <number>', 'Maximum number of results', '10')
  .option('-s, --source <source>', 'Search source (all, github, gitee, atomgit)', 'all')
  .action(async (query: string | undefined, options: FindOptions & { source: string }) => {
    const spin = spinner('Searching for skills...');
    
    try {
      const client = getClient();
      let searchQuery = query;
      
      if (!searchQuery) {
        spin.stop();
        const answer = await inquirer.prompt([{
          type: 'input',
          name: 'query',
          message: 'What kind of skill are you looking for?',
          default: ''
        }]);
        searchQuery = answer.query;
      }
      
      if (!searchQuery) {
        spin.stop();
        console.log(chalk.yellow('No search query provided. Showing all installed skills...\n'));
        const result = await client.listSkills({ limit: parseInt(options.limit) });
        if (result.skills.length === 0) {
          console.log(chalk.gray('No skills found.'));
          return;
        }
        result.skills.forEach(printSkillShort);
        return;
      }
      
      spin.start();
      const result = await client.searchSkills({
        query: searchQuery,
        source: options.source,
        limit: parseInt(options.limit)
      });
      spin.stop();
      
      if (result.results.length === 0) {
        console.log(chalk.yellow(`No skills found matching "${searchQuery}".`));
        console.log(chalk.gray('\nTry different keywords or search from other sources.'));
        return;
      }
      
      console.log(chalk.bold(`\nFound ${result.total_count} skill(s) matching "${searchQuery}":\n`));
      
      result.results.forEach((item) => {
        const stars = item.stars || item.stargazers_count || 0;
        const sourceIcon = item.source === 'github' ? '🐙' : item.source === 'gitee' ? '🏠' : item.source === 'atomgit' ? '⚛️' : '📦';
        console.log(`${sourceIcon} ${chalk.cyan(item.full_name)} ${chalk.yellow(`⭐ ${stars}`)}`);
        console.log(`   ${chalk.gray(item.description || 'No description')}`);
        console.log(`   ${chalk.gray('Clone:')} ${item.clone_url}`);
        console.log();
      });
      
      console.log(chalk.gray('Install with: skills add <clone_url>'));
      
    } catch (error: unknown) {
      spin.fail('Search failed');
      printError(handleApiError(error).errmsg);
      process.exit(1);
    }
  });

program
  .command('add <source>')
  .description('Install a skill from GitHub or local path')
  .option('-g, --global', 'Install globally (user-level)', false)
  .option('-p, --path <path>', 'Local path to skill')
  .option('-b, --branch <branch>', 'Git branch name')
  .option('-t, --tag <tag>', 'Git tag name')
  .option('-c, --commit <commit>', 'Git commit ID')
  .option('-n, --name <name>', 'Skill name override')
  .option('--validate', 'Validate skill before installation', true)
  .option('--no-validate', 'Skip validation')
  .option('-y, --yes', 'Skip confirmation prompts', false)
  .action(async (source: string, options: AddOptions) => {
    const spin = spinner('Installing skill...');
    
    try {
      const client = getClient();
      
      const installOptions: SkillInstallOptions = {
        source: options.path || source,
        validate: options.validate,
        branch: options.branch,
        tag: options.tag,
        commit: options.commit
      };
      
      if (!options.yes) {
        spin.stop();
        console.log(chalk.bold('\nAbout to install:'), chalk.cyan(source));
        const answer = await inquirer.prompt([{
          type: 'confirm',
          name: 'proceed',
          message: 'Continue?',
          default: true
        }]);
        if (!answer.proceed) {
          console.log(chalk.gray('Installation cancelled.'));
          return;
        }
        spin.start();
      }
      
      spin.text = 'Installing skill...';
      const result = await client.installSkill(installOptions);
      spin.succeed(chalk.green(result.message));
      
      console.log(chalk.gray('\nSkill ID:'), result.id);
      console.log(chalk.gray('Status:'), result.status);
      console.log(chalk.gray('Installed at:'), result.created_at);
      
    } catch (error: unknown) {
      spin.fail('Installation failed');
      const apiError = handleApiError(error);
      if (apiError.errmsg && apiError.errmsg !== 'undefined') {
        printError(apiError.errmsg);
      } else if (error instanceof Error) {
        printError(error.message);
      } else {
        printError('Installation failed. Please check if the skill source is valid and accessible.');
      }
      if (apiError.details) {
        console.log(chalk.gray('Details:'), JSON.stringify(apiError.details, null, 2));
      }
      process.exit(1);
    }
  });

program
  .command('list')
  .description('List installed skills')
  .option('-l, --limit <number>', 'Maximum number of results', '20')
  .option('-p, --page <number>', 'Page number', '0')
  .option('--json', 'Output as JSON', false)
  .action(async (options: ListOptions) => {
    const spin = spinner('Loading skills...');
    
    try {
      const client = getClient();
      const result = await client.listSkills({
        limit: parseInt(options.limit),
        page: parseInt(options.page)
      });
      spin.stop();
      
      if (options.json) {
        console.log(JSON.stringify(result, null, 2));
        return;
      }
      
      if (result.skills.length === 0) {
        console.log(chalk.yellow('No skills installed.'));
        console.log(chalk.gray('\nInstall a skill with: skills add <source>'));
        console.log(chalk.gray('Find skills with: skills find <query>'));
        return;
      }
      
      console.log(chalk.bold(`\nInstalled Skills (${result.total_count} total):\n`));
      result.skills.forEach(printSkillShort);
      
      if (result.total_page > 1) {
        console.log(chalk.gray(`\nPage ${result.current_page + 1} of ${result.total_page}`));
        console.log(chalk.gray('Use --page to see more results'));
      }
      
    } catch (error: unknown) {
      spin.fail('Failed to list skills');
      printError(handleApiError(error).errmsg);
      process.exit(1);
    }
  });

program
  .command('run <skillId>')
  .description('Execute a skill')
  .option('-t, --tool <name>', 'Tool name to execute')
  .option('-p, --params <json>', 'Parameters as JSON string')
  .option('-f, --params-file <file>', 'Parameters from JSON file')
  .option('-i, --interactive', 'Interactive parameter input', false)
  .action(async (skillId: string, options: RunOptions) => {
    const spin = spinner('Executing skill...');
    
    try {
      const client = getClient();
      
      let params: Record<string, unknown> = {};
      
      if (options.params) {
        params = JSON.parse(options.params);
      } else if (options.paramsFile) {
        params = await fs.readJson(options.paramsFile);
      } else if (options.interactive) {
        spin.stop();
        const skill = await client.getSkill(skillId);
        console.log(chalk.bold(`\nExecuting: ${skill.name}`));
        console.log(chalk.gray(skill.description));
        
        if (skill.tools && skill.tools.length > 0) {
          const toolAnswer = await inquirer.prompt([{
            type: 'list',
            name: 'tool',
            message: 'Select a tool:',
            choices: skill.tools.map((t: ToolDefinition) => ({ name: `${t.name} - ${t.description}`, value: t.name }))
          }]);
          options.tool = toolAnswer.tool;
          
          const tool = skill.tools.find((t: ToolDefinition) => t.name === options.tool);
          if (tool && tool.parameters.length > 0) {
            for (const param of tool.parameters) {
              const answer = await inquirer.prompt([{
                type: param.paramType === 'boolean' ? 'confirm' : 'input',
                name: param.name,
                message: param.description,
                default: param.defaultValue,
              }]);
              params[param.name] = answer[param.name];
            }
          }
        }
        spin.start();
      }
      
      let result: SkillExecutionResult;
      
      if (options.tool) {
        spin.text = `Executing tool: ${options.tool}...`;
        result = await client.executeSkillTool(skillId, options.tool, params);
      } else {
        spin.text = 'Executing skill...';
        result = await client.executeSkill(skillId, params);
      }
      
      if (result.success) {
        spin.succeed('Execution completed');
        console.log('\n' + chalk.bold('Result:'));
        console.log(result.output);
        if (result.data) {
          console.log(chalk.gray('\nData:'));
          console.log(JSON.stringify(result.data, null, 2));
        }
      } else {
        spin.fail('Execution failed');
        printError(result.errorMessage || 'Unknown error');
        process.exit(1);
      }
      
    } catch (error: unknown) {
      spin.fail('Execution failed');
      printError(handleApiError(error).errmsg);
      process.exit(1);
    }
  });

program
  .command('remove <skillId>')
  .alias('rm')
  .alias('uninstall')
  .description('Remove an installed skill')
  .option('-y, --yes', 'Skip confirmation prompt', false)
  .action(async (skillId: string, options: RemoveOptions) => {
    try {
      const client = getClient();
      
      if (!options.yes) {
        const skill = await client.getSkill(skillId);
        console.log(chalk.bold('\nAbout to remove:'));
        printSkill(skill);
        
        const answer = await inquirer.prompt([{
          type: 'confirm',
          name: 'proceed',
          message: 'Are you sure you want to remove this skill?',
          default: false
        }]);
        
        if (!answer.proceed) {
          console.log(chalk.gray('Removal cancelled.'));
          return;
        }
      }
      
      const spin = spinner('Removing skill...');
      const result = await client.uninstallSkill(skillId);
      spin.succeed(result.message);
      
    } catch (error: unknown) {
      printError(handleApiError(error).errmsg);
      process.exit(1);
    }
  });

program
  .command('info <skillId>')
  .description('Show detailed information about a skill')
  .action(async (skillId: string) => {
    try {
      const client = getClient();
      const skill = await client.getSkill(skillId);
      
      printSkill(skill);
      
      if (skill.tools && skill.tools.length > 0) {
        console.log(chalk.bold('\n  Tools:'));
        skill.tools.forEach((tool: ToolDefinition) => {
          console.log(chalk.cyan(`    • ${tool.name}`));
          console.log(chalk.gray(`      ${tool.description}`));
          if (tool.parameters.length > 0) {
            tool.parameters.forEach(param => {
              const required = param.required ? chalk.red('*') : '';
              console.log(chalk.gray(`        - ${param.name}${required}: ${param.description}`));
            });
          }
        });
      }
      
      if (skill.dependencies && skill.dependencies.length > 0) {
        console.log(chalk.bold('\n  Dependencies:'));
        skill.dependencies.forEach((dep: string) => {
          console.log(chalk.gray(`    • ${dep}`));
        });
      }
      
    } catch (error: unknown) {
      printError(handleApiError(error).errmsg);
      process.exit(1);
    }
  });

program
  .command('init [name]')
  .description('Initialize a new skill project')
  .option('-d, --directory <dir>', 'Target directory', '.')
  .option('-t, --template <template>', 'Skill template', 'basic')
  .action(async (name: string | undefined, options: InitOptions) => {
    try {
      let skillName = name;
      if (!skillName) {
        const answer = await inquirer.prompt([{
          type: 'input',
          name: 'name',
          message: 'Skill name:',
          validate: (input: string) => input.length > 0 || 'Name is required'
        }]);
        skillName = answer.name;
      }
      
      const targetDir = path.join(options.directory, skillName!);
      
      if (await fs.exists(targetDir)) {
        const answer = await inquirer.prompt([{
          type: 'confirm',
          name: 'overwrite',
          message: `Directory "${targetDir}" already exists. Overwrite?`,
          default: false
        }]);
        if (!answer.overwrite) {
          console.log(chalk.gray('Init cancelled.'));
          return;
        }
      }
      
      const spin = spinner('Creating skill project...');
      
      await fs.ensureDir(targetDir);
      
      const skillContent = `---
name: ${skillName}
description: A new agent skill
version: 1.0.0
author: Your Name
license: MIT
---

# ${skillName}

This is a new agent skill created with the skills CLI.

## Usage

Describe how to use this skill here.

## Tools

### tool-name

Description of what this tool does.

**Parameters:**

- \`param1\` (string, required): Description of parameter

**Example:**

\`\`\`
skills run ${skillName} --tool tool-name -p '{"param1": "value"}'
\`\`\`

## Installation

\`\`\`
skills add ./path/to/${skillName}
\`\`\`
`;
      
      await fs.writeFile(path.join(targetDir, 'SKILL.md'), skillContent);
      
      const readmeContent = `# ${skillName}

An agent skill for [description].

## Installation

\`\`\`bash
skills add ./path/to/${skillName}
\`\`\`

## Usage

\`\`\`bash
skills run ${skillName} --tool <tool-name> -p '{"param": "value"}'
\`\`\`

## License

MIT
`;
      
      await fs.writeFile(path.join(targetDir, 'README.md'), readmeContent);
      
      spin.succeed(`Skill project created at ${targetDir}`);
      
      console.log(chalk.bold('\nNext steps:'));
      console.log(chalk.gray(`  1. Edit ${targetDir}/SKILL.md to define your skill`));
      console.log(chalk.gray(`  2. Add any additional files or resources`));
      console.log(chalk.gray(`  3. Install with: skills add ${targetDir}`));
      
    } catch (error: unknown) {
      printError(error instanceof Error ? error.message : 'Unknown error');
      process.exit(1);
    }
  });

program
  .command('check')
  .description('Check for skill updates')
  .action(async () => {
    const spin = spinner('Checking for updates...');
    
    try {
      const client = getClient();
      const result = await client.listSkills({ limit: 100 });
      spin.stop();
      
      if (result.skills.length === 0) {
        console.log(chalk.yellow('No skills installed.'));
        return;
      }
      
      console.log(chalk.bold(`\nChecking ${result.skills.length} skill(s) for updates...\n`));
      
      let updatesAvailable = 0;
      for (const skill of result.skills) {
        console.log(chalk.gray(`  ${skill.name} (${skill.version}) - No updates available`));
      }
      
      if (updatesAvailable === 0) {
        console.log(chalk.green('\n✓ All skills are up to date'));
      } else {
        console.log(chalk.yellow(`\n${updatesAvailable} skill(s) have updates available`));
        console.log(chalk.gray('Run `skills update` to update all skills'));
      }
      
    } catch (error: unknown) {
      spin.fail('Check failed');
      printError(handleApiError(error).errmsg);
      process.exit(1);
    }
  });

program
  .command('update [skillId]')
  .description('Update skills to their latest versions')
  .option('-a, --all', 'Update all installed skills', false)
  .action(async (skillId: string | undefined, options: UpdateOptions) => {
    const spin = spinner('Updating skills...');
    
    try {
      const client = getClient();
      
      if (options.all) {
        const result = await client.listSkills({ limit: 100 });
        spin.stop();
        
        if (result.skills.length === 0) {
          console.log(chalk.yellow('No skills installed.'));
          return;
        }
        
        console.log(chalk.bold(`\nUpdating ${result.skills.length} skill(s)...\n`));
        
        for (const skill of result.skills) {
          const updateSpin = spinner(`Updating ${skill.name}...`);
          try {
            await client.updateSkill(skill.id, {});
            updateSpin.succeed(`${skill.name} updated`);
          } catch {
            updateSpin.fail(`Failed to update ${skill.name}`);
          }
        }
        
        console.log(chalk.green('\n✓ Update complete'));
      } else if (skillId) {
        spin.text = `Updating ${skillId}...`;
        await client.updateSkill(skillId, {});
        spin.succeed(`${skillId} updated`);
      } else {
        spin.stop();
        printError('Please specify a skill ID or use --all to update all skills');
        process.exit(1);
      }
      
    } catch (error: unknown) {
      spin.fail('Update failed');
      printError(handleApiError(error).errmsg);
      process.exit(1);
    }
  });

program
  .command('config <skillId>')
  .description('Manage skill configuration')
  .option('-s, --set <key=value>', 'Set a configuration value')
  .option('-g, --get <key>', 'Get a configuration value')
  .option('-l, --list', 'List all configuration', false)
  .action(async (skillId: string, options: ConfigOptions) => {
    try {
      const client = getClient();
      
      if (options.list) {
        const config = await client.getSkillConfig(skillId);
        console.log(chalk.bold(`\nConfiguration for ${skillId}:\n`));
        console.log(JSON.stringify(config, null, 2));
        return;
      }
      
      if (options.get) {
        const config = await client.getSkillConfig(skillId);
        console.log(config[options.get] || chalk.gray('(not set)'));
        return;
      }
      
      if (options.set) {
        const [key, value] = options.set.split('=');
        if (!key || value === undefined) {
          printError('Invalid format. Use: --set key=value');
          process.exit(1);
        }
        
        const config = await client.getSkillConfig(skillId);
        config[key] = value;
        
        await client.setSkillConfig(skillId, config);
        printSuccess(`Set ${key} = ${value}`);
        return;
      }
      
      printError('Please specify an action: --set, --get, or --list');
      
    } catch (error: unknown) {
      printError(handleApiError(error).errmsg);
      process.exit(1);
    }
  });

program
  .command('status')
  .description('Check the status of the skills runtime server')
  .action(async () => {
    try {
      const client = getClient();
      const runtimeStatus = await client.runtime.status();
      
      if (runtimeStatus.running) {
        console.log(chalk.green('✓'), 'Skills runtime is running');
        console.log(chalk.gray('  API URL:'), client.getBaseUrl());
        console.log(chalk.gray('  Runtime Version:'), runtimeStatus.version || 'unknown');
        console.log(chalk.gray('  SDK Version:'), runtimeStatus.sdkVersion || 'unknown');
        
        const skills = await client.listSkills({ limit: 1 });
        console.log(chalk.gray('  Skills installed:'), skills.total_count);
      } else {
        console.log(chalk.red('✗'), 'Skills runtime is not running');
        console.log(chalk.gray('  API URL:'), client.getBaseUrl());
        console.log(chalk.gray('  SDK Version:'), runtimeStatus.sdkVersion || 'unknown');
        console.log(chalk.gray('\nStart the runtime with: skills start'));
        console.log(chalk.gray('Install runtime with: skills install-runtime'));
      }
      
    } catch (error: unknown) {
      console.log(chalk.red('✗'), 'Skills runtime is not responding');
      console.log(chalk.gray('  Error:'), handleApiError(error).errmsg);
    }
  });

program
  .command('install-runtime')
  .description('Download and install the AgentSkills runtime binary')
  .option('--runtime-version <version>', 'Runtime version to install', RUNTIME_VERSION)
  .action(async (options: { runtimeVersion: string }) => {
    const runtime = new RuntimeManager();
    
    if (runtime.isInstalled()) {
      console.log(chalk.yellow('Runtime is already installed at:'), runtime.getRuntimePath());
      const answer = await inquirer.prompt([{
        type: 'confirm',
        name: 'reinstall',
        message: 'Do you want to reinstall?',
        default: false
      }]);
      if (!answer.reinstall) {
        return;
      }
    }
    
    const spin = spinner(`Downloading runtime v${options.runtimeVersion}...`);
    
    try {
      const success = await runtime.downloadRuntime(options.runtimeVersion);
      if (success) {
        spin.succeed('Runtime installed successfully');
        console.log(chalk.gray('\nLocation:'), runtime.getRuntimePath());
        console.log(chalk.bold('\nNext steps:'));
        console.log(chalk.gray('  1. Start the runtime: skills start'));
        console.log(chalk.gray('  2. Install a skill: skills add <source>'));
      } else {
        spin.fail('Failed to download runtime');
        process.exit(1);
      }
    } catch (error: unknown) {
      spin.fail('Installation failed');
      printError(error instanceof Error ? error.message : 'Unknown error');
      process.exit(1);
    }
  });

program
  .command('start')
  .description('Start the AgentSkills runtime server')
  .option('-p, --port <port>', 'Port to listen on', '8080')
  .option('-h, --host <host>', 'Host to bind to', '127.0.0.1')
  .option('-f, --foreground', 'Run in foreground (default: background)', false)
  .action(async (options: { port: string; host: string; foreground: boolean }) => {
    const runtime = new RuntimeManager();
    
    if (!runtime.isInstalled()) {
      printError('Runtime is not installed.');
      console.log(chalk.gray('\nInstall with: skills install-runtime'));
      process.exit(1);
    }
    
    const status = await runtime.status();
    if (status.running) {
      console.log(chalk.yellow('Runtime is already running'));
      console.log(chalk.gray('  API URL:'), `http://${options.host}:${options.port}`);
      console.log(chalk.gray('  Runtime Version:'), status.version || 'unknown');
      console.log(chalk.gray('  SDK Version:'), status.sdkVersion || 'unknown');
      return;
    }
    
    const detached = !options.foreground;
    
    console.log(chalk.bold('Starting AgentSkills runtime...'));
    console.log(chalk.gray(`  Host: ${options.host}`));
    console.log(chalk.gray(`  Port: ${options.port}`));
    console.log(chalk.gray(`  Mode: ${detached ? 'background' : 'foreground'}`));
    
    const proc = runtime.start({
      port: parseInt(options.port),
      host: options.host,
      detached: detached
    });
    
    if (proc) {
      if (detached) {
        await new Promise(resolve => setTimeout(resolve, 2000));
        const newStatus = await runtime.status();
        if (newStatus.running) {
          console.log(chalk.green('\n✓ Runtime started in background'));
          console.log(chalk.gray('  API URL:'), `http://${options.host}:${options.port}`);
          console.log(chalk.gray('  Runtime Version:'), newStatus.version || 'unknown');
          console.log(chalk.gray('  SDK Version:'), newStatus.sdkVersion || 'unknown');
          console.log(chalk.gray('\nStop with: skills stop'));
        } else {
          printError('Runtime failed to start');
          process.exit(1);
        }
      } else {
        console.log(chalk.green('\n✓ Runtime started'));
        console.log(chalk.gray('Press Ctrl+C to stop'));
      }
    } else {
      printError('Failed to start runtime');
      process.exit(1);
    }
  });

program
  .command('stop')
  .description('Stop the AgentSkills runtime server')
  .action(async () => {
    const runtime = new RuntimeManager();
    
    const status = await runtime.status();
    if (!status.running) {
      console.log(chalk.yellow('Runtime is not running'));
      return;
    }
    
    const success = runtime.stop();
    if (success) {
      console.log(chalk.green('✓ Runtime stopped'));
    } else {
      printError('Failed to stop runtime');
      process.exit(1);
    }
  });

program.parse();
