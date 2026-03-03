<?php

namespace AgentSkills\Tests;

use PHPUnit\Framework\TestCase;
use AgentSkills\RuntimeStatus;

class RuntimeStatusTest extends TestCase
{
    public function testCreateRuntimeStatus(): void
    {
        $status = new RuntimeStatus(
            running: true,
            version: '0.0.16',
            sdkVersion: '0.0.1',
            pid: 12345,
            port: 8080,
        );

        $this->assertTrue($status->running);
        $this->assertEquals('0.0.16', $status->version);
        $this->assertEquals('0.0.1', $status->sdkVersion);
        $this->assertEquals(12345, $status->pid);
        $this->assertEquals(8080, $status->port);
    }

    public function testCreateRuntimeStatusWithDefaults(): void
    {
        $status = new RuntimeStatus(
            running: false,
        );

        $this->assertFalse($status->running);
        $this->assertNull($status->version);
        $this->assertNull($status->sdkVersion);
        $this->assertNull($status->pid);
        $this->assertNull($status->port);
    }

    public function testToArray(): void
    {
        $status = new RuntimeStatus(
            running: true,
            version: '0.0.16',
        );

        $array = $status->toArray();

        $this->assertArrayHasKey('running', $array);
        $this->assertArrayHasKey('version', $array);
        $this->assertTrue($array['running']);
        $this->assertEquals('0.0.16', $array['version']);
    }

    public function testFromArray(): void
    {
        $data = [
            'running' => true,
            'version' => '0.0.16',
            'sdkVersion' => '0.0.1',
        ];

        $status = RuntimeStatus::fromArray($data);

        $this->assertTrue($status->running);
        $this->assertEquals('0.0.16', $status->version);
        $this->assertEquals('0.0.1', $status->sdkVersion);
    }
}