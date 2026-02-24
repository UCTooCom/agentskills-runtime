<?php

namespace AgentSkills;

class SkillExecutionResult
{
    public function __construct(
        public readonly bool $success,
        public readonly string $output,
        public readonly ?string $errorMessage = null,
        public readonly ?array $data = null,
    ) {}

    public function toArray(): array
    {
        return array_filter([
            'success' => $this->success,
            'output' => $this->output,
            'errorMessage' => $this->errorMessage,
            'data' => $this->data,
        ], fn($value) => $value !== null);
    }

    public static function fromArray(array $data): self
    {
        return new self(
            success: $data['success'],
            output: $data['output'],
            errorMessage: $data['errorMessage'] ?? null,
            data: $data['data'] ?? null,
        );
    }
}