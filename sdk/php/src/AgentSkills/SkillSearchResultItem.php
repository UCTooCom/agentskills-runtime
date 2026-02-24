<?php

namespace AgentSkills;

class SkillSearchResultItem
{
    public function __construct(
        public readonly string $name,
        public readonly string $full_name,
        public readonly string $description,
        public readonly string $clone_url,
        public readonly string $source,
        public readonly ?string $url = null,
        public readonly ?string $html_url = null,
        public readonly ?int $stars = null,
        public readonly ?int $forks = null,
        public readonly ?int $stargazers_count = null,
        public readonly ?int $forks_count = null,
        public readonly string $updated_at,
        public readonly ?string $author = null,
        public readonly ?array $owner = null,
        public readonly ?array $topics = null,
        public readonly ?string $license = null,
    ) {}

    public function toArray(): array
    {
        return array_filter([
            'name' => $this->name,
            'full_name' => $this->full_name,
            'description' => $this->description,
            'url' => $this->url,
            'html_url' => $this->html_url,
            'clone_url' => $this->clone_url,
            'source' => $this->source,
            'stars' => $this->stars,
            'forks' => $this->forks,
            'stargazers_count' => $this->stargazers_count,
            'forks_count' => $this->forks_count,
            'updated_at' => $this->updated_at,
            'author' => $this->author,
            'owner' => $this->owner,
            'topics' => $this->topics,
            'license' => $this->license,
        ], fn($value) => $value !== null);
    }

    public static function fromArray(array $data): self
    {
        return new self(
            name: $data['name'],
            full_name: $data['full_name'],
            description: $data['description'],
            clone_url: $data['clone_url'],
            source: $data['source'],
            url: $data['url'] ?? null,
            html_url: $data['html_url'] ?? null,
            stars: $data['stars'] ?? null,
            forks: $data['forks'] ?? null,
            stargazers_count: $data['stargazers_count'] ?? null,
            forks_count: $data['forks_count'] ?? null,
            updated_at: $data['updated_at'],
            author: $data['author'] ?? null,
            owner: $data['owner'] ?? null,
            topics: $data['topics'] ?? null,
            license: $data['license'] ?? null,
        );
    }
}