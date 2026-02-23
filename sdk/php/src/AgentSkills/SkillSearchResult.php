<?php

namespace AgentSkills;

class SkillSearchResult
{
    public function __construct(
        public readonly int $total_count,
        public readonly array $results,
    ) {}

    public function toArray(): array
    {
        return [
            'total_count' => $this->total_count,
            'results' => array_map(
                fn($result) => $result instanceof SkillSearchResultItem ? $result->toArray() : $result,
                $this->results
            ),
        ];
    }

    public static function fromArray(array $data): self
    {
        return new self(
            total_count: $data['total_count'],
            results: array_map(
                fn($result) => is_array($result) ? SkillSearchResultItem::fromArray($result) : $result,
                $data['results'] ?? []
            ),
        );
    }
}