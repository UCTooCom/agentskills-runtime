"""Test configuration for pytest."""

import sys
from pathlib import Path

import pytest

src_path = Path(__file__).parent.parent / "src"
sys.path.insert(0, str(src_path))
