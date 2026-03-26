package com.opencangjie.skills;

import com.opencangjie.skills.model.*;
import org.junit.Before;
import org.junit.Test;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import static org.junit.Assert.*;

public class SkillsClientTest {
    private SkillsClient client;

    @Before
    public void setUp() {
        ClientConfig config = new ClientConfig();
        config.setBaseUrl("http://127.0.0.1:8080/api/v1/uctoo");
        client = new SkillsClient(config);
    }

    @Test
    public void testHealthCheck() throws IOException {
        SkillsClient.HealthCheckResponse response = client.healthCheck();
        assertNotNull(response);
        System.out.println("Health check status: " + response.getStatus());
        System.out.println("Health check message: " + response.getMessage());
    }

    @Test
    public void testListSkills() throws IOException {
        SkillsClient.ListSkillsOptions options = new SkillsClient.ListSkillsOptions();
        options.setLimit(10);
        options.setPage(0);
        SkillListResponse response = client.listSkills(options);
        assertNotNull(response);
        System.out.println("Total skills: " + response.getTotalCount());
        System.out.println("Current page: " + response.getCurrentPage());
        System.out.println("Total pages: " + response.getTotalPage());
    }

    @Test
    public void testSearchSkills() throws IOException {
        SkillsClient.SearchSkillsOptions options = new SkillsClient.SearchSkillsOptions();
        options.setQuery("test");
        options.setLimit(5);
        SkillSearchResult result = client.searchSkills(options);
        assertNotNull(result);
        System.out.println("Search total count: " + result.getTotalCount());
    }

    @Test
    public void testRuntimeStatus() {
        RuntimeStatus status = client.getRuntime().status();
        assertNotNull(status);
        System.out.println("Runtime running: " + status.isRunning());
        System.out.println("Runtime version: " + status.getVersion());
        System.out.println("SDK version: " + status.getSdkVersion());
    }

    @Test
    public void testIsRuntimeInstalled() {
        boolean installed = client.getRuntime().isInstalled();
        System.out.println("Runtime installed: " + installed);
    }
}
