"""Tests for AgentSkills SDK models."""

import pytest

from agent_skills.models import (
    ParamType,
    Skill,
    SkillMetadata,
    ToolDefinition,
    ToolParameter,
)


class TestSkillMetadata:
    """Tests for SkillMetadata."""

    def test_create_skill_metadata(self) -> None:
        """Test creating a SkillMetadata instance."""
        metadata = SkillMetadata(
            name="test-skill",
            version="1.0.0",
            description="A test skill",
            author="Test Author",
        )
        assert metadata.name == "test-skill"
        assert metadata.version == "1.0.0"
        assert metadata.description == "A test skill"
        assert metadata.author == "Test Author"
        assert metadata.license is None


class TestSkill:
    """Tests for Skill."""

    def test_create_skill(self) -> None:
        """Test creating a Skill instance."""
        skill = Skill(
            id="test-id",
            name="test-skill",
            version="1.0.0",
            description="A test skill",
            author="Test Author",
            source_path="/path/to/skill",
        )
        assert skill.id == "test-id"
        assert skill.name == "test-skill"
        assert skill.version == "1.0.0"


class TestToolParameter:
    """Tests for ToolParameter."""

    def test_create_tool_parameter(self) -> None:
        """Test creating a ToolParameter instance."""
        param = ToolParameter(
            name="input",
            param_type=ParamType.STRING,
            description="Input parameter",
            required=True,
        )
        assert param.name == "input"
        assert param.param_type == ParamType.STRING
        assert param.description == "Input parameter"
        assert param.required is True

    def test_tool_parameter_to_dict(self) -> None:
        """Test converting ToolParameter to dict."""
        param = ToolParameter(
            name="input",
            param_type=ParamType.STRING,
            description="Input parameter",
            required=True,
            default_value="default",
        )
        result = param.to_dict()
        assert result["name"] == "input"
        assert result["paramType"] == "string"
        assert result["description"] == "Input parameter"
        assert result["required"] is True
        assert result["defaultValue"] == "default"

    def test_tool_parameter_from_dict(self) -> None:
        """Test creating ToolParameter from dict."""
        data = {
            "name": "input",
            "paramType": "number",
            "description": "A number",
            "required": False,
            "defaultValue": 0,
        }
        param = ToolParameter.from_dict(data)
        assert param.name == "input"
        assert param.param_type == ParamType.NUMBER
        assert param.description == "A number"
        assert param.required is False
        assert param.default_value == 0


class TestToolDefinition:
    """Tests for ToolDefinition."""

    def test_create_tool_definition(self) -> None:
        """Test creating a ToolDefinition instance."""
        param = ToolParameter(
            name="input",
            param_type=ParamType.STRING,
            description="Input",
            required=True,
        )
        tool = ToolDefinition(
            name="test-tool",
            description="A test tool",
            parameters=[param],
        )
        assert tool.name == "test-tool"
        assert tool.description == "A test tool"
        assert len(tool.parameters) == 1

    def test_tool_definition_to_dict(self) -> None:
        """Test converting ToolDefinition to dict."""
        param = ToolParameter(
            name="input",
            param_type=ParamType.STRING,
            description="Input",
            required=True,
        )
        tool = ToolDefinition(
            name="test-tool",
            description="A test tool",
            parameters=[param],
        )
        result = tool.to_dict()
        assert result["name"] == "test-tool"
        assert result["description"] == "A test tool"
        assert len(result["parameters"]) == 1

    def test_tool_definition_from_dict(self) -> None:
        """Test creating ToolDefinition from dict."""
        data = {
            "name": "test-tool",
            "description": "A test tool",
            "parameters": [
                {
                    "name": "input",
                    "paramType": "string",
                    "description": "Input",
                    "required": True,
                }
            ],
        }
        tool = ToolDefinition.from_dict(data)
        assert tool.name == "test-tool"
        assert tool.description == "A test tool"
        assert len(tool.parameters) == 1
        assert tool.parameters[0].name == "input"
