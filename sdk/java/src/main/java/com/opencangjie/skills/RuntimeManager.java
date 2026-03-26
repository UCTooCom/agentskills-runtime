package com.opencangjie.skills;

import com.opencangjie.skills.model.RuntimeOptions;
import com.opencangjie.skills.model.RuntimeStatus;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.zip.GZIPInputStream;

public class RuntimeManager {
    private Process process = null;
    private String baseUrl;
    private static final String DEFAULT_BASE_URL = "http://127.0.0.1:8080/api/v1/uctoo";
    private static final String SDK_VERSION = "0.0.1";
    private static final String RUNTIME_VERSION = "0.0.16";
    private static final String GITHUB_REPO = "UCTooCom/agentskills-runtime";
    private static final String ATOMGIT_REPO = "uctoo/agentskills-runtime";

    private static class DownloadMirror {
        String name;
        String url;
        int priority;
        String region;

        DownloadMirror(String name, String url, int priority, String region) {
            this.name = name;
            this.url = url;
            this.priority = priority;
            this.region = region;
        }
    }

    private static final List<DownloadMirror> DOWNLOAD_MIRRORS = Arrays.asList(
        new DownloadMirror("atomgit", "https://atomgit.com/" + ATOMGIT_REPO + "/releases/download", 1, "china"),
        new DownloadMirror("github", "https://github.com/" + GITHUB_REPO + "/releases/download", 2, "global")
    );

    public RuntimeManager(String baseUrl) {
        this.baseUrl = baseUrl != null ? baseUrl : DEFAULT_BASE_URL;
    }

    public RuntimeManager() {
        this(DEFAULT_BASE_URL);
    }

    public boolean isInstalled() {
        return Files.exists(getRuntimePath());
    }

    public Path getRuntimePath() {
        PlatformInfo info = getPlatformInfo();
        return getRuntimeDir().resolve(info.platform + "-" + info.arch)
                .resolve("release").resolve("bin")
                .resolve("agentskills-runtime" + info.suffix);
    }

    public Path getRuntimeDir() {
        String userHome = System.getProperty("user.home");
        return Paths.get(userHome, ".agentskills-runtime");
    }

    public Path getReleaseDir() {
        PlatformInfo info = getPlatformInfo();
        return getRuntimeDir().resolve(info.platform + "-" + info.arch).resolve("release");
    }

    public Path getVersionFilePath() {
        PlatformInfo info = getPlatformInfo();
        return getRuntimeDir().resolve(info.platform + "-" + info.arch)
                .resolve("release").resolve("VERSION");
    }

    public String getInstalledVersion() {
        try {
            Path versionFile = getVersionFilePath();
            if (Files.exists(versionFile)) {
                List<String> lines = Files.readAllLines(versionFile);
                for (String line : lines) {
                    if (line.startsWith("AGENTSKILLS_RUNTIME_VERSION=")) {
                        return line.split("=")[1].trim();
                    }
                }
                if (!lines.isEmpty()) {
                    String firstLine = lines.get(0).trim();
                    if (!firstLine.contains("=")) {
                        return firstLine;
                    }
                }
            }
        } catch (Exception e) {
            // Ignore errors
        }
        return null;
    }

    public boolean downloadRuntime(String version) throws Exception {
        if (version == null) {
            version = RUNTIME_VERSION;
        }

        PlatformInfo info = getPlatformInfo();
        Path runtimeDir = getRuntimeDir().resolve(info.platform + "-" + info.arch);

        if (!Files.exists(runtimeDir)) {
            Files.createDirectories(runtimeDir);
        }

        String fileName = "agentskills-runtime-" + info.platform + "-" + info.arch + ".tar.gz";

        for (DownloadMirror mirror : DOWNLOAD_MIRRORS) {
            String downloadUrl = mirror.url + "/v" + version + "/" + fileName;
            System.out.println("Trying mirror: " + mirror.name + " (" + mirror.region + ")");
            System.out.println("URL: " + downloadUrl);

            try {
                Path archivePath = runtimeDir.resolve("runtime.tar.gz");
                downloadFile(downloadUrl, archivePath);
                extractTarGz(archivePath, runtimeDir);
                Files.delete(archivePath);

                Path runtimePath = getRuntimePath();
                if (Files.exists(runtimePath) && !System.getProperty("os.name").toLowerCase().contains("win")) {
                    runtimePath.toFile().setExecutable(true);
                }

                createEnvFile();
                System.out.println("AgentSkills Runtime v" + version + " downloaded successfully from " + mirror.name + "!");
                return true;
            } catch (Exception e) {
                System.out.println("Mirror " + mirror.name + " failed, trying next...");
                e.printStackTrace();
                continue;
            }
        }

        System.err.println("All mirrors failed to download runtime.");
        System.out.println("\nPlease download manually from one of these mirrors:");
        for (DownloadMirror mirror : DOWNLOAD_MIRRORS) {
            System.out.println("  - " + mirror.url + "/v" + version + "/" + fileName);
        }
        return false;
    }

    public Process start(RuntimeOptions options) {
        Path runtimePath = getRuntimePath();

        if (!Files.exists(runtimePath)) {
            System.err.println("Runtime not found. Run \"skills install-runtime\" first.");
            return null;
        }

        int port = options.getPort() != null ? options.getPort() : 8080;
        String host = options.getHost() != null ? options.getHost() : "127.0.0.1";
        String cwd = options.getCwd() != null ? options.getCwd() : getReleaseDir().toString();

        String skillInstallPath = options.getSkillInstallPath() != null 
                ? options.getSkillInstallPath() 
                : System.getenv("SKILL_INSTALL_PATH") != null 
                ? System.getenv("SKILL_INSTALL_PATH") 
                : Paths.get(System.getProperty("user.dir"), "skills").toString();

        Map<String, String> env = new HashMap<>(System.getenv());
        env.put("SKILL_INSTALL_PATH", skillInstallPath);
        if (options.getEnv() != null) {
            env.putAll(options.getEnv());
        }

        System.out.println("[SDK DEBUG] cwd: " + cwd);
        System.out.println("[SDK DEBUG] SKILL_INSTALL_PATH in env: " + env.get("SKILL_INSTALL_PATH"));
        System.out.println("[SDK DEBUG] runtimePath: " + runtimePath);

        try {
            List<String> args = new ArrayList<>();
            args.add(runtimePath.toString());
            args.add(String.valueOf(port));
            args.add("--skill-path");
            args.add(skillInstallPath);

            ProcessBuilder processBuilder = new ProcessBuilder(args);
            processBuilder.directory(new File(cwd));
            processBuilder.environment().putAll(env);
            processBuilder.inheritIO();

            if (options.getDetached() != null && options.getDetached()) {
                processBuilder.redirectOutput(ProcessBuilder.Redirect.INHERIT);
                processBuilder.redirectError(ProcessBuilder.Redirect.INHERIT);
                processBuilder.redirectInput(ProcessBuilder.Redirect.INHERIT);
            }

            process = processBuilder.start();

            if (options.getDetached() != null && options.getDetached() && process != null) {
                Path pidFile = getRuntimeDir().resolve("runtime.pid");
                Files.write(pidFile, String.valueOf(process.pid()).getBytes());
            }

            return process;
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    public boolean stop() {
        Path pidFile = getRuntimeDir().resolve("runtime.pid");

        if (Files.exists(pidFile)) {
            try {
                String pidStr = new String(Files.readAllBytes(pidFile));
                int pid = Integer.parseInt(pidStr.trim());

                if (System.getProperty("os.name").toLowerCase().contains("win")) {
                    Runtime.getRuntime().exec("taskkill /F /PID " + pid);
                } else {
                    Runtime.getRuntime().exec("kill " + pid);
                }

                Files.delete(pidFile);
                return true;
            } catch (Exception e) {
                try {
                    Files.deleteIfExists(pidFile);
                } catch (Exception ex) {
                    // Ignore
                }
                return false;
            }
        }

        if (process != null) {
            try {
                process.destroy();
                process.waitFor(5, TimeUnit.SECONDS);
                if (process.isAlive()) {
                    process.destroyForcibly();
                }
            } catch (Exception e) {
                // Ignore
            }
            process = null;
            return true;
        }

        return false;
    }

    public RuntimeStatus status() {
        RuntimeStatus status = new RuntimeStatus();
        status.setRunning(false);
        status.setSdkVersion(SDK_VERSION);

        try {
            URL url = new URL(baseUrl + "/hello");
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setConnectTimeout(2000);
            connection.setReadTimeout(2000);
            connection.setRequestMethod("GET");

            int responseCode = connection.getResponseCode();
            if (responseCode == 200) {
                String headerVersion = connection.getHeaderField("X-Runtime-Version");
                String installedVersion = getInstalledVersion();
                
                status.setRunning(true);
                status.setVersion(headerVersion != null ? headerVersion : (installedVersion != null ? installedVersion : "unknown"));
            }

            connection.disconnect();
        } catch (Exception e) {
            // Ignore
        }

        return status;
    }

    private PlatformInfo getPlatformInfo() {
        String osName = System.getProperty("os.name").toLowerCase();
        String osArch = System.getProperty("os.arch").toLowerCase();

        String platform;
        if (osName.contains("win")) {
            platform = "win";
        } else if (osName.contains("mac")) {
            platform = "darwin";
        } else if (osName.contains("linux")) {
            platform = "linux";
        } else {
            platform = osName;
        }

        String arch;
        if (osArch.contains("amd64") || osArch.contains("x86_64")) {
            arch = "x64";
        } else if (osArch.contains("arm64") || osArch.contains("aarch64")) {
            arch = "arm64";
        } else if (osArch.contains("x86")) {
            arch = "x86";
        } else {
            arch = osArch;
        }

        String suffix = osName.contains("win") ? ".exe" : "";

        return new PlatformInfo(platform, arch, suffix);
    }

    private void downloadFile(String urlStr, Path destination) throws Exception {
        URL url = new URL(urlStr);
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setConnectTimeout(30000);
        connection.setReadTimeout(60000);

        try (InputStream in = connection.getInputStream();
             OutputStream out = Files.newOutputStream(destination)) {
            byte[] buffer = new byte[4096];
            int bytesRead;
            while ((bytesRead = in.read(buffer)) != -1) {
                out.write(buffer, 0, bytesRead);
            }
        } finally {
            connection.disconnect();
        }
    }

    private void extractTarGz(Path archivePath, Path destination) throws Exception {
        try (GZIPInputStream gis = new GZIPInputStream(new FileInputStream(archivePath.toFile()));
             TarInputStream tis = new TarInputStream(gis)) {
            TarEntry entry;
            while ((entry = tis.getNextEntry()) != null) {
                Path entryPath = destination.resolve(entry.getName());
                if (entry.isDirectory()) {
                    Files.createDirectories(entryPath);
                } else {
                    Files.createDirectories(entryPath.getParent());
                    try (OutputStream os = Files.newOutputStream(entryPath)) {
                        byte[] buffer = new byte[4096];
                        int bytesRead;
                        while ((bytesRead = tis.read(buffer)) != -1) {
                            os.write(buffer, 0, bytesRead);
                        }
                    }
                }
                tis.closeEntry();
            }
        }
    }

    private void createEnvFile() throws Exception {
        Path releaseDir = getReleaseDir();
        Path envFile = releaseDir.resolve(".env");
        Path envExampleFile = releaseDir.resolve(".env.example");

        if (!Files.exists(envFile)) {
            if (Files.exists(envExampleFile)) {
                Files.copy(envExampleFile, envFile);
                System.out.println("Created .env file from .env.example");
            } else {
                String defaultEnvContent = "# AgentSkills Runtime Configuration\n" +
                        "# This file was auto-generated. Edit as needed.\n\n" +
                        "# Skill Installation Path\n" +
                        "SKILL_INSTALL_PATH=./skills\n";
                Files.write(envFile, defaultEnvContent.getBytes());
                System.out.println("Created default .env file");
            }
        }
    }

    private static class PlatformInfo {
        String platform;
        String arch;
        String suffix;

        PlatformInfo(String platform, String arch, String suffix) {
            this.platform = platform;
            this.arch = arch;
            this.suffix = suffix;
        }
    }

    private static class TarInputStream extends FilterInputStream {
        public TarInputStream(InputStream in) {
            super(in);
        }

        public TarEntry getNextEntry() throws IOException {
            // Simple tar entry parsing
            byte[] header = new byte[512];
            int read = read(header);
            if (read < 512) {
                return null;
            }

            String name = new String(header, 0, 100).trim();
            if (name.isEmpty()) {
                return null;
            }

            return new TarEntry(name);
        }

        public void closeEntry() throws IOException {
            // Skip to the next block
            long pos = in.skip(512 - (in.available() % 512));
            if (pos < 0) {
                throw new IOException("Failed to skip to next block");
            }
        }
    }

    private static class TarEntry {
        private String name;

        public TarEntry(String name) {
            this.name = name;
        }

        public String getName() {
            return name;
        }

        public boolean isDirectory() {
            return name.endsWith("/");
        }
    }
}
