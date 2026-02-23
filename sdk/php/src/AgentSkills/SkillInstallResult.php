<?php

namespace AgentSkills;

class SkillInstallResult
{
    public function __construct(
        public readonly string $id,
        public readonly string $name,
        public readonly string $status,
        public readonly string $message,
        public readonly string $created_at,
    ) {}

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'status' => $this->status,
            'message' => $this->message,
            'created_at' => $this->created_at,
        ];
    }

    public static function fromArray(array $data): self
    {
        return new self(
            id: $data['id'],
            name: $data['name'],
            status: $data['status'],
            message: $data['message'],
            created_at: $data['created_at'],
        );
    }
}