<?php

namespace AgentSkills;

class RuntimeStatus
{
    public function __construct(
        public readonly bool $running,
        public readonly ?string $version = null,
        public readonly ?string $sdkVersion = null,
        public readonly ?int $pid = null,
        public readonly ?int $port = null,
    ) {}

    public function toArray(): array
    {
        return array_filter([
            'running' => $this->running,
            'version' => $this->version,
            'sdkVersion' => $this->sdkVersion,
            'pid' => $this->pid,
            'port' => $this->port,
        ], fn($value) => $value !== null);
    }

    public static function fromArray(array $data): self
    {
        return new self(
            running: $data['running'],
            version: $data['version'] ?? null,
            sdkVersion: $data['sdkVersion'] ?? null,
            pid: $data['pid'] ?? null,
            port: $data['port'] ?? null,
        );
    }
}