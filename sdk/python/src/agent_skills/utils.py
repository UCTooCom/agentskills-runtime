"""Utility functions for AgentSkills SDK."""

from __future__ import annotations

import os
from typing import Any, Callable, Dict, List, Optional, Tuple, TypedDict, Union

from agent_skills import RUNTIME_VERSION, __version__
from agent_skills.models import EnvironmentConfig, SkillMetadata, ToolDefinition


class ConfigValidationResult(TypedDict):
    """Result of configuration validation."""

    pass


def define_skill(
    metadata: SkillMetadata,
    tools: List[ToolDefinition],
    validate_config: Optional[Callable[[EnvironmentConfig], Tuple[None, str]]] = None,
) -> Dict[str, Any]:
    """Define a new skill with metadata and tools.

    Args:
        metadata: Skill metadata including name, version, description, etc.
        tools: List of tool definitions for the skill.
        validate_config: Optional function to validate configuration.

    Returns:
        A dictionary containing the skill definition.
    """
    return {
        "metadata": metadata,
        "tools": tools,
        "validate_config": validate_config,
    }


def get_config() -> Dict[str, str]:
    """Get configuration from environment variables.

    Returns:
        A dictionary of configuration values from environment variables
        prefixed with 'SKILL_'.
    """
    config: Dict[str, str] = {}

    for key, value in os.environ.items():
        if key.startswith("SKILL_") and value is not None:
            config_key = key[6:]
            config[config_key] = value

    return config


def get_sdk_version() -> str:
    """Get the SDK version."""
    return __version__


def get_runtime_version() -> str:
    """Get the runtime version."""
    return RUNTIME_VERSION
