<?php

namespace AgentSkills;

enum ToolParameterType: string
{
    case String = 'string';
    case Number = 'number';
    case Boolean = 'boolean';
    case File = 'file';
    case Array = 'array';
    case Object = 'object';
}

class ToolParameter
{
    public function __construct(
        public readonly string $name,
        public readonly ToolParameterType $paramType,
        public readonly string $description,
        public readonly bool $required = false,
        public readonly string|int|bool|null $defaultValue = null,
    ) {}

    public function toArray(): array
    {
        $data = [
            'name' => $this->name,
            'paramType' => $this->paramType->value,
            'description' => $this->description,
            'required' => $this->required,
        ];

        if ($this->defaultValue !== null) {
            $data['defaultValue'] = $this->defaultValue;
        }

        return $data;
    }

    public static function fromArray(array $data): self
    {
        return new self(
            name: $data['name'],
            paramType: ToolParameterType::from($data['paramType']),
            description: $data['description'],
            required: $data['required'] ?? false,
            defaultValue: $data['defaultValue'] ?? null,
        );
    }
}