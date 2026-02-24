<?php

namespace AgentSkills\Tests;

use PHPUnit\Framework\TestCase;
use AgentSkills\RuntimeOptions;

class RuntimeOptionsTest extends TestCase
{
    public function testCreateRuntimeOptions(): void
    {
        $options = new RuntimeOptions(
            port: 9000,
            host: '0.0.0.0',
            detached: true,
            skillInstallPath: '/path/to/skills',
        );

        $this->assertEquals(9000, $options->port);
        $this->assertEquals('0.0.0.0', $options->host);
        $this->assertTrue($options->detached);
        $this->assertEquals('/path/to/skills', $options->skillInstallPath);
    }

    public function testCreateRuntimeOptionsWithDefaults(): void
    {
        $options = new RuntimeOptions();

        $this->assertNull($options->port);
        $this->assertNull($options->host);
        $this->assertNull($options->detached);
        $this->assertNull($options->skillInstallPath);
    }

    public function testToArray(): void
    {
        $options = new RuntimeOptions(
            port: 9000,
        );

        $array = $options->toArray();

        $this->assertArrayHasKey('port', $array);
        $this->assertEquals(9000, $array['port']);
    }
}