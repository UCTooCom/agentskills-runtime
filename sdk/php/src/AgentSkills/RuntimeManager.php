<?php

namespace AgentSkills;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;
use Symfony\Component\Filesystem\Filesystem;
use Symfony\Component\Process\Process;

class RuntimeManager
{
    private const DEFAULT_BASE_URL = 'http://127.0.0.1:8080';
    private const RUNTIME_VERSION = '0.0.16';
    private const GITHUB_REPO = 'UCTooCom/agentskills-runtime';
    private const ATOMGIT_REPO = 'uctoo/agentskills-runtime';

    private ?Process $process = null;
    private string $baseUrl;
    private Filesystem $filesystem;
    private string $sdkDir;

    public function __construct(string $baseUrl = self::DEFAULT_BASE_URL, ?string $sdkDir = null)
    {
        $this->baseUrl = $baseUrl;
        $this->filesystem = new Filesystem();
        $this->sdkDir = $sdkDir ?? dirname(__DIR__, 3);
    }

    private function getPlatformInfo(): array
    {
        $os = PHP_OS_FAMILY;
        $arch = php_uname('m');

        $platformMap = [
            'Windows' => 'win',
            'Darwin' => 'darwin',
            'Linux' => 'linux',
        ];

        $archMap = [
            'x86_64' => 'x64',
            'AMD64' => 'x64',
            'aarch64' => 'arm64',
            'arm64' => 'arm64',
            'i386' => 'x86',
            'i686' => 'x86',
        ];

        return [
            'platform' => $platformMap[$os] ?? strtolower($os),
            'arch' => $archMap[$arch] ?? $arch,
            'suffix' => $os === 'Windows' ? '.exe' : '',
        ];
    }

    private function getRuntimeDir(): string
    {
        return $this->sdkDir . '/runtime';
    }

    private function getRuntimePath(): string
    {
        $info = $this->getPlatformInfo();
        return sprintf(
            '%s/%s-%s/release/bin/agentskills-runtime%s',
            $this->getRuntimeDir(),
            $info['platform'],
            $info['arch'],
            $info['suffix']
        );
    }

    private function getReleaseDir(): string
    {
        $info = $this->getPlatformInfo();
        return sprintf(
            '%s/%s-%s/release',
            $this->getRuntimeDir(),
            $info['platform'],
            $info['arch']
        );
    }

    private function getVersionFilePath(): string
    {
        $info = $this->getPlatformInfo();
        return sprintf(
            '%s/%s-%s/release/VERSION',
            $this->getRuntimeDir(),
            $info['platform'],
            $info['arch']
        );
    }

    private function getInstalledVersion(): ?string
    {
        $versionFile = $this->getVersionFilePath();
        
        if (!$this->filesystem->exists($versionFile)) {
            return null;
        }

        $content = file_get_contents($versionFile);
        $lines = explode("\n", $content);

        foreach ($lines as $line) {
            if (str_starts_with($line, 'AGENTSKILLS_RUNTIME_VERSION=')) {
                return trim(substr($line, 27));
            }
        }

        $firstLine = trim($lines[0] ?? '');
        if ($firstLine && !str_contains($firstLine, '=')) {
            return $firstLine;
        }

        return null;
    }

    public function isInstalled(): bool
    {
        return $this->filesystem->exists($this->getRuntimePath());
    }

    public function downloadRuntime(string $version = self::RUNTIME_VERSION): bool
    {
        $info = $this->getPlatformInfo();
        $runtimeDir = sprintf('%s/%s-%s', $this->getRuntimeDir(), $info['platform'], $info['arch']);
        
        $this->filesystem->mkdir($runtimeDir);
        
        $fileName = sprintf('agentskills-runtime-%s-%s.tar.gz', $info['platform'], $info['arch']);
        
        $mirrors = [
            [
                'name' => 'atomgit',
                'url' => sprintf('https://atomgit.com/%s/releases/download', self::ATOMGIT_REPO),
                'priority' => 1,
                'region' => 'china',
            ],
            [
                'name' => 'github',
                'url' => sprintf('https://github.com/%s/releases/download', self::GITHUB_REPO),
                'priority' => 2,
                'region' => 'global',
            ],
        ];

        foreach ($mirrors as $mirror) {
            $downloadUrl = sprintf('%s/v%s/%s', $mirror['url'], $version, $fileName);
            
            echo sprintf("Trying mirror: %s (%s)\n", $mirror['name'], $mirror['region']);
            echo sprintf("URL: %s\n", $downloadUrl);
            
            try {
                $archivePath = $runtimeDir . '/runtime.tar.gz';
                
                $client = new Client();
                $response = $client->get($downloadUrl, [
                    'sink' => $archivePath,
                    'timeout' => 300,
                ]);

                if ($response->getStatusCode() !== 200) {
                    throw new \Exception("Download failed with status {$response->getStatusCode()}");
                }

                $phar = new \PharData($archivePath);
                $phar->extractTo($runtimeDir);
                
                $this->filesystem->remove($archivePath);

                $runtimePath = $this->getRuntimePath();
                if ($this->filesystem->exists($runtimePath) && PHP_OS_FAMILY !== 'Windows') {
                    chmod($runtimePath, 0755);
                }

                $releaseDir = $this->getReleaseDir();
                $envFile = $releaseDir . '/.env';
                $envExampleFile = $releaseDir . '/.env.example';

                if (!$this->filesystem->exists($envFile) && $this->filesystem->exists($envExampleFile)) {
                    $this->filesystem->copy($envExampleFile, $envFile);
                    echo "Created .env file from .env.example\n";
                } elseif (!$this->filesystem->exists($envFile)) {
                    $defaultEnvContent = "# AgentSkills Runtime Configuration\n# This file was auto-generated. Edit as needed.\n\n# Skill Installation Path\nSKILL_INSTALL_PATH=./skills\n";
                    file_put_contents($envFile, $defaultEnvContent);
                    echo "Created default .env file\n";
                }

                echo sprintf("AgentSkills Runtime v%s downloaded successfully from %s!\n", $version, $mirror['name']);
                return true;
            } catch (\Exception $e) {
                echo sprintf("Mirror %s failed, trying next...\n", $mirror['name']);
                echo "Error: " . $e->getMessage() . "\n";
                continue;
            }
        }

        echo "All mirrors failed to download runtime.\n";
        echo "\nPlease download manually from one of these mirrors:\n";
        foreach ($mirrors as $mirror) {
            echo sprintf("  - %s/v%s/%s\n", $mirror['url'], $version, $fileName);
        }
        
        return false;
    }

    public function start(?RuntimeOptions $options = null): ?Process
    {
        $runtimePath = $this->getRuntimePath();
        
        if (!$this->filesystem->exists($runtimePath)) {
            echo "Runtime not found. Run \"skills install-runtime\" first.\n";
            return null;
        }

        $options = $options ?? new RuntimeOptions();
        $port = $options->port ?? 8080;
        $host = $options->host ?? '127.0.0.1';
        $cwd = $options->cwd ?? $this->getReleaseDir();
        
        $skillInstallPath = $options->skillInstallPath 
            ?? getenv('SKILL_INSTALL_PATH') 
            ?: getcwd() . '/skills';

        $env = array_merge(getenv(), [
            'SKILL_INSTALL_PATH' => $skillInstallPath,
            ...($options->env ?? []),
        ]);

        echo sprintf("[SDK DEBUG] cwd: %s\n", $cwd);
        echo sprintf("[SDK DEBUG] SKILL_INSTALL_PATH in env: %s\n", $env['SKILL_INSTALL_PATH']);
        echo sprintf("[SDK DEBUG] runtimePath: %s\n", $runtimePath);

        if (PHP_OS_FAMILY === 'Windows') {
            $escapedPath = str_replace('"', '""', $skillInstallPath);
            $command = sprintf('"%s" %d --skill-path "%s"', $runtimePath, $port, $escapedPath);
            echo sprintf("[SDK DEBUG] command: %s\n", $command);
            
            $this->process = new Process(['cmd', '/c', $command], $cwd, $env);
        } else {
            $args = [(string) $port, '--skill-path', $skillInstallPath];
            echo sprintf("[SDK DEBUG] args: %s\n", implode(' ', $args));
            
            $this->process = new Process([$runtimePath, ...$args], $cwd, $env);
        }

        $detached = $options->detached ?? false;
        if ($detached) {
            $this->process->disableOutput();
        }

        $this->process->start();

        if ($detached && $this->process->getPid()) {
            $pidFile = $this->getRuntimeDir() . '/runtime.pid';
            file_put_contents($pidFile, $this->process->getPid());
        }

        return $this->process;
    }

    public function stop(): bool
    {
        $pidFile = $this->getRuntimeDir() . '/runtime.pid';
        
        if ($this->filesystem->exists($pidFile)) {
            $pid = (int) file_get_contents($pidFile);
            try {
                if (PHP_OS_FAMILY === 'Windows') {
                    exec("taskkill /F /PID {$pid} 2>&1", $output, $returnCode);
                } else {
                    posix_kill($pid, SIGTERM);
                }
                $this->filesystem->remove($pidFile);
                return true;
            } catch (\Exception $e) {
                try {
                    $this->filesystem->remove($pidFile);
                } catch (\Exception $e) {}
                return false;
            }
        }

        if ($this->process && $this->process->isRunning()) {
            try {
                $this->process->stop();
            } catch (\Exception $e) {}
            $this->process = null;
            return true;
        }

        return false;
    }

    public function status(): RuntimeStatus
    {
        try {
            $client = new Client([
                'base_uri' => $this->baseUrl,
                'timeout' => 2,
            ]);
            
            $response = $client->get('/hello');
            $headerVersion = $response->getHeader('x-runtime-version')[0] ?? null;
            $installedVersion = $this->getInstalledVersion();
            
            return new RuntimeStatus(
                running: true,
                version: $headerVersion ?? $installedVersion ?? 'unknown',
                sdkVersion: $this->getSdkVersion(),
            );
        } catch (GuzzleException $e) {
            return new RuntimeStatus(
                running: false,
                sdkVersion: $this->getSdkVersion(),
            );
        }
    }

    private function getSdkVersion(): string
    {
        $composerJson = $this->sdkDir . '/composer.json';
        if ($this->filesystem->exists($composerJson)) {
            $content = json_decode(file_get_contents($composerJson), true);
            return $content['version'] ?? '0.0.1';
        }
        return '0.0.1';
    }
}