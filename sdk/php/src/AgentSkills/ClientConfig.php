<?php

namespace AgentSkills;

class ClientConfig
{
    public function __construct(
        public readonly ?string $baseUrl = null,
        public readonly ?string $authToken = null,
        public readonly ?int $timeout = null,
    ) {}

    public function toArray(): array
    {
        return array_filter([
            'baseUrl' => $this->baseUrl,
            'authToken' => $this->authToken,
            'timeout' => $this->timeout,
        ], fn($value) => $value !== null);
    }
}