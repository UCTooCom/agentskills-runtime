<?php

namespace AgentSkills\Tests;

use PHPUnit\Framework\TestCase;
use AgentSkills\Skill;
use AgentSkills\ToolDefinition;
use AgentSkills\ToolParameter;
use AgentSkills\ToolParameterType;

class SkillTest extends TestCase
{
    public function testCreateSkill(): void
    {
        $tools = [
            new ToolDefinition(
                name: 'my-tool',
                description: 'A tool',
                parameters: [
                    new ToolParameter(
                        name: 'input',
                        paramType: ToolParameterType::String,
                        description: 'Input parameter',
                        required: true,
                    ),
                ],
            ),
        ];

        $skill = new Skill(
            id: 'skill-123',
            name: 'test-skill',
            version: '1.0.0',
            description: 'Test skill',
            author: 'Test Author',
            source_path: '/path/to/skill',
            tools: $tools,
        );

        $this->assertEquals('skill-123', $skill->id);
        $this->assertEquals('test-skill', $skill->name);
        $this->assertEquals('1.0.0', $skill->version);
        $this->assertEquals('Test skill', $skill->description);
        $this->assertEquals('Test Author', $skill->author);
        $this->assertEquals('/path/to/skill', $skill->source_path);
    }

    public function testToArray(): void
    {
        $tools = [
            new ToolDefinition(
                name: 'my-tool',
                description: 'A tool',
                parameters: [],
            ),
        ];

        $skill = new Skill(
            id: 'skill-123',
            name: 'test-skill',
            version: '1.0.0',
            description: 'Test skill',
            author: 'Test Author',
            source_path: '/path/to/skill',
            tools: $tools,
        );

        $array = $skill->toArray();

        $this->assertArrayHasKey('id', $array);
        $this->assertArrayHasKey('name', $array);
        $this->assertArrayHasKey('version', $array);
        $this->assertArrayHasKey('description', $array);
        $this->assertArrayHasKey('author', $array);
        $this->assertArrayHasKey('source_path', $array);
        $this->assertArrayHasKey('tools', $array);
    }

    public function testFromArray(): void
    {
        $data = [
            'id' => 'skill-123',
            'name' => 'test-skill',
            'version' => '1.0.0',
            'description' => 'Test skill',
            'author' => 'Test Author',
            'source_path' => '/path/to/skill',
            'tools' => [],
        ];

        $skill = Skill::fromArray($data);

        $this->assertEquals('skill-123', $skill->id);
        $this->assertEquals('test-skill', $skill->name);
        $this->assertEquals('1.0.0', $skill->version);
        $this->assertEquals('Test skill', $skill->description);
        $this->assertEquals('Test Author', $skill->author);
        $this->assertEquals('/path/to/skill', $skill->source_path);
    }
}