<?php

namespace AgentSkills;

class SkillInstallResponse
{
    public function __construct(
        public readonly string $status,
        public readonly string $message,
        public readonly ?string $id = null,
        public readonly ?string $name = null,
        public readonly ?string $created_at = null,
        public readonly ?string $source_type = null,
        public readonly ?string $source_url = null,
        public readonly ?array $available_skills = null,
        public readonly ?int $total_count = null,
    ) {}

    public function toArray(): array
    {
        return array_filter([
            'status' => $this->status,
            'message' => $this->message,
            'id' => $this->id,
            'name' => $this->name,
            'created_at' => $this->created_at,
            'source_type' => $this->source_type,
            'source_url' => $this->source_url,
            'available_skills' => $this->available_skills ? array_map(
                fn($skill) => $skill instanceof AvailableSkillInfo ? $skill->toArray() : $skill,
                $this->available_skills
            ) : null,
            'total_count' => $this->total_count,
        ], fn($value) => $value !== null);
    }

    public static function fromArray(array $data): self
    {
        return new self(
            status: $data['status'],
            message: $data['message'],
            id: $data['id'] ?? null,
            name: $data['name'] ?? null,
            created_at: $data['created_at'] ?? null,
            source_type: $data['source_type'] ?? null,
            source_url: $data['source_url'] ?? null,
            available_skills: isset($data['available_skills']) ? array_map(
                fn($skill) => is_array($skill) ? AvailableSkillInfo::fromArray($skill) : $skill,
                $data['available_skills']
            ) : null,
            total_count: $data['total_count'] ?? null,
        );
    }

    public function isMultiSkillRepo(): bool
    {
        return $this->status === 'multi_skill_repo' && $this->available_skills !== null;
    }
}