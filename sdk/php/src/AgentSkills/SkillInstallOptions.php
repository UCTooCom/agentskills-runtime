<?php

namespace AgentSkills;

class SkillInstallOptions
{
    public function __construct(
        public readonly string $source,
        public readonly ?bool $validate = null,
        public readonly ?string $creator = null,
        public readonly ?string $install_path = null,
        public readonly ?string $branch = null,
        public readonly ?string $tag = null,
        public readonly ?string $commit = null,
    ) {}

    public function toArray(): array
    {
        return array_filter([
            'source' => $this->source,
            'validate' => $this->validate,
            'creator' => $this->creator,
            'install_path' => $this->install_path,
            'branch' => $this->branch,
            'tag' => $this->tag,
            'commit' => $this->commit,
        ], fn($value) => $value !== null);
    }
}