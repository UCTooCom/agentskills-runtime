package com.opencangjie.skills.model;

import java.util.Map;

public class EnvironmentConfig {
    private Map<String, String> config;

    public EnvironmentConfig(Map<String, String> config) {
        this.config = config;
    }

    public Map<String, String> getConfig() {
        return config;
    }

    public void setConfig(Map<String, String> config) {
        this.config = config;
    }

    public String get(String key) {
        return config != null ? config.get(key) : null;
    }

    public void put(String key, String value) {
        if (config != null) {
            config.put(key, value);
        }
    }
}
