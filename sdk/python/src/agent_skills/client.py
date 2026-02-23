"""API client for AgentSkills SDK."""

import os
from typing import Any, Dict, List, Optional, Union

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from agent_skills.models import (
    ApiError,
    AvailableSkillInfo,
    ClientConfig,
    MultiSkillRepoResponse,
    Skill,
    SkillExecutionResult,
    SkillInstallOptions,
    SkillInstallResponse,
    SkillListResponse,
    SkillSearchResult,
    SkillSearchResultItem,
    ToolDefinition,
    ToolParameter,
)
from agent_skills.runtime import RuntimeManager


DEFAULT_BASE_URL = "http://127.0.0.1:8080"
DEFAULT_TIMEOUT = 30000


def handle_api_error(error: Exception) -> ApiError:
    """Handle API errors and return a consistent error format."""
    if isinstance(error, requests.exceptions.HTTPError):
        response = error.response
        try:
            data = response.json()
            return ApiError(
                errno=data.get("errno", response.status_code),
                errmsg=data.get("errmsg", str(error)),
                details=data.get("details"),
            )
        except Exception:
            return ApiError(
                errno=response.status_code,
                errmsg=response.reason or str(error),
            )
    if isinstance(error, requests.exceptions.ConnectionError):
        return ApiError(
            errno=503,
            errmsg="Runtime server is not responding. Make sure the runtime is running.",
        )
    if isinstance(error, requests.exceptions.Timeout):
        return ApiError(
            errno=504,
            errmsg="Request timed out.",
        )
    if isinstance(error, requests.exceptions.RequestException):
        return ApiError(
            errno=500,
            errmsg=str(error),
        )
    if isinstance(error, Exception):
        return ApiError(
            errno=500,
            errmsg=str(error),
        )
    return ApiError(errno=500, errmsg="Unknown error")


class SkillsClient:
    """Client for communicating with the AgentSkills runtime."""

    def __init__(self, config: Optional[ClientConfig] = None) -> None:
        if config is None:
            config = ClientConfig()

        self.base_url = config.base_url or os.environ.get("SKILL_RUNTIME_API_URL", DEFAULT_BASE_URL)
        self.timeout = config.timeout / 1000 if config.timeout else DEFAULT_TIMEOUT / 1000

        self._session = requests.Session()

        retry_strategy = Retry(
            total=3,
            backoff_factor=0.5,
            status_forcelist=[502, 503, 504],
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self._session.mount("http://", adapter)
        self._session.mount("https://", adapter)

        headers = {"Content-Type": "application/json"}
        if config.auth_token:
            headers["Authorization"] = f"Bearer {config.auth_token}"
        self._session.headers.update(headers)

        self._runtime_manager = RuntimeManager(self.base_url)

    @property
    def runtime(self) -> RuntimeManager:
        """Get the runtime manager."""
        return self._runtime_manager

    def set_auth_token(self, token: str) -> None:
        """Set the authentication token."""
        self._session.headers["Authorization"] = f"Bearer {token}"

    def get_base_url(self) -> str:
        """Get the base URL."""
        return self.base_url

    def health_check(self) -> Dict[str, str]:
        """Check the health of the runtime."""
        try:
            response = self._session.get(f"{self.base_url}/hello", timeout=2)
            return {"status": "ok", "message": response.text}
        except Exception:
            return {"status": "error", "message": "Server not responding"}

    def list_skills(
        self,
        limit: int = 10,
        page: int = 0,
        skip: int = 0,
    ) -> SkillListResponse:
        """List installed skills."""
        params = {"limit": limit, "page": page}
        if skip > 0:
            params["skip"] = skip

        response = self._session.get(
            f"{self.base_url}/skills",
            params=params,
            timeout=self.timeout,
        )
        response.raise_for_status()
        data = response.json()

        skills = []
        for skill_data in data.get("skills", []):
            skills.append(self._parse_skill(skill_data))

        return SkillListResponse(
            current_page=data.get("current_page", 0),
            total_count=data.get("total_count", 0),
            total_page=data.get("total_page", 0),
            skills=skills,
        )

    def get_skill(self, skill_id: str) -> Skill:
        """Get a skill by ID."""
        response = self._session.get(
            f"{self.base_url}/skills/{skill_id}",
            timeout=self.timeout,
        )
        response.raise_for_status()
        return self._parse_skill(response.json())

    def install_skill(self, options: SkillInstallOptions) -> SkillInstallResponse:
        """Install a skill."""
        payload: Dict[str, Any] = {
            "source": options.source,
            "validate": options.validate,
        }
        if options.creator:
            payload["creator"] = options.creator
        if options.install_path:
            payload["install_path"] = options.install_path
        if options.branch:
            payload["branch"] = options.branch
        if options.tag:
            payload["tag"] = options.tag
        if options.commit:
            payload["commit"] = options.commit
        if options.skill_subpath:
            payload["skill_subpath"] = options.skill_subpath

        response = self._session.post(
            f"{self.base_url}/skills/add",
            json=payload,
            timeout=self.timeout,
        )
        response.raise_for_status()
        return self._parse_install_response(response.json())

    def install_skill_from_multi_repo(
        self,
        source: str,
        skill_path: str,
        options: Optional[SkillInstallOptions] = None,
    ) -> SkillInstallResponse:
        """Install a skill from a multi-skill repository."""
        if options is None:
            options = SkillInstallOptions(source=source)

        options.source = source
        options.skill_subpath = skill_path
        return self.install_skill(options)

    def is_multi_skill_repo_response(self, response: SkillInstallResponse) -> bool:
        """Check if the response is a multi-skill repository response."""
        return response.status == "multi_skill_repo" and response.available_skills is not None

    def uninstall_skill(self, skill_id: str) -> Dict[str, Any]:
        """Uninstall a skill."""
        response = self._session.post(
            f"{self.base_url}/skills/del",
            json={"id": skill_id},
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()

    def execute_skill(
        self,
        skill_id: str,
        params: Optional[Dict[str, Any]] = None,
    ) -> SkillExecutionResult:
        """Execute a skill."""
        if params is None:
            params = {}

        response = self._session.post(
            f"{self.base_url}/skills/execute",
            json={"skill_id": skill_id, "params": params},
            timeout=self.timeout,
        )
        response.raise_for_status()
        data = response.json()

        return SkillExecutionResult(
            success=data.get("success", False),
            output=data.get("output", ""),
            error_message=data.get("errorMessage") or data.get("error_message"),
            data=data.get("data"),
        )

    def execute_skill_tool(
        self,
        skill_id: str,
        tool_name: str,
        args: Optional[Dict[str, Any]] = None,
    ) -> SkillExecutionResult:
        """Execute a specific tool from a skill."""
        if args is None:
            args = {}

        response = self._session.post(
            f"{self.base_url}/skills/{skill_id}/tools/{tool_name}/run",
            json={"args": args},
            timeout=self.timeout,
        )
        response.raise_for_status()
        data = response.json()

        return SkillExecutionResult(
            success=data.get("success", False),
            output=data.get("output", ""),
            error_message=data.get("errorMessage") or data.get("error_message"),
            data=data.get("data"),
        )

    def search_skills(
        self,
        query: str,
        source: str = "all",
        limit: int = 10,
    ) -> SkillSearchResult:
        """Search for skills."""
        response = self._session.post(
            f"{self.base_url}/skills/search",
            json={"query": query, "source": source, "limit": limit},
            timeout=self.timeout,
        )
        response.raise_for_status()
        data = response.json()

        results = []
        for item in data.get("results", []):
            results.append(
                SkillSearchResultItem(
                    name=item.get("name", ""),
                    full_name=item.get("full_name", ""),
                    description=item.get("description", ""),
                    url=item.get("url"),
                    html_url=item.get("html_url"),
                    clone_url=item.get("clone_url", ""),
                    source=item.get("source", ""),
                    stars=item.get("stars") or item.get("stargazers_count"),
                    forks=item.get("forks") or item.get("forks_count"),
                    stargazers_count=item.get("stargazers_count"),
                    forks_count=item.get("forks_count"),
                    updated_at=item.get("updated_at", ""),
                    author=item.get("author"),
                    owner=item.get("owner"),
                    topics=item.get("topics"),
                    license=item.get("license"),
                )
            )

        return SkillSearchResult(
            total_count=data.get("total_count", 0),
            results=results,
        )

    def update_skill(self, skill_id: str, updates: Dict[str, Any]) -> Skill:
        """Update a skill."""
        payload = {"id": skill_id, **updates}
        response = self._session.post(
            f"{self.base_url}/skills/edit",
            json=payload,
            timeout=self.timeout,
        )
        response.raise_for_status()
        return self._parse_skill(response.json())

    def get_skill_config(self, skill_id: str) -> Dict[str, Any]:
        """Get skill configuration."""
        response = self._session.get(
            f"{self.base_url}/skills/{skill_id}/config",
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()

    def set_skill_config(
        self,
        skill_id: str,
        config: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Set skill configuration."""
        response = self._session.post(
            f"{self.base_url}/skills/{skill_id}/config",
            json=config,
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()

    def list_skill_tools(self, skill_id: str) -> List[ToolDefinition]:
        """List tools in a skill."""
        response = self._session.get(
            f"{self.base_url}/skills/{skill_id}/tools",
            timeout=self.timeout,
        )
        response.raise_for_status()
        data = response.json()

        tools = []
        for tool_data in data:
            tools.append(self._parse_tool_definition(tool_data))

        return tools

    def _parse_skill(self, data: Dict[str, Any]) -> Skill:
        """Parse a skill from API response."""
        tools = None
        if "tools" in data:
            tools = [self._parse_tool_definition(t) for t in data["tools"]]

        return Skill(
            id=data.get("id", ""),
            name=data.get("name", ""),
            version=data.get("version", ""),
            description=data.get("description", ""),
            author=data.get("author", ""),
            license=data.get("license"),
            format=data.get("format"),
            created_at=data.get("created_at"),
            updated_at=data.get("updated_at"),
            source_path=data.get("source_path", ""),
            metadata=data.get("metadata"),
            dependencies=data.get("dependencies"),
            tools=tools,
        )

    def _parse_tool_definition(self, data: Dict[str, Any]) -> ToolDefinition:
        """Parse a tool definition from API response."""
        parameters = []
        for p in data.get("parameters", []):
            parameters.append(ToolParameter.from_dict(p))

        return ToolDefinition(
            name=data.get("name", ""),
            description=data.get("description", ""),
            parameters=parameters,
        )

    def _parse_install_response(self, data: Dict[str, Any]) -> SkillInstallResponse:
        """Parse an install response from API."""
        available_skills = None
        if "available_skills" in data:
            available_skills = [
                AvailableSkillInfo(
                    name=s.get("name", ""),
                    description=s.get("description", ""),
                    relative_path=s.get("relative_path", ""),
                    full_path=s.get("full_path", ""),
                    depth=s.get("depth", 0),
                    parent_path=s.get("parent_path", ""),
                )
                for s in data["available_skills"]
            ]

        return SkillInstallResponse(
            id=data.get("id"),
            name=data.get("name"),
            status=data.get("status", ""),
            message=data.get("message", ""),
            created_at=data.get("created_at"),
            source_type=data.get("source_type"),
            source_url=data.get("source_url"),
            available_skills=available_skills,
            total_count=data.get("total_count"),
        )


def create_client(config: Optional[ClientConfig] = None) -> SkillsClient:
    """Create a new SkillsClient instance."""
    return SkillsClient(config)
