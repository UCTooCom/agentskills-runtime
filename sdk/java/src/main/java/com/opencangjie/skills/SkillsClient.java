package com.opencangjie.skills;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.opencangjie.skills.model.*;

import okhttp3.*;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

public class SkillsClient {
    private OkHttpClient client;
    private String baseUrl;
    private RuntimeManager runtimeManager;
    private ObjectMapper objectMapper;

    private static final String DEFAULT_BASE_URL = "http://127.0.0.1:8080";
    private static final int DEFAULT_TIMEOUT = 30000;

    public SkillsClient(ClientConfig config) {
        this.baseUrl = config.getBaseUrl() != null 
                ? config.getBaseUrl() 
                : System.getenv("SKILL_RUNTIME_API_URL") != null 
                ? System.getenv("SKILL_RUNTIME_API_URL") 
                : DEFAULT_BASE_URL;

        int timeout = config.getTimeout() != null ? config.getTimeout() : DEFAULT_TIMEOUT;

        OkHttpClient.Builder builder = new OkHttpClient.Builder()
                .connectTimeout(timeout, java.util.concurrent.TimeUnit.MILLISECONDS)
                .readTimeout(timeout, java.util.concurrent.TimeUnit.MILLISECONDS)
                .writeTimeout(timeout, java.util.concurrent.TimeUnit.MILLISECONDS);

        this.client = builder.build();
        this.objectMapper = new ObjectMapper();
        this.runtimeManager = new RuntimeManager(this.baseUrl);

        if (config.getAuthToken() != null) {
            setAuthToken(config.getAuthToken());
        }
    }

    public SkillsClient() {
        this(new ClientConfig());
    }

    public RuntimeManager getRuntime() {
        return runtimeManager;
    }

    public void setAuthToken(String token) {
        // OkHttpClient doesn't support modifying headers directly
        // We'll handle this in each request
    }

    public String getBaseUrl() {
        return baseUrl;
    }

    public HealthCheckResponse healthCheck() throws IOException {
        Request request = new Request.Builder()
                .url(baseUrl + "/hello")
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (response.isSuccessful()) {
                String responseBody = response.body().string();
                HealthCheckResponse healthCheckResponse = new HealthCheckResponse();
                healthCheckResponse.setStatus("ok");
                healthCheckResponse.setMessage(responseBody);
                return healthCheckResponse;
            } else {
                HealthCheckResponse healthCheckResponse = new HealthCheckResponse();
                healthCheckResponse.setStatus("error");
                healthCheckResponse.setMessage("Server not responding");
                return healthCheckResponse;
            }
        }
    }

    public SkillListResponse listSkills(ListSkillsOptions options) throws IOException {
        int limit = options.getLimit() != null ? options.getLimit() : 10;
        int page = options.getPage() != null ? options.getPage() : 0;
        int skip = options.getSkip() != null ? options.getSkip() : 0;

        String url = baseUrl + "/skills?limit=" + limit + "&page=" + page;
        if (skip > 0) {
            url += "&skip=" + skip;
        }

        Request request = new Request.Builder()
                .url(url)
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response);
            }
            return objectMapper.readValue(response.body().string(), SkillListResponse.class);
        }
    }

    public Skill getSkill(String skillId) throws IOException {
        Request request = new Request.Builder()
                .url(baseUrl + "/skills/" + skillId)
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response);
            }
            return objectMapper.readValue(response.body().string(), Skill.class);
        }
    }

    public SkillInstallResponse installSkill(SkillInstallOptions options) throws IOException {
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("source", options.getSource());
        if (options.getValidate() != null) {
            requestBody.put("validate", options.getValidate());
        }
        if (options.getCreator() != null) {
            requestBody.put("creator", options.getCreator());
        }
        if (options.getInstallPath() != null) {
            requestBody.put("install_path", options.getInstallPath());
        }
        if (options.getBranch() != null) {
            requestBody.put("branch", options.getBranch());
        }
        if (options.getTag() != null) {
            requestBody.put("tag", options.getTag());
        }
        if (options.getCommit() != null) {
            requestBody.put("commit", options.getCommit());
        }
        if (options.getSkillSubpath() != null) {
            requestBody.put("skill_subpath", options.getSkillSubpath());
        }

        RequestBody body = RequestBody.create(
                objectMapper.writeValueAsString(requestBody),
                MediaType.parse("application/json")
        );

        Request request = new Request.Builder()
                .url(baseUrl + "/skills/add")
                .post(body)
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response);
            }
            return objectMapper.readValue(response.body().string(), SkillInstallResponse.class);
        }
    }

    public SkillInstallResponse installSkillFromMultiRepo(String source, String skillPath, SkillInstallOptions options) throws IOException {
        if (options == null) {
            options = new SkillInstallOptions();
        }
        options.setSource(source);
        options.setSkillSubpath(skillPath);
        return installSkill(options);
    }

    public boolean isMultiSkillRepoResponse(SkillInstallResponse response) {
        return "multi_skill_repo".equals(response.getStatus()) && response.getAvailableSkills() != null;
    }

    public UninstallSkillResponse uninstallSkill(String skillId) throws IOException {
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("id", skillId);

        RequestBody body = RequestBody.create(
                objectMapper.writeValueAsString(requestBody),
                MediaType.parse("application/json")
        );

        Request request = new Request.Builder()
                .url(baseUrl + "/skills/del")
                .post(body)
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response);
            }
            return objectMapper.readValue(response.body().string(), UninstallSkillResponse.class);
        }
    }

    public SkillExecutionResult executeSkill(String skillId, Map<String, Object> params) throws IOException {
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("skill_id", skillId);
        requestBody.put("params", params != null ? params : new HashMap<>());

        RequestBody body = RequestBody.create(
                objectMapper.writeValueAsString(requestBody),
                MediaType.parse("application/json")
        );

        Request request = new Request.Builder()
                .url(baseUrl + "/skills/execute")
                .post(body)
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response);
            }
            return objectMapper.readValue(response.body().string(), SkillExecutionResult.class);
        }
    }

    public SkillExecutionResult executeSkillTool(String skillId, String toolName, Map<String, Object> args) throws IOException {
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("args", args != null ? args : new HashMap<>());

        RequestBody body = RequestBody.create(
                objectMapper.writeValueAsString(requestBody),
                MediaType.parse("application/json")
        );

        Request request = new Request.Builder()
                .url(baseUrl + "/skills/" + skillId + "/tools/" + toolName + "/run")
                .post(body)
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response);
            }
            return objectMapper.readValue(response.body().string(), SkillExecutionResult.class);
        }
    }

    public SkillSearchResult searchSkills(SearchSkillsOptions options) throws IOException {
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("query", options.getQuery());
        requestBody.put("source", options.getSource() != null ? options.getSource() : "all");
        requestBody.put("limit", options.getLimit() != null ? options.getLimit() : 10);

        RequestBody body = RequestBody.create(
                objectMapper.writeValueAsString(requestBody),
                MediaType.parse("application/json")
        );

        Request request = new Request.Builder()
                .url(baseUrl + "/skills/search")
                .post(body)
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response);
            }
            return objectMapper.readValue(response.body().string(), SkillSearchResult.class);
        }
    }

    public Skill updateSkill(String skillId, Map<String, Object> updates) throws IOException {
        Map<String, Object> requestBody = new HashMap<>(updates);
        requestBody.put("id", skillId);

        RequestBody body = RequestBody.create(
                objectMapper.writeValueAsString(requestBody),
                MediaType.parse("application/json")
        );

        Request request = new Request.Builder()
                .url(baseUrl + "/skills/edit")
                .post(body)
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response);
            }
            return objectMapper.readValue(response.body().string(), Skill.class);
        }
    }

    public Map<String, Object> getSkillConfig(String skillId) throws IOException {
        Request request = new Request.Builder()
                .url(baseUrl + "/skills/" + skillId + "/config")
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response);
            }
            return objectMapper.readValue(response.body().string(), Map.class);
        }
    }

    public SetSkillConfigResponse setSkillConfig(String skillId, Map<String, Object> config) throws IOException {
        RequestBody body = RequestBody.create(
                objectMapper.writeValueAsString(config),
                MediaType.parse("application/json")
        );

        Request request = new Request.Builder()
                .url(baseUrl + "/skills/" + skillId + "/config")
                .post(body)
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response);
            }
            return objectMapper.readValue(response.body().string(), SetSkillConfigResponse.class);
        }
    }

    public java.util.List<ToolDefinition> listSkillTools(String skillId) throws IOException {
        Request request = new Request.Builder()
                .url(baseUrl + "/skills/" + skillId + "/tools")
                .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response);
            }
            return objectMapper.readValue(
                    response.body().string(),
                    objectMapper.getTypeFactory().constructCollectionType(java.util.List.class, ToolDefinition.class)
            );
        }
    }

    public static class ListSkillsOptions {
        private Integer limit;
        private Integer page;
        private Integer skip;

        public Integer getLimit() {
            return limit;
        }

        public void setLimit(Integer limit) {
            this.limit = limit;
        }

        public Integer getPage() {
            return page;
        }

        public void setPage(Integer page) {
            this.page = page;
        }

        public Integer getSkip() {
            return skip;
        }

        public void setSkip(Integer skip) {
            this.skip = skip;
        }
    }

    public static class SearchSkillsOptions {
        private String query;
        private String source;
        private Integer limit;

        public SearchSkillsOptions(String query) {
            this.query = query;
        }

        public SearchSkillsOptions() {
        }

        public String getQuery() {
            return query;
        }

        public void setQuery(String query) {
            this.query = query;
        }

        public String getSource() {
            return source;
        }

        public void setSource(String source) {
            this.source = source;
        }

        public Integer getLimit() {
            return limit;
        }

        public void setLimit(Integer limit) {
            this.limit = limit;
        }
    }

    public static class HealthCheckResponse {
        private String status;
        private String message;

        public String getStatus() {
            return status;
        }

        public void setStatus(String status) {
            this.status = status;
        }

        public String getMessage() {
            return message;
        }

        public void setMessage(String message) {
            this.message = message;
        }
    }

    public static class UninstallSkillResponse {
        private boolean success;
        private String message;

        public boolean isSuccess() {
            return success;
        }

        public void setSuccess(boolean success) {
            this.success = success;
        }

        public String getMessage() {
            return message;
        }

        public void setMessage(String message) {
            this.message = message;
        }
    }

    public static class SetSkillConfigResponse {
        private boolean success;
        private String message;

        public boolean isSuccess() {
            return success;
        }

        public void setSuccess(boolean success) {
            this.success = success;
        }

        public String getMessage() {
            return message;
        }

        public void setMessage(String message) {
            this.message = message;
        }
    }
}
