<?php

namespace AgentSkills;

function defineSkill(array $config): array
{
    return [
        'metadata' => $config['metadata'],
        'tools' => $config['tools'] ?? [],
        'validateConfig' => $config['validateConfig'] ?? null,
    ];
}

function getConfig(): array
{
    $config = [];
    
    foreach ($_ENV as $key => $value) {
        if (str_starts_with($key, 'SKILL_') && $value !== null) {
            $configKey = substr($key, 6);
            $config[$configKey] = $value;
        }
    }
    
    return $config;
}

function getSdkVersion(): string
{
    $composerJson = dirname(__DIR__) . '/composer.json';
    if (file_exists($composerJson)) {
        $content = json_decode(file_get_contents($composerJson), true);
        return $content['version'] ?? '0.0.1';
    }
    return '0.0.1';
}

function getRuntimeVersion(): string
{
    $composerJson = dirname(__DIR__) . '/composer.json';
    if (file_exists($composerJson)) {
        $content = json_decode(file_get_contents($composerJson), true);
        return $content['extra']['runtime']['version'] ?? '0.0.1';
    }
    return '0.0.1';
}

function createClient(?ClientConfig $config = null): SkillsClient
{
    return new SkillsClient($config);
}

function handleApiError(\Exception $error): ApiError
{
    if ($error instanceof \GuzzleHttp\Exception\RequestException) {
        $response = $error->getResponse();
        
        if ($response !== null) {
            $statusCode = $response->getStatusCode();
            $data = json_decode((string) $response->getBody(), true);
            
            if (isset($data['errno']) && isset($data['errmsg'])) {
                return new ApiError(
                    errno: $data['errno'],
                    errmsg: $data['errmsg'],
                    details: $data['details'] ?? null,
                );
            }
            
            return new ApiError(
                errno: $statusCode,
                errmsg: $response->getReasonPhrase() ?? 'Request failed',
            );
        }
        
        return new ApiError(
            errno: 503,
            errmsg: 'Runtime server is not responding. Make sure runtime is running.',
        );
    }
    
    if ($error instanceof \GuzzleHttp\Exception\GuzzleException) {
        return new ApiError(
            errno: 500,
            errmsg: $error->getMessage() ?? 'Unknown error',
        );
    }
    
    return new ApiError(
        errno: 500,
        errmsg: $error->getMessage() ?? 'Unknown error',
    );
}