#!/usr/bin/env python3
"""
Publish script for agentskills-runtime Python SDK to PyPI.

Usage:
    python publish.py [--test] [--token YOUR_TOKEN]

Options:
    --test      Publish to TestPyPI instead of PyPI
    --token     PyPI API token (if not provided, will use .pypirc or prompt)
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional


def run_command(cmd: list[str], cwd: Optional[Path] = None) -> int:
    """Run a command and return the exit code."""
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=cwd)
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="Publish agentskills-runtime to PyPI")
    parser.add_argument(
        "--test",
        action="store_true",
        help="Publish to TestPyPI instead of PyPI",
    )
    parser.add_argument(
        "--token",
        type=str,
        help="PyPI API token (if not provided, will use .pypirc or prompt)",
    )
    args = parser.parse_args()

    script_dir = Path(__file__).parent.absolute()
    os.chdir(script_dir)

    print("=" * 50)
    print("AgentSkills Python SDK Publish Script")
    print("=" * 50)
    print(f"Working directory: {script_dir}")

    print("\n[STEP] Cleaning previous builds...")
    for dir_name in ["build", "dist", "*.egg-info"]:
        for path in script_dir.glob(dir_name):
            if path.is_dir():
                import shutil

                shutil.rmtree(path)
                print(f"  Removed: {path}")

    print("\n[STEP] Building package...")
    rc = run_command([sys.executable, "-m", "build"])
    if rc != 0:
        print("ERROR: Build failed!")
        return rc

    print("\n[STEP] Checking package...")
    rc = run_command([sys.executable, "-m", "twine", "check", "dist/*"])
    if rc != 0:
        print("WARNING: Package check had issues, but continuing...")

    print("\n[STEP] Publishing to PyPI...")
    if args.test:
        print("  Target: TestPyPI")
        repository = "testpypi"
    else:
        print("  Target: PyPI")
        repository = "pypi"

    pypirc_path = script_dir / ".pypirc"
    publish_cmd = [
        sys.executable, "-m", "twine", "upload",
        "--repository", repository,
        "--config-file", str(pypirc_path),
        "dist/*"
    ]

    if args.token:
        username = "__token__"
        password = args.token
        publish_cmd.extend(["--username", username, "--password", password])

    rc = run_command(publish_cmd)
    if rc != 0:
        print("ERROR: Publish failed!")
        return rc

    print("\n" + "=" * 50)
    print("Publish completed successfully!")
    print("=" * 50)

    if args.test:
        print("\nPackage published to TestPyPI:")
        print("https://test.pypi.org/project/agentskills-runtime/")
        print("\nTo install from TestPyPI:")
        print("pip install --index-url https://test.pypi.org/simple/ agentskills-runtime")
    else:
        print("\nPackage published to PyPI:")
        print("https://pypi.org/project/agentskills-runtime/")
        print("\nTo install:")
        print("pip install agentskills-runtime")

    return 0


if __name__ == "__main__":
    sys.exit(main())
