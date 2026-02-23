<?php

namespace AgentSkills;

class AvailableSkillInfo
{
    public function __construct(
        public readonly string $name,
        public readonly string $description,
        public readonly string $relative_path,
        public readonly string $full_path,
        public readonly int $depth,
        public readonly string $parent_path,
    ) {}

    public function toArray(): array
    {
        return [
            'name' => $this->name,
            'description' => $this->description,
            'relative_path' => $this->relative_path,
            'full_path' => $this->full_path,
            'depth' => $this->depth,
            'parent_path' => $this->parent_path,
        ];
    }

    public static function fromArray(array $data): self
    {
        return new self(
            name: $data['name'],
            description: $data['description'],
            relative_path: $data['relative_path'],
            full_path: $data['full_path'],
            depth: $data['depth'],
            parent_path: $data['parent_path'],
        );
    }
}