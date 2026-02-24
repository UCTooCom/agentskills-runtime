<?php

namespace AgentSkills;

class Skill
{
    public function __construct(
        public readonly string $id,
        public readonly string $name,
        public readonly string $version,
        public readonly string $description,
        public readonly string $author,
        public readonly string $source_path,
        public readonly ?array $metadata = null,
        public readonly ?array $dependencies = null,
        public readonly ?array $tools = null,
        public readonly ?string $license = null,
        public readonly ?string $format = null,
        public readonly ?string $created_at = null,
        public readonly ?string $updated_at = null,
    ) {}

    public function toArray(): array
    {
        return array_filter([
            'id' => $this->id,
            'name' => $this->name,
            'version' => $this->version,
            'description' => $this->description,
            'author' => $this->author,
            'source_path' => $this->source_path,
            'metadata' => $this->metadata,
            'dependencies' => $this->dependencies,
            'tools' => $this->tools ? array_map(
                fn($tool) => $tool instanceof ToolDefinition ? $tool->toArray() : $tool,
                $this->tools
            ) : null,
            'license' => $this->license,
            'format' => $this->format,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ], fn($value) => $value !== null);
    }

    public static function fromArray(array $data): self
    {
        return new self(
            id: $data['id'],
            name: $data['name'],
            version: $data['version'],
            description: $data['description'],
            author: $data['author'],
            source_path: $data['source_path'],
            metadata: $data['metadata'] ?? null,
            dependencies: $data['dependencies'] ?? null,
            tools: isset($data['tools']) ? array_map(
                fn($tool) => is_array($tool) ? ToolDefinition::fromArray($tool) : $tool,
                $data['tools']
            ) : null,
            license: $data['license'] ?? null,
            format: $data['format'] ?? null,
            created_at: $data['created_at'] ?? null,
            updated_at: $data['updated_at'] ?? null,
        );
    }
}