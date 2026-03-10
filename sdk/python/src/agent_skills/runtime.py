"""Runtime manager for AgentSkills SDK."""

from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests

from agent_skills import RUNTIME_VERSION, __version__
from agent_skills.models import RuntimeOptions, RuntimeStatus


GITHUB_REPO = "UCTooCom/agentskills-runtime"
ATOMGIT_REPO = "uctoo/agentskills-runtime"


class DownloadMirror:
    """Download mirror configuration."""

    def __init__(self, name: str, url: str, priority: int, region: str) -> None:
        self.name = name
        self.url = url
        self.priority = priority
        self.region = region


DOWNLOAD_MIRRORS: List[DownloadMirror] = [
    DownloadMirror(
        name="atomgit",
        url=f"https://atomgit.com/{ATOMGIT_REPO}/releases/download",
        priority=1,
        region="china",
    ),
    DownloadMirror(
        name="github",
        url=f"https://github.com/{GITHUB_REPO}/releases/download",
        priority=2,
        region="global",
    ),
]


def get_platform_info() -> Dict[str, str]:
    """Get platform information for the current system."""
    current_platform = platform.system().lower()
    arch = platform.machine().lower()

    platform_map = {
        "windows": "win",
        "darwin": "darwin",
        "linux": "linux",
    }

    arch_map = {
        "x86_64": "x64",
        "amd64": "x64",
        "x64": "x64",
        "arm64": "arm64",
        "aarch64": "arm64",
    }

    mapped_platform = platform_map.get(current_platform, current_platform)
    mapped_arch = arch_map.get(arch, arch)

    suffix = ".exe" if current_platform == "windows" else ""

    return {
        "platform": mapped_platform,
        "arch": mapped_arch,
        "suffix": suffix,
    }


def get_runtime_dir() -> Path:
    """Get the runtime directory path."""
    return Path.home() / ".agentskills-runtime"


def get_runtime_path() -> Path:
    """Get the runtime executable path."""
    info = get_platform_info()
    return (
        get_runtime_dir()
        / f"{info['platform']}-{info['arch']}"
        / "release"
        / "bin"
        / f"agentskills-runtime{info['suffix']}"
    )


def get_release_dir() -> Path:
    """Get the release directory path."""
    info = get_platform_info()
    return get_runtime_dir() / f"{info['platform']}-{info['arch']}" / "release"


def get_version_file_path() -> Path:
    """Get the VERSION file path."""
    info = get_platform_info()
    return get_runtime_dir() / f"{info['platform']}-{info['arch']}" / "release" / "VERSION"


def get_installed_version() -> Optional[str]:
    """Get the installed runtime version."""
    version_file = get_version_file_path()
    if version_file.exists():
        content = version_file.read_text(encoding="utf-8")
        lines = content.strip().split("\n")
        for line in lines:
            if line.startswith("AGENTSKILLS_RUNTIME_VERSION="):
                version = line.split("=", 1)[1].strip()
                return version if version else None
        first_line = lines[0].strip() if lines else ""
        if first_line and "=" not in first_line:
            return first_line
    return None


def is_runtime_installed() -> bool:
    """Check if the runtime is installed."""
    return get_runtime_path().exists()


class RuntimeManager:
    """Manager for AgentSkills runtime."""

    def __init__(self, base_url: str = "http://127.0.0.1:8080") -> None:
        self.base_url = base_url
        self._process: Optional[subprocess.Popen[Any]] = None

    def is_installed(self) -> bool:
        """Check if the runtime is installed."""
        return is_runtime_installed()

    def get_runtime_path(self) -> Path:
        """Get the runtime executable path."""
        return get_runtime_path()

    def download_runtime(self, version: str = RUNTIME_VERSION) -> bool:
        """Download and install the runtime."""
        info = get_platform_info()
        runtime_dir = get_runtime_dir() / f"{info['platform']}-{info['arch']}"

        runtime_dir.mkdir(parents=True, exist_ok=True)

        file_name = f"agentskills-runtime-{info['platform']}-{info['arch']}.tar.gz"

        for mirror in DOWNLOAD_MIRRORS:
            download_url = f"{mirror.url}/v{version}/{file_name}"

            print(f"Trying mirror: {mirror.name} ({mirror.region})")
            print(f"URL: {download_url}")

            try:
                archive_path = runtime_dir / "runtime.tar.gz"

                response = requests.get(download_url, stream=True, timeout=300)
                response.raise_for_status()

                with open(archive_path, "wb") as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)

                with tarfile.open(archive_path, "r:gz") as tar:
                    tar.extractall(runtime_dir)

                archive_path.unlink()

                runtime_path = get_runtime_path()
                if runtime_path.exists() and platform.system().lower() != "windows":
                    os.chmod(runtime_path, 0o755)

                release_dir = get_release_dir()
                env_file = release_dir / ".env"
                env_example_file = release_dir / ".env.example"

                if not env_file.exists() and env_example_file.exists():
                    shutil.copy(env_example_file, env_file)
                    print("Created .env file from .env.example")
                elif not env_file.exists():
                    default_env_content = """# AgentSkills Runtime Configuration
# This file was auto-generated. Edit as needed.

# Skill Installation Path
SKILL_INSTALL_PATH=./skills
"""
                    env_file.write_text(default_env_content, encoding="utf-8")
                    print("Created default .env file")

                print(f"AgentSkills Runtime v{version} downloaded successfully from {mirror.name}!")
                return True

            except Exception as e:
                print(f"Mirror {mirror.name} failed, trying next...")
                print(f"Error: {e}")
                continue

        print("All mirrors failed to download runtime.")
        print("\nPlease download manually from one of these mirrors:")
        for mirror in DOWNLOAD_MIRRORS:
            print(f"  - {mirror.url}/v{version}/{file_name}")
        return False

    def start(self, options: Optional[RuntimeOptions] = None) -> Optional[subprocess.Popen[Any]]:
        """Start the runtime."""
        if options is None:
            options = RuntimeOptions()

        runtime_path = get_runtime_path()

        if not runtime_path.exists():
            print("Runtime not found. Run 'skills install-runtime' first.")
            return None

        port = options.port
        host = options.host
        cwd = options.cwd or str(get_release_dir())

        skill_install_path = (
            options.skill_install_path
            or os.environ.get("SKILL_INSTALL_PATH")
            or str(Path.cwd() / "skills")
        )

        env = {
            **os.environ,
            "SKILL_INSTALL_PATH": skill_install_path,
            **(options.env or {}),
        }

        print(f"[SDK DEBUG] cwd: {cwd}")
        print(f"[SDK DEBUG] SKILL_INSTALL_PATH in env: {env['SKILL_INSTALL_PATH']}")
        print(f"[SDK DEBUG] runtimePath: {runtime_path}")

        args = [str(runtime_path), str(port), "--skill-path", skill_install_path]
        print(f"[SDK DEBUG] args: {' '.join(args)}")

        stdout = subprocess.DEVNULL if options.detached else None
        stderr = subprocess.DEVNULL if options.detached else None

        self._process = subprocess.Popen(
            args,
            stdout=stdout,
            stderr=stderr,
            cwd=cwd,
            env=env,
        )

        if options.detached and self._process.pid:
            pid_file = get_runtime_dir() / "runtime.pid"
            pid_file.write_text(str(self._process.pid), encoding="utf-8")

        return self._process

    def stop(self) -> bool:
        """Stop the runtime."""
        pid_file = get_runtime_dir() / "runtime.pid"

        if pid_file.exists():
            try:
                pid = int(pid_file.read_text(encoding="utf-8").strip())
                if platform.system().lower() == "windows":
                    subprocess.run(["taskkill", "/F", "/PID", str(pid)], check=False, capture_output=True)
                else:
                    os.kill(pid, 15)
                pid_file.unlink()
                return True
            except Exception:
                try:
                    pid_file.unlink()
                except Exception:
                    pass
                return False

        if self._process is not None:
            try:
                if platform.system().lower() == "windows":
                    subprocess.run(["taskkill", "/F", "/PID", str(self._process.pid)], check=False, capture_output=True)
                else:
                    self._process.terminate()
            except Exception:
                pass
            self._process = None
            return True

        return False

    def status(self) -> RuntimeStatus:
        """Get the runtime status."""
        try:
            response = requests.get(f"{self.base_url}/hello", timeout=2)
            header_version = response.headers.get("x-runtime-version")
            installed_version = get_installed_version()

            return RuntimeStatus(
                running=True,
                version=header_version or installed_version or "unknown",
                sdk_version=__version__,
            )
        except Exception:
            return RuntimeStatus(running=False, sdk_version=__version__)
