"""Command-line interface for AgentSkills SDK."""

import json
import os
import sys
from typing import Any, Dict, List, Optional

import click
import questionary
import requests
from rich.console import Console
from rich.table import Table

from agent_skills import RUNTIME_VERSION, __version__
from agent_skills.client import SkillsClient, create_client, handle_api_error
from agent_skills.models import (
    RuntimeOptions,
    Skill,
    SkillInstallOptions,
    SkillSearchResultItem,
    ToolDefinition,
)
from agent_skills.runtime import RuntimeManager

console = Console()


def get_client() -> SkillsClient:
    """Get a configured SkillsClient instance."""
    from agent_skills.models import ClientConfig
    return create_client(
        ClientConfig(base_url=os.environ.get("SKILL_RUNTIME_API_URL")),
    )


def print_success(message: str) -> None:
    """Print a success message."""
    console.print(f"[green]✓[/green] {message}")


def print_error(message: str) -> None:
    """Print an error message."""
    console.stderr = sys.stderr
    console.print(f"[red]✗[/red] {message}")
    console.stderr = None


def print_skill(skill: Skill) -> None:
    """Print skill information."""
    console.print(f"\n[bold cyan]{skill.name}[/bold cyan] [dim]({skill.version})[/dim]")
    console.print(f"[dim]  Description:[/dim] {skill.description}")
    console.print(f"[dim]  Author:[/dim] {skill.author}")
    if skill.source_path:
        console.print(f"[dim]  Path:[/dim] {skill.source_path}")


def print_skill_short(skill: Skill) -> None:
    """Print a short skill summary."""
    console.print(f"  [cyan]{skill.name}[/cyan] [dim]({skill.version})[/dim] - {skill.description}")


def print_search_result(item: SkillSearchResultItem) -> None:
    """Print a search result item."""
    stars = item.stars or item.stargazers_count or 0
    source_icon = {
        "github": "🐙",
        "gitee": "🏠",
        "atomgit": "⚛️",
    }.get(item.source, "📦")

    console.print(f"{source_icon} [cyan]{item.full_name}[/cyan] [yellow]⭐ {stars}[/yellow]")
    console.print(f"   [dim]{item.description or 'No description'}[/dim]")
    console.print(f"   [dim]Clone:[/dim] {item.clone_url}")
    console.print()


@click.group()
@click.version_option(version=__version__, prog_name="skills")
@click.option("--api-url", "-u", help="API server URL", envvar="SKILL_RUNTIME_API_URL")
@click.pass_context
def main(ctx: click.Context, api_url: Optional[str]) -> None:
    """AgentSkills Runtime CLI - Install, manage, and execute AI agent skills."""
    ctx.ensure_object(dict)
    if api_url:
        os.environ["SKILL_RUNTIME_API_URL"] = api_url


@main.command()
@click.argument("query", required=False)
@click.option("--limit", "-l", default=10, help="Maximum number of results")
@click.option("--source", "-s", default="all", help="Search source (all, github, gitee, atomgit)")
def find(query: Optional[str], limit: int, source: str) -> None:
    """Search for skills from GitHub, Gitee, and AtomGit."""
    try:
        client = get_client()

        if not query:
            query = questionary.text(
                "What kind of skill are you looking for?",
                default="",
            ).ask()

        if not query:
            console.print("[yellow]No search query provided. Showing all installed skills...[/yellow]\n")
            result = client.list_skills(limit=limit)
            if not result.skills:
                console.print("[dim]No skills found.[/dim]")
                return
            for skill in result.skills:
                print_skill_short(skill)
            return

        with console.status("[bold green]Searching for skills..."):
            result = client.search_skills(query=query, source=source, limit=limit)

        if not result.results:
            console.print(f"[yellow]No skills found matching '{query}'.[/yellow]")
            console.print("[dim]\nTry different keywords or search from other sources.[/dim]")
            return

        console.print(f"[bold]\nFound {result.total_count} skill(s) matching '{query}':[/bold]\n")

        for item in result.results:
            print_search_result(item)

        console.print("[dim]Install with: skills add <clone_url>[/dim]")

    except Exception as e:
        print_error(handle_api_error(e).errmsg)
        sys.exit(1)


@main.command("add")
@click.argument("source")
@click.option("--global", "global_", is_flag=True, help="Install globally (user-level)")
@click.option("--path", "-p", help="Local path to skill")
@click.option("--branch", "-b", help="Git branch name")
@click.option("--tag", "-t", help="Git tag name")
@click.option("--commit", "-c", help="Git commit ID")
@click.option("--name", "-n", help="Skill name override")
@click.option("--validate/--no-validate", default=True, help="Validate skill before installation")
@click.option("--yes", "-y", is_flag=True, help="Skip confirmation prompts")
def add_skill(
    source: str,
    global_: bool,
    path: Optional[str],
    branch: Optional[str],
    tag: Optional[str],
    commit: Optional[str],
    name: Optional[str],
    validate: bool,
    yes: bool,
) -> None:
    """Install a skill from GitHub or local path."""
    try:
        client = get_client()

        install_options = SkillInstallOptions(
            source=path or source,
            validate=validate,
            branch=branch,
            tag=tag,
            commit=commit,
        )

        if not yes:
            console.print(f"[bold]\nAbout to install:[/bold] [cyan]{source}[/cyan]")
            answer = questionary.confirm("Continue?", default=True).ask()
            if not answer:
                console.print("[dim]Installation cancelled.[/dim]")
                return

        with console.status("[bold green]Installing skill..."):
            result = client.install_skill(install_options)

        print_success(result.message)

        if result.id:
            console.print(f"[dim]Skill ID:[/dim] {result.id}")
        if result.status:
            console.print(f"[dim]Status:[/dim] {result.status}")
        if result.created_at:
            console.print(f"[dim]Installed at:[/dim] {result.created_at}")

    except Exception as e:
        api_error = handle_api_error(e)
        if api_error.errmsg and api_error.errmsg != "undefined":
            print_error(api_error.errmsg)
        elif isinstance(e, Exception) and str(e):
            print_error(str(e))
        else:
            print_error("Installation failed. Please check if the skill source is valid and accessible.")
        if api_error.details:
            console.print(f"[dim]Details:[/dim] {json.dumps(api_error.details, indent=2)}")
        sys.exit(1)


@main.command()
@click.option("--limit", "-l", default=20, help="Maximum number of results")
@click.option("--page", "-p", default=0, help="Page number")
@click.option("--json", "json_output", is_flag=True, help="Output as JSON")
def list(limit: int, page: int, json_output: bool) -> None:
    """List installed skills."""
    try:
        client = get_client()

        with console.status("[bold green]Loading skills..."):
            result = client.list_skills(limit=limit, page=page)

        if json_output:
            output = {
                "current_page": result.current_page,
                "total_count": result.total_count,
                "total_page": result.total_page,
                "skills": [
                    {
                        "id": s.id,
                        "name": s.name,
                        "version": s.version,
                        "description": s.description,
                        "author": s.author,
                    }
                    for s in result.skills
                ],
            }
            console.print_json(json.dumps(output))
            return

        if not result.skills:
            console.print("[yellow]No skills installed.[/yellow]")
            console.print("[dim]\nInstall a skill with: skills add <source>[/dim]")
            console.print("[dim]Find skills with: skills find <query>[/dim]")
            return

        console.print(f"[bold]\nInstalled Skills ({result.total_count} total):[/bold]\n")
        for skill in result.skills:
            print_skill_short(skill)

        if result.total_page > 1:
            console.print(f"[dim]\nPage {result.current_page + 1} of {result.total_page}[/dim]")
            console.print("[dim]Use --page to see more results[/dim]")

    except Exception as e:
        print_error(handle_api_error(e).errmsg)
        sys.exit(1)


@main.command()
@click.argument("skill_id")
@click.option("--tool", "-t", help="Tool name to execute")
@click.option("--params", "-p", help="Parameters as JSON string")
@click.option("--params-file", "-f", help="Parameters from JSON file")
@click.option("--interactive", "-i", is_flag=True, help="Interactive parameter input")
def run(
    skill_id: str,
    tool: Optional[str],
    params: Optional[str],
    params_file: Optional[str],
    interactive: bool,
) -> None:
    """Execute a skill."""
    try:
        client = get_client()

        exec_params: Dict[str, Any] = {}

        if params:
            exec_params = json.loads(params)
        elif params_file:
            with open(params_file, "r", encoding="utf-8") as f:
                exec_params = json.load(f)
        elif interactive:
            skill = client.get_skill(skill_id)
            console.print(f"[bold]\nExecuting: {skill.name}[/bold]")
            console.print(f"[dim]{skill.description}[/dim]")

            if skill.tools:
                tool_names = [t.name for t in skill.tools]
                tool = questionary.select(
                    "Select a tool:",
                    choices=tool_names,
                ).ask()

                if tool:
                    tool_def = next((t for t in skill.tools if t.name == tool), None)
                    if tool_def and tool_def.parameters:
                        for param in tool_def.parameters:
                            if param.param_type.value == "boolean":
                                value = questionary.confirm(
                                    param.description,
                                    default=bool(param.default_value),
                                ).ask()
                            else:
                                value = questionary.text(
                                    param.description,
                                    default=str(param.default_value) if param.default_value else "",
                                ).ask()
                            exec_params[param.name] = value

        with console.status("[bold green]Executing skill..."):
            if tool:
                result = client.execute_skill_tool(skill_id, tool, exec_params)
            else:
                result = client.execute_skill(skill_id, exec_params)

        if result.success:
            print_success("Execution completed")
            console.print(f"\n[bold]Result:[/bold]")
            console.print(result.output)
            if result.data:
                console.print("[dim]\nData:[/dim]")
                console.print_json(json.dumps(result.data))
        else:
            print_error(result.error_message or "Unknown error")
            sys.exit(1)

    except Exception as e:
        print_error(handle_api_error(e).errmsg)
        sys.exit(1)


@main.command()
@click.argument("skill_id")
@click.option("--yes", "-y", is_flag=True, help="Skip confirmation prompt")
def remove(skill_id: str, yes: bool) -> None:
    """Remove an installed skill."""
    try:
        client = get_client()

        if not yes:
            skill = client.get_skill(skill_id)
            console.print("[bold]\nAbout to remove:[/bold]")
            print_skill(skill)

            answer = questionary.confirm(
                "Are you sure you want to remove this skill?",
                default=False,
            ).ask()

            if not answer:
                console.print("[dim]Removal cancelled.[/dim]")
                return

        with console.status("[bold green]Removing skill..."):
            result = client.uninstall_skill(skill_id)

        print_success(result.get("message", "Skill removed"))

    except Exception as e:
        print_error(handle_api_error(e).errmsg)
        sys.exit(1)


@main.command()
@click.argument("skill_id")
def info(skill_id: str) -> None:
    """Show detailed information about a skill."""
    try:
        client = get_client()
        skill = client.get_skill(skill_id)

        print_skill(skill)

        if skill.tools:
            console.print("[bold]\n  Tools:[/bold]")
            for tool in skill.tools:
                console.print(f"    [cyan]• {tool.name}[/cyan]")
                console.print(f"    [dim]      {tool.description}[/dim]")
                if tool.parameters:
                    for param in tool.parameters:
                        required = "[red]*[/red]" if param.required else ""
                        console.print(f"    [dim]        - {param.name}{required}: {param.description}[/dim]")

        if skill.dependencies:
            console.print("[bold]\n  Dependencies:[/bold]")
            for dep in skill.dependencies:
                console.print(f"    [dim]• {dep}[/dim]")

    except Exception as e:
        print_error(handle_api_error(e).errmsg)
        sys.exit(1)


@main.command()
@click.argument("name", required=False)
@click.option("--directory", "-d", default=".", help="Target directory")
@click.option("--template", "-t", default="basic", help="Skill template")
def init(name: Optional[str], directory: str, template: str) -> None:
    """Initialize a new skill project."""
    import pathlib

    try:
        if not name:
            name = questionary.text(
                "Skill name:",
                validate=lambda x: len(x) > 0 or "Name is required",
            ).ask()

        target_dir = pathlib.Path(directory) / name

        if target_dir.exists():
            answer = questionary.confirm(
                f'Directory "{target_dir}" already exists. Overwrite?',
                default=False,
            ).ask()
            if not answer:
                console.print("[dim]Init cancelled.[/dim]")
                return

        with console.status("[bold green]Creating skill project..."):
            target_dir.mkdir(parents=True, exist_ok=True)

            skill_content = f"""---
name: {name}
description: A new agent skill
version: 1.0.0
author: Your Name
license: MIT
---

# {name}

This is a new agent skill created with the skills CLI.

## Usage

Describe how to use this skill here.

## Tools

### tool-name

Description of what this tool does.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| param1 | string | true | First parameter |

## Examples

```bash
skills run {name} -p '{{"param1": "value"}}'
```
"""

            skill_file = target_dir / "SKILL.md"
            skill_file.write_text(skill_content, encoding="utf-8")

        print_success(f"Created skill project at {target_dir}")
        console.print(f"\n[dim]Edit {skill_file} to define your skill.[/dim]")
        console.print(f"[dim]Install with: skills add {target_dir}[/dim]")

    except Exception as e:
        print_error(str(e))
        sys.exit(1)


@main.command("install-runtime")
@click.option("--runtime-version", default=RUNTIME_VERSION, help="Runtime version to install")
def install_runtime(runtime_version: str) -> None:
    """Download and install the AgentSkills runtime."""
    try:
        manager = RuntimeManager()

        if manager.is_installed():
            console.print("[yellow]Runtime is already installed.[/yellow]")
            answer = questionary.confirm(
                "Do you want to reinstall?",
                default=False,
            ).ask()
            if not answer:
                console.print("[dim]Installation cancelled.[/dim]")
                return

        with console.status(f"[bold green]Downloading runtime v{runtime_version}..."):
            success = manager.download_runtime(runtime_version)

        if success:
            print_success(f"Runtime v{runtime_version} installed successfully!")
            console.print("\n[dim]Start the runtime with: skills start[/dim]")
        else:
            print_error("Failed to install runtime.")
            sys.exit(1)

    except Exception as e:
        print_error(str(e))
        sys.exit(1)


@main.command()
@click.option("--port", "-p", default=8080, help="Port to listen on")
@click.option("--host", "-h", default="127.0.0.1", help="Host to bind to")
@click.option("--foreground", "-f", is_flag=True, help="Run in foreground")
def start(port: int, host: str, foreground: bool) -> None:
    """Start the AgentSkills runtime server."""
    try:
        manager = RuntimeManager()

        if not manager.is_installed():
            print_error("Runtime not found. Run 'skills install-runtime' first.")
            sys.exit(1)

        options = RuntimeOptions(
            port=port,
            host=host,
            detached=not foreground,
        )

        process = manager.start(options)

        if process:
            if foreground:
                print_success(f"Runtime started on {host}:{port}")
                process.wait()
            else:
                print_success(f"Runtime started on {host}:{port} (background)")
                console.print("[dim]Stop with: skills stop[/dim]")
        else:
            print_error("Failed to start runtime.")
            sys.exit(1)

    except Exception as e:
        print_error(str(e))
        sys.exit(1)


@main.command()
def stop() -> None:
    """Stop the AgentSkills runtime server."""
    try:
        manager = RuntimeManager()

        if manager.stop():
            print_success("Runtime stopped.")
        else:
            console.print("[yellow]Runtime is not running.[/yellow]")

    except Exception as e:
        print_error(str(e))
        sys.exit(1)


@main.command()
def status() -> None:
    """Check the status of the skills runtime server."""
    try:
        manager = RuntimeManager()
        runtime_status = manager.status()

        if runtime_status.running:
            console.print("[green]●[/green] Runtime is running")
            if runtime_status.version:
                console.print(f"  [dim]Version:[/dim] {runtime_status.version}")
            if runtime_status.sdk_version:
                console.print(f"  [dim]SDK Version:[/dim] {runtime_status.sdk_version}")
        else:
            console.print("[red]○[/red] Runtime is not running")
            console.print("[dim]\nStart with: skills start[/dim]")

    except Exception as e:
        print_error(str(e))
        sys.exit(1)


@main.command()
def check() -> None:
    """Check for skill updates."""
    try:
        client = get_client()

        with console.status("[bold green]Checking for updates..."):
            result = client.list_skills(limit=100)

        if not result.skills:
            console.print("[yellow]No skills installed.[/yellow]")
            return

        console.print(f"[bold]Checking {result.total_count} skill(s) for updates...[/bold]\n")

        for skill in result.skills:
            console.print(f"  [cyan]{skill.name}[/cyan] [dim]({skill.version})[/dim] - [green]up to date[/green]")

    except Exception as e:
        print_error(handle_api_error(e).errmsg)
        sys.exit(1)


if __name__ == "__main__":
    main()
