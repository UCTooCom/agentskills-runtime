#!/usr/bin/env node

const https = require('https');
const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');
const os = require('os');

const GITHUB_REPO = 'UCTooCom/agentskills-runtime';
const ATOMGIT_REPO = 'uctoo/agentskills-runtime';

const packageJsonPath = path.join(__dirname, '..', 'package.json');
const packageJsonContent = fs.readFileSync(packageJsonPath, 'utf8');
const packageJson = JSON.parse(packageJsonContent);
const RUNTIME_VERSION = packageJson.runtime && packageJson.runtime.version ? packageJson.runtime.version : '0.0.3';

const DOWNLOAD_MIRRORS = [
  {
    name: 'atomgit',
    url: `https://atomgit.com/${ATOMGIT_REPO}/releases/download`,
    priority: 1,
    region: 'china'
  },
  {
    name: 'github',
    url: `https://github.com/${GITHUB_REPO}/releases/download`,
    priority: 2,
    region: 'global'
  }
];

function getPlatform() {
  const platform = os.platform();
  const arch = os.arch();
  
  const platformMap = {
    'win32': 'win',
    'darwin': 'darwin',
    'linux': 'linux'
  };
  
  const archMap = {
    'x64': 'x64',
    'arm64': 'arm64',
    'x86': 'x86'
  };
  
  return {
    platform: platformMap[platform] || platform,
    arch: archMap[arch] || arch,
    suffix: platform === 'win32' ? '.exe' : ''
  };
}

function getRuntimeDir() {
  const homeDir = os.homedir();
  return path.join(homeDir, '.agentskills-runtime');
}

function getRuntimePath() {
  const { platform, arch, suffix } = getPlatform();
  // Check for release structure first (release/bin/agentskills-runtime.exe)
  // Then fall back to direct structure (bin/agentskills-runtime.exe)
  const releasePath = path.join(getRuntimeDir(), `${platform}-${arch}`, 'release', 'bin', `agentskills-runtime${suffix}`);
  const directPath = path.join(getRuntimeDir(), `${platform}-${arch}`, `agentskills-runtime${suffix}`);
  
  if (fs.existsSync(releasePath)) {
    return releasePath;
  }
  return directPath;
}

function getRuntimeWorkingDir() {
  const { platform, arch } = getPlatform();
  // For release structure, working dir should be the release directory (parent of bin/)
  // This ensures .env file at release/.env can be found
  const releaseDir = path.join(getRuntimeDir(), `${platform}-${arch}`, 'release');
  if (fs.existsSync(path.join(releaseDir, 'bin'))) {
    return releaseDir;
  }
  // Fall back to bin directory for direct structure
  return path.join(getRuntimeDir(), `${platform}-${arch}`, 'bin');
}

function isRuntimeInstalled() {
  return fs.existsSync(getRuntimePath());
}

async function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    https.get(url, (response) => {
      if (response.statusCode === 302 || response.statusCode === 301) {
        downloadFile(response.headers.location, dest).then(resolve).catch(reject);
        return;
      }
      if (response.statusCode !== 200) {
        reject(new Error(`Download failed with status ${response.statusCode}`));
        return;
      }
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve(true);
      });
    }).on('error', (err) => {
      fs.unlink(dest, () => {});
      reject(err);
    });
  });
}

async function downloadRuntime(version = RUNTIME_VERSION) {
  const { platform, arch, suffix } = getPlatform();
  const runtimeDir = path.join(getRuntimeDir(), `${platform}-${arch}`);
  
  if (!fs.existsSync(runtimeDir)) {
    fs.mkdirSync(runtimeDir, { recursive: true });
  }
  
  const fileName = `agentskills-runtime-${platform}-${arch}.tar.gz`;
  const archivePath = path.join(runtimeDir, 'runtime.tar.gz');
  
  for (const mirror of DOWNLOAD_MIRRORS) {
    const downloadUrl = `${mirror.url}/v${version}/${fileName}`;
    
    console.log(`Trying mirror: ${mirror.name} (${mirror.region})`);
    console.log(`URL: ${downloadUrl}`);
    
    try {
      await downloadFile(downloadUrl, archivePath);
      
      if (os.platform() !== 'win32') {
        execSync(`tar -xzf "${archivePath}" -C "${runtimeDir}"`);
      } else {
        execSync(`tar -xzf "${archivePath}" -C "${runtimeDir}"`, { shell: 'powershell.exe' });
      }
      
      fs.unlinkSync(archivePath);
      
      const runtimePath = getRuntimePath();
      if (fs.existsSync(runtimePath) && os.platform() !== 'win32') {
        fs.chmodSync(runtimePath, '755');
      }
      
      // Handle .env file - preserve existing configuration
      const releaseDir = getRuntimeWorkingDir();
      const envFile = path.join(releaseDir, '.env');
      const envExampleFile = path.join(releaseDir, '.env.example');
      
      if (!fs.existsSync(envFile) && fs.existsSync(envExampleFile)) {
        fs.copyFileSync(envExampleFile, envFile);
        console.log('Created .env file from .env.example');
      } else if (!fs.existsSync(envFile)) {
        const defaultEnvContent = `# AgentSkills Runtime Configuration
# This file was auto-generated. Edit as needed.

# Skill Installation Path
SKILL_INSTALL_PATH=./skills
`;
        fs.writeFileSync(envFile, defaultEnvContent);
        console.log('Created default .env file');
      } else {
        console.log('Preserved existing .env file');
      }
      
      console.log(`AgentSkills Runtime v${version} downloaded successfully from ${mirror.name}!`);
      return true;
    } catch (error) {
      console.log(`Mirror ${mirror.name} failed: ${error.message}`);
      console.log('Trying next mirror...');
      continue;
    }
  }
  
  console.error('All mirrors failed to download runtime.');
  console.log('\nPlease download manually from one of these mirrors:');
  for (const mirror of DOWNLOAD_MIRRORS) {
    console.log(`  - ${mirror.url}/v${version}/${fileName}`);
  }
  return false;
}

function startRuntime(options = {}) {
  const runtimePath = getRuntimePath();
  
  if (!fs.existsSync(runtimePath)) {
    console.error('Runtime not found. Run "skills install-runtime" first.');
    return null;
  }
  
  const port = options.port || 8080;
  const host = options.host || '127.0.0.1';
  
  const args = ['--port', String(port), '--host', host];
  
  // Use the correct working directory for the runtime
  // This ensures .env file can be found in the release directory
  const workingDir = getRuntimeWorkingDir();
  
  const child = spawn(runtimePath, args, {
    stdio: options.detached ? 'ignore' : 'inherit',
    detached: options.detached || false,
    cwd: workingDir
  });
  
  if (options.detached) {
    child.unref();
    const pidFile = path.join(getRuntimeDir(), 'runtime.pid');
    fs.writeFileSync(pidFile, String(child.pid));
  }
  
  return child;
}

function stopRuntime() {
  const pidFile = path.join(getRuntimeDir(), 'runtime.pid');
  
  if (fs.existsSync(pidFile)) {
    const pid = parseInt(fs.readFileSync(pidFile, 'utf-8'), 10);
    try {
      process.kill(pid, 'SIGTERM');
      fs.unlinkSync(pidFile);
      return true;
    } catch (error) {
      return false;
    }
  }
  
  return false;
}

async function checkRuntimeStatus() {
  const http = require('http');
  
  return new Promise((resolve) => {
    const req = http.get('http://127.0.0.1:8080/hello', (res) => {
      resolve({ running: true, version: res.headers['x-runtime-version'] || 'unknown' });
    });
    
    req.on('error', () => {
      resolve({ running: false });
    });
    
    req.setTimeout(2000, () => {
      req.destroy();
      resolve({ running: false });
    });
  });
}

module.exports = {
  getPlatform,
  getRuntimeDir,
  getRuntimePath,
  getRuntimeWorkingDir,
  isRuntimeInstalled,
  downloadRuntime,
  startRuntime,
  stopRuntime,
  checkRuntimeStatus,
  DOWNLOAD_MIRRORS
};
