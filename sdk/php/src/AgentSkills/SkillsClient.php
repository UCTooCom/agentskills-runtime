<?php

namespace AgentSkills;

use GuzzleHttp\Client as GuzzleClient;
use GuzzleHttp\Exception\GuzzleException;
use GuzzleHttp\Exception\RequestException;

class SkillsClient
{
    private const DEFAULT_BASE_URL = 'http://127.0.0.1:8080';
    private const DEFAULT_TIMEOUT = 30000;

    private GuzzleClient $client;
    private string $baseUrl;
    private RuntimeManager $runtimeManager;

    public function __construct(?ClientConfig $config = null)
    {
        $config = $config ?? new ClientConfig();
        
        $this->baseUrl = $config->baseUrl ?? getenv('SKILL_RUNTIME_API_URL') ?: self::DEFAULT_BASE_URL;
        
        $this->client = new GuzzleClient([
            'base_uri' => $this->baseUrl,
            'timeout' => $config->timeout ?? self::DEFAULT_TIMEOUT,
            'headers' => [
                'Content-Type' => 'application/json',
                ...($config->authToken ? ['Authorization' => 'Bearer ' . $config->authToken] : []),
            ],
        ]);
        
        $this->runtimeManager = new RuntimeManager($this->baseUrl);
    }

    public function getRuntime(): RuntimeManager
    {
        return $this->runtimeManager;
    }

    public function setAuthToken(string $token): void
    {
        $this->client = new GuzzleClient([
            'base_uri' => $this->baseUrl,
            'timeout' => self::DEFAULT_TIMEOUT,
            'headers' => [
                'Content-Type' => 'application/json',
                'Authorization' => 'Bearer ' . $token,
            ],
        ]);
    }

    public function getBaseUrl(): string
    {
        return $this->baseUrl;
    }

    public function healthCheck(): array
    {
        try {
            $response = $this->client->get('/hello');
            return [
                'status' => 'ok',
                'message' => (string) $response->getBody(),
            ];
        } catch (GuzzleException $e) {
            return [
                'status' => 'error',
                'message' => 'Server not responding',
            ];
        }
    }

    public function listSkills(array $options = []): SkillListResponse
    {
        $limit = $options['limit'] ?? 10;
        $page = $options['page'] ?? 0;
        $skip = $options['skip'] ?? 0;

        $params = [
            'limit' => $limit,
            'page' => $page,
        ];
        
        if ($skip > 0) {
            $params['skip'] = $skip;
        }

        $response = $this->client->get('/skills', ['query' => $params]);
        $data = json_decode((string) $response->getBody(), true);

        return SkillListResponse::fromArray($data);
    }

    public function getSkill(string $skillId): Skill
    {
        $response = $this->client->get("/skills/{$skillId}");
        $data = json_decode((string) $response->getBody(), true);

        return Skill::fromArray($data);
    }

    public function installSkill(SkillInstallOptions $options): SkillInstallResponse
    {
        $response = $this->client->post('/skills/add', [
            'json' => $options->toArray(),
        ]);
        $data = json_decode((string) $response->getBody(), true);

        return SkillInstallResponse::fromArray($data);
    }

    public function installSkillFromMultiRepo(string $source, string $skillPath, ?SkillInstallOptions $options = null): SkillInstallResponse
    {
        $options = $options ?? new SkillInstallOptions($source);
        
        $response = $this->client->post('/skills/add', [
            'json' => array_merge($options->toArray(), [
                'source' => $source,
                'skill_subpath' => $skillPath,
            ]),
        ]);
        $data = json_decode((string) $response->getBody(), true);

        return SkillInstallResponse::fromArray($data);
    }

    public function uninstallSkill(string $skillId): array
    {
        $response = $this->client->post('/skills/del', [
            'json' => ['id' => $skillId],
        ]);
        $data = json_decode((string) $response->getBody(), true);

        return $data;
    }

    public function executeSkill(string $skillId, array $params = []): SkillExecutionResult
    {
        $response = $this->client->post('/skills/execute', [
            'json' => [
                'skill_id' => $skillId,
                'params' => $params,
            ],
        ]);
        $data = json_decode((string) $response->getBody(), true);

        return SkillExecutionResult::fromArray($data);
    }

    public function executeSkillTool(string $skillId, string $toolName, array $args = []): SkillExecutionResult
    {
        $response = $this->client->post("/skills/{$skillId}/tools/{$toolName}/run", [
            'json' => ['args' => $args],
        ]);
        $data = json_decode((string) $response->getBody(), true);

        return SkillExecutionResult::fromArray($data);
    }

    public function searchSkills(string|array $options): SkillSearchResult
    {
        if (is_string($options)) {
            $searchOptions = [
                'query' => $options,
                'source' => 'all',
                'limit' => 10,
            ];
        } else {
            $searchOptions = [
                'query' => $options['query'],
                'source' => $options['source'] ?? 'all',
                'limit' => $options['limit'] ?? 10,
            ];
        }

        $response = $this->client->post('/skills/search', [
            'json' => $searchOptions,
        ]);
        $data = json_decode((string) $response->getBody(), true);

        return SkillSearchResult::fromArray($data);
    }

    public function updateSkill(string $skillId, array $updates): Skill
    {
        $response = $this->client->post('/skills/edit', [
            'json' => array_merge(['id' => $skillId], $updates),
        ]);
        $data = json_decode((string) $response->getBody(), true);

        return Skill::fromArray($data);
    }

    public function getSkillConfig(string $skillId): array
    {
        $response = $this->client->get("/skills/{$skillId}/config");
        return json_decode((string) $response->getBody(), true);
    }

    public function setSkillConfig(string $skillId, array $config): array
    {
        $response = $this->client->post("/skills/{$skillId}/config", [
            'json' => $config,
        ]);
        return json_decode((string) $response->getBody(), true);
    }

    public function listSkillTools(string $skillId): array
    {
        $response = $this->client->get("/skills/{$skillId}/tools");
        $data = json_decode((string) $response->getBody(), true);

        return array_map(fn($tool) => ToolDefinition::fromArray($tool), $data);
    }
}