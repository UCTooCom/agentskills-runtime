<?php

namespace AgentSkills;

class SkillListResponse
{
    public function __construct(
        public readonly int $current_page,
        public readonly int $total_count,
        public readonly int $total_page,
        public readonly array $skills,
    ) {}

    public function toArray(): array
    {
        return [
            'current_page' => $this->current_page,
            'total_count' => $this->total_count,
            'total_page' => $this->total_page,
            'skills' => array_map(
                fn($skill) => $skill instanceof Skill ? $skill->toArray() : $skill,
                $this->skills
            ),
        ];
    }

    public static function fromArray(array $data): self
    {
        return new self(
            current_page: $data['current_page'],
            total_count: $data['total_count'],
            total_page: $data['total_page'],
            skills: array_map(
                fn($skill) => is_array($skill) ? Skill::fromArray($skill) : $skill,
                $data['skills'] ?? []
            ),
        );
    }
}