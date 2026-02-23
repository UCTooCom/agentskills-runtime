"""Tests for AgentSkills SDK client."""

import pytest
from unittest.mock import Mock, patch
import requests

from agent_skills.client import SkillsClient, create_client, handle_api_error
from agent_skills.models import ClientConfig


class TestCreateClient:
    """Tests for create_client function."""

    def test_create_client_default(self) -> None:
        """Test creating a client with default config."""
        client = create_client()
        assert isinstance(client, SkillsClient)

    def test_create_client_with_config(self) -> None:
        """Test creating a client with custom config."""
        config = ClientConfig(
            base_url="http://custom:9090",
            auth_token="test-token",
            timeout=5000,
        )
        client = create_client(config)
        assert client.base_url == "http://custom:9090"


class TestHandleApiError:
    """Tests for handle_api_error function."""

    def test_handle_connection_error(self) -> None:
        """Test handling connection error."""
        error = requests.exceptions.ConnectionError("Connection refused")
        result = handle_api_error(error)
        assert result.errno == 503
        assert "not responding" in result.errmsg

    def test_handle_timeout_error(self) -> None:
        """Test handling timeout error."""
        error = requests.exceptions.Timeout("Request timed out")
        result = handle_api_error(error)
        assert result.errno == 504
        assert "timed out" in result.errmsg.lower()

    def test_handle_generic_error(self) -> None:
        """Test handling generic error."""
        error = Exception("Something went wrong")
        result = handle_api_error(error)
        assert result.errno == 500
        assert "Something went wrong" in result.errmsg


class TestSkillsClient:
    """Tests for SkillsClient class."""

    def test_get_base_url(self) -> None:
        """Test get_base_url method."""
        client = SkillsClient(ClientConfig(base_url="http://test:8080"))
        assert client.get_base_url() == "http://test:8080"

    def test_set_auth_token(self) -> None:
        """Test set_auth_token method."""
        client = SkillsClient()
        client.set_auth_token("new-token")
        assert client._session.headers["Authorization"] == "Bearer new-token"

    @patch("requests.Session.get")
    def test_health_check_success(self, mock_get: Mock) -> None:
        """Test health_check with successful response."""
        mock_response = Mock()
        mock_response.text = "OK"
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        client = SkillsClient()
        result = client.health_check()

        assert result["status"] == "ok"
        assert result["message"] == "OK"

    @patch("requests.Session.get")
    def test_health_check_failure(self, mock_get: Mock) -> None:
        """Test health_check with failed response."""
        mock_get.side_effect = requests.exceptions.ConnectionError()

        client = SkillsClient()
        result = client.health_check()

        assert result["status"] == "error"
        assert "not responding" in result["message"]
