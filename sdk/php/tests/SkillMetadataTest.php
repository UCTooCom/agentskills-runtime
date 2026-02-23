<?php

namespace AgentSkills\Tests;

use PHPUnit\Framework\TestCase;
use AgentSkills\SkillMetadata;

class SkillMetadataTest extends TestCase
{
    public function testCreateSkillMetadata(): void
    {
        $metadata = new SkillMetadata(
            name: 'test-skill',
            version: '1.0.0',
            description: 'Test skill',
            author: 'Test Author',
        );

        $this->assertEquals('test-skill', $metadata->name);
        $this->assertEquals('1.0.0', $metadata->version);
        $this->assertEquals('Test skill', $metadata->description);
        $this->assertEquals('Test Author', $metadata->author);
    }

    public function testToArray(): void
    {
        $metadata = new SkillMetadata(
            name: 'test-skill',
            version: '1.0.0',
            description: 'Test skill',
            author: 'Test Author',
            license: 'MIT',
        );

        $array = $metadata->toArray();

        $this->assertArrayHasKey('name', $array);
        $this->assertArrayHasKey('version', $array);
        $this->assertArrayHasKey('description', $array);
        $this->assertArrayHasKey('author', $array);
        $this->assertArrayHasKey('license', $array);
        $this->assertEquals('test-skill', $array['name']);
    }

    public function testFromArray(): void
    {
        $data = [
            'name' => 'test-skill',
            'version' => '1.0.0',
            'description' => 'Test skill',
            'author' => 'Test Author',
        ];

        $metadata = SkillMetadata::fromArray($data);

        $this->assertEquals('test-skill', $metadata->name);
        $this->assertEquals('1.0.0', $metadata->version);
        $this->assertEquals('Test skill', $metadata->description);
        $this->assertEquals('Test Author', $metadata->author);
    }
}