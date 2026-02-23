<?php

namespace AgentSkills\Tests;

use PHPUnit\Framework\TestCase;
use AgentSkills\ToolDefinition;
use AgentSkills\ToolParameter;
use AgentSkills\ToolParameterType;

class ToolDefinitionTest extends TestCase
{
    public function testCreateToolDefinition(): void
    {
        $params = [
            new ToolParameter(
                name: 'input',
                paramType: ToolParameterType::String,
                description: 'Input parameter',
                required: true,
            ),
        ];

        $tool = new ToolDefinition(
            name: 'my-tool',
            description: 'A tool',
            parameters: $params,
        );

        $this->assertEquals('my-tool', $tool->name);
        $this->assertEquals('A tool', $tool->description);
        $this->assertCount(1, $tool->parameters);
    }

    public function testToArray(): void
    {
        $params = [
            new ToolParameter(
                name: 'input',
                paramType: ToolParameterType::String,
                description: 'Input parameter',
                required: true,
            ),
        ];

        $tool = new ToolDefinition(
            name: 'my-tool',
            description: 'A tool',
            parameters: $params,
        );

        $array = $tool->toArray();

        $this->assertArrayHasKey('name', $array);
        $this->assertArrayHasKey('description', $array);
        $this->assertArrayHasKey('parameters', $array);
        $this->assertCount(1, $array['parameters']);
    }

    public function testFromArray(): void
    {
        $data = [
            'name' => 'my-tool',
            'description' => 'A tool',
            'parameters' => [
                [
                    'name' => 'input',
                    'paramType' => 'string',
                    'description' => 'Input parameter',
                    'required' => true,
                ],
            ],
        ];

        $tool = ToolDefinition::fromArray($data);

        $this->assertEquals('my-tool', $tool->name);
        $this->assertEquals('A tool', $tool->description);
        $this->assertCount(1, $tool->parameters);
    }
}