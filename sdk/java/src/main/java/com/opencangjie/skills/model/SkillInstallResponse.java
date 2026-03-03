package com.opencangjie.skills.model;

import java.util.List;

public class SkillInstallResponse {
    private String id;
    private String name;
    private String status;
    private String message;
    private String createdAt;
    private String sourceType;
    private String sourceUrl;
    private List<AvailableSkillInfo> availableSkills;
    private Integer totalCount;

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

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

    public String getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(String createdAt) {
        this.createdAt = createdAt;
    }

    public String getSourceType() {
        return sourceType;
    }

    public void setSourceType(String sourceType) {
        this.sourceType = sourceType;
    }

    public String getSourceUrl() {
        return sourceUrl;
    }

    public void setSourceUrl(String sourceUrl) {
        this.sourceUrl = sourceUrl;
    }

    public List<AvailableSkillInfo> getAvailableSkills() {
        return availableSkills;
    }

    public void setAvailableSkills(List<AvailableSkillInfo> availableSkills) {
        this.availableSkills = availableSkills;
    }

    public Integer getTotalCount() {
        return totalCount;
    }

    public void setTotalCount(Integer totalCount) {
        this.totalCount = totalCount;
    }
}
