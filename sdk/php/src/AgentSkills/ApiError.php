<?php

namespace AgentSkills;

class ApiError
{
    public function __construct(
        public readonly int $errno,
        public readonly string $errmsg,
        public readonly ?array $details = null,
    ) {}

    public function toArray(): array
    {
        $data = [
            'errno' => $this->errno,
            'errmsg' => $this->errmsg,
        ];

        if ($this->details !== null) {
            $data['details'] = $this->details;
        }

        return $data;
    }

    public static function fromArray(array $data): self
    {
        return new self(
            errno: $data['errno'],
            errmsg: $data['errmsg'],
            details: $data['details'] ?? null,
        );
    }
}