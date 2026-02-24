<?php

namespace AgentSkills\Tests;

use PHPUnit\Framework\TestCase;
use AgentSkills\ClientConfig;

class ClientConfigTest extends TestCase
{
    public function testCreateClientConfig(): void
    {
        $config = new ClientConfig(
            baseUrl: 'http://127.0.0.1:8080',
            authToken: 'test-token',
            timeout: 30000,
        );

        $this->assertEquals('http://127.0.0.1:8080', $config->baseUrl);
        $this->assertEquals('test-token', $config->authToken);
        $this->assertEquals(30000, $config->timeout);
    }

    public function testCreateClientConfigWithDefaults(): void
    {
        $config = new ClientConfig();

        $this->assertNull($config->baseUrl);
        $this->assertNull($config->authToken);
        $this->assertNull($config->timeout);
    }

    public function testToArray(): void
    {
        $config = new ClientConfig(
            baseUrl: 'http://127.0.0.1:8080',
        );

        $array = $config->toArray();

        $this->assertArrayHasKey('baseUrl', $array);
        $this->assertEquals('http://127.0.0.1:8080', $array['baseUrl']);
    }
}