<?php

namespace AgentSkills;

class SkillMetadata
{
    public function __construct(
        public readonly string $name,
        public readonly string $version,
        public readonly string $description,
        public readonly string $author,
        public readonly ?string $license = null,
        public readonly ?string $format = null,
        public readonly ?string $created_at = null,
        public readonly ?string $updated_at = null,
    ) {}

    public function toArray(): array
    {
        return array_filter([
            'name' => $this->name,
            'version' => $this->version,
            'description' => $this->description,
            'author' => $this->author,
            'license' => $this->license,
            'format' => $this->format,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ], fn($value) => $value !== null);
    }

    public static function fromArray(array $data): self
    {
        return new self(
            name: $data['name'],
            version: $data['version'],
            description: $data['description'],
            author: $data['author'],
            license: $data['license'] ?? null,
            format: $data['format'] ?? null,
            created_at: $data['created_at'] ?? null,
            updated_at: $data['updated_at'] ?? null,
        );
    }
}