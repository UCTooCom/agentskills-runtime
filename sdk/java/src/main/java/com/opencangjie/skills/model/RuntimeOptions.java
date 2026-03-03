package com.opencangjie.skills.model;

import java.util.Map;

public class RuntimeOptions {
    private Integer port;
    private String host;
    private Boolean detached;
    private String cwd;
    private Map<String, String> env;
    private String skillInstallPath;

    public Integer getPort() {
        return port;
    }

    public void setPort(Integer port) {
        this.port = port;
    }

    public String getHost() {
        return host;
    }

    public void setHost(String host) {
        this.host = host;
    }

    public Boolean getDetached() {
        return detached;
    }

    public void setDetached(Boolean detached) {
        this.detached = detached;
    }

    public String getCwd() {
        return cwd;
    }

    public void setCwd(String cwd) {
        this.cwd = cwd;
    }

    public Map<String, String> getEnv() {
        return env;
    }

    public void setEnv(Map<String, String> env) {
        this.env = env;
    }

    public String getSkillInstallPath() {
        return skillInstallPath;
    }

    public void setSkillInstallPath(String skillInstallPath) {
        this.skillInstallPath = skillInstallPath;
    }
}
