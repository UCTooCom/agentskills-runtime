<?php

namespace AgentSkills;

class RuntimeOptions
{
    public function __construct(
        public readonly ?int $port = null,
        public readonly ?string $host = null,
        public readonly ?bool $detached = null,
        public readonly ?string $cwd = null,
        public readonly ?array $env = null,
        public readonly ?string $skillInstallPath = null,
    ) {}

    public function toArray(): array
    {
        return array_filter([
            'port' => $this->port,
            'host' => $this->host,
            'detached' => $this->detached,
            'cwd' => $this->cwd,
            'env' => $this->env,
            'skillInstallPath' => $this->skillInstallPath,
        ], fn($value) => $value !== null);
    }
}