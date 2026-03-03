"""Type definitions for the AgentSkills SDK."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional, TypedDict, Union


class EnvironmentConfig(TypedDict, total=False):
    """Environment configuration dictionary."""

    pass


@dataclass
class SkillMetadata:
    """Skill metadata definition."""

    name: str
    version: str
    description: str
    author: str
    license: Optional[str] = None
    format: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


@dataclass
class Skill(SkillMetadata):
    """Complete skill definition."""

    id: str = ""
    source_path: str = ""
    metadata: Optional[Dict[str, Any]] = None
    dependencies: Optional[List[str]] = None
    tools: Optional[List["ToolDefinition"]] = None


class ParamType(Enum):
    """Tool parameter types."""

    STRING = "string"
    NUMBER = "number"
    BOOLEAN = "boolean"
    FILE = "file"
    ARRAY = "array"
    OBJECT = "object"


@dataclass
class ToolParameter:
    """Tool parameter definition."""

    name: str
    param_type: ParamType
    description: str
    required: bool
    default_value: Optional[Union[str, int, float, bool]] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation."""
        result = {
            "name": self.name,
            "paramType": self.param_type.value,
            "description": self.description,
            "required": self.required,
        }
        if self.default_value is not None:
            result["defaultValue"] = self.default_value
        return result

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ToolParameter":
        """Create from dictionary representation."""
        param_type_str = data.get("paramType", data.get("param_type", "string"))
        param_type = ParamType(param_type_str) if isinstance(param_type_str, str) else param_type_str

        return cls(
            name=data["name"],
            param_type=param_type,
            description=data.get("description", ""),
            required=data.get("required", False),
            default_value=data.get("defaultValue", data.get("default_value")),
        )


@dataclass
class ToolDefinition:
    """Tool definition."""

    name: str
    description: str
    parameters: List[ToolParameter] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation."""
        return {
            "name": self.name,
            "description": self.description,
            "parameters": [p.to_dict() for p in self.parameters],
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ToolDefinition":
        """Create from dictionary representation."""
        parameters = []
        for p in data.get("parameters", []):
            if isinstance(p, dict):
                parameters.append(ToolParameter.from_dict(p))
            elif isinstance(p, ToolParameter):
                parameters.append(p)

        return cls(
            name=data["name"],
            description=data.get("description", ""),
            parameters=parameters,
        )


@dataclass
class SkillExecutionResult:
    """Result of skill execution."""

    success: bool
    output: str
    error_message: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


@dataclass
class SkillListResponse:
    """Response from listing skills."""

    current_page: int
    total_count: int
    total_page: int
    skills: List[Skill]


@dataclass
class SkillInstallOptions:
    """Options for installing a skill."""

    source: str
    validate: bool = True
    creator: Optional[str] = None
    install_path: Optional[str] = None
    branch: Optional[str] = None
    tag: Optional[str] = None
    commit: Optional[str] = None
    skill_subpath: Optional[str] = None


@dataclass
class SkillInstallResult:
    """Result of skill installation."""

    id: str
    name: str
    status: str
    message: str
    created_at: str


@dataclass
class AvailableSkillInfo:
    """Information about an available skill in a multi-skill repository."""

    name: str
    description: str
    relative_path: str
    full_path: str
    depth: int
    parent_path: str


@dataclass
class MultiSkillRepoResponse:
    """Response when installing from a multi-skill repository."""

    status: str = "multi_skill_repo"
    message: str = ""
    available_skills: List[AvailableSkillInfo] = field(default_factory=list)
    total_count: int = 0
    source_url: str = ""


@dataclass
class SkillInstallResponse:
    """Response from skill installation."""

    id: Optional[str] = None
    name: Optional[str] = None
    status: str = ""
    message: str = ""
    created_at: Optional[str] = None
    source_type: Optional[str] = None
    source_url: Optional[str] = None
    available_skills: Optional[List[AvailableSkillInfo]] = None
    total_count: Optional[int] = None


@dataclass
class SkillSearchResultItem:
    """A single search result item."""

    name: str
    full_name: str
    description: str
    url: Optional[str] = None
    html_url: Optional[str] = None
    clone_url: str = ""
    source: str = ""
    stars: Optional[int] = None
    forks: Optional[int] = None
    stargazers_count: Optional[int] = None
    forks_count: Optional[int] = None
    updated_at: str = ""
    author: Optional[str] = None
    owner: Optional[Dict[str, str]] = None
    topics: Optional[List[str]] = None
    license: Optional[str] = None


@dataclass
class SkillSearchResult:
    """Result of skill search."""

    total_count: int
    results: List[SkillSearchResultItem]


@dataclass
class ApiError:
    """API error response."""

    errno: int
    errmsg: str
    details: Optional[Dict[str, Any]] = None


@dataclass
class ClientConfig:
    """Client configuration."""

    base_url: Optional[str] = None
    auth_token: Optional[str] = None
    timeout: int = 30000


@dataclass
class RuntimeStatus:
    """Runtime status information."""

    running: bool
    version: Optional[str] = None
    sdk_version: Optional[str] = None
    pid: Optional[int] = None
    port: Optional[int] = None


@dataclass
class RuntimeOptions:
    """Options for starting the runtime."""

    port: int = 8080
    host: str = "127.0.0.1"
    detached: bool = False
    cwd: Optional[str] = None
    env: Optional[Dict[str, str]] = None
    skill_install_path: Optional[str] = None
