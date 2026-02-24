<?php

namespace AgentSkills;

class MultiSkillRepoResponse
{
    public function __construct(
        public readonly string $status,
        public readonly string $message,
        public readonly array $available_skills,
        public readonly int $total_count,
        public readonly string $source_url,
    ) {}

    public function toArray(): array
    {
        return [
            'status' => $this->status,
            'message' => $this->message,
            'available_skills' => array_map(
                fn($skill) => $skill instanceof AvailableSkillInfo ? $skill->toArray() : $skill,
                $this->available_skills
            ),
            'total_count' => $this->total_count,
            'source_url' => $this->source_url,
        ];
    }

    public static function fromArray(array $data): self
    {
        return new self(
            status: $data['status'],
            message: $data['message'],
            available_skills: array_map(
                fn($skill) => is_array($skill) ? AvailableSkillInfo::fromArray($skill) : $skill,
                $data['available_skills'] ?? []
            ),
            total_count: $data['total_count'],
            source_url: $data['source_url'],
        );
    }
}