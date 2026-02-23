<?php

namespace AgentSkills\Tests;

use PHPUnit\Framework\TestCase;
use AgentSkills\ToolParameter;
use AgentSkills\ToolParameterType;

class ToolParameterTest extends TestCase
{
    public function testCreateToolParameter(): void
    {
        $param = new ToolParameter(
            name: 'input',
            paramType: ToolParameterType::String,
            description: 'Input parameter',
            required: true,
        );

        $this->assertEquals('input', $param->name);
        $this->assertEquals(ToolParameterType::String, $param->paramType);
        $this->assertEquals('Input parameter', $param->description);
        $this->assertTrue($param->required);
    }

    public function testToArray(): void
    {
        $param = new ToolParameter(
            name: 'input',
            paramType: ToolParameterType::String,
            description: 'Input parameter',
            required: true,
            defaultValue: 'default',
        );

        $array = $param->toArray();

        $this->assertArrayHasKey('name', $array);
        $this->assertArrayHasKey('paramType', $array);
        $this->assertArrayHasKey('description', $array);
        $this->assertArrayHasKey('required', $array);
        $this->assertArrayHasKey('defaultValue', $array);
        $this->assertEquals('string', $array['paramType']);
    }

    public function testFromArray(): void
    {
        $data = [
            'name' => 'input',
            'paramType' => 'string',
            'description' => 'Input parameter',
            'required' => true,
        ];

        $param = ToolParameter::fromArray($data);

        $this->assertEquals('input', $param->name);
        $this->assertEquals(ToolParameterType::String, $param->paramType);
        $this->assertEquals('Input parameter', $param->description);
        $this->assertTrue($param->required);
    }
}