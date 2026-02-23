<?php

namespace AgentSkills;

class ToolDefinition
{
    public function __construct(
        public readonly string $name,
        public readonly string $description,
        public readonly array $parameters = [],
    ) {}

    public function toArray(): array
    {
        return [
            'name' => $this->name,
            'description' => $this->description,
            'parameters' => array_map(
                fn($param) => $param instanceof ToolParameter ? $param->toArray() : $param,
                $this->parameters
            ),
        ];
    }

    public static function fromArray(array $data): self
    {
        return new self(
            name: $data['name'],
            description: $data['description'],
            parameters: array_map(
                fn($param) => ToolParameter::fromArray($param),
                $data['parameters'] ?? []
            ),
        );
    }
}