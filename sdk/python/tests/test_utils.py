"""Tests for AgentSkills SDK utilities."""

import os

from agent_skills.utils import get_config, get_sdk_version, get_runtime_version


class TestGetConfig:
    """Tests for get_config function."""

    def test_get_config_empty(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Test get_config with no SKILL_ environment variables."""
        monkeypatch.delenv("SKILL_TEST", raising=False)
        config = get_config()
        assert isinstance(config, dict)

    def test_get_config_with_skill_env(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Test get_config with SKILL_ environment variables."""
        monkeypatch.setenv("SKILL_API_KEY", "test-key")
        monkeypatch.setenv("SKILL_ENDPOINT", "http://localhost:8080")
        monkeypatch.setenv("OTHER_VAR", "should-not-appear")

        config = get_config()

        assert "API_KEY" in config
        assert config["API_KEY"] == "test-key"
        assert "ENDPOINT" in config
        assert config["ENDPOINT"] == "http://localhost:8080"
        assert "OTHER_VAR" not in config


class TestVersionFunctions:
    """Tests for version functions."""

    def test_get_sdk_version(self) -> None:
        """Test get_sdk_version returns a string."""
        version = get_sdk_version()
        assert isinstance(version, str)
        assert len(version) > 0

    def test_get_runtime_version(self) -> None:
        """Test get_runtime_version returns a string."""
        version = get_runtime_version()
        assert isinstance(version, str)
        assert len(version) > 0
