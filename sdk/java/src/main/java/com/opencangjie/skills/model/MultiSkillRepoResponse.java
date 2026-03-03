package com.opencangjie.skills.model;

import java.util.List;

public class MultiSkillRepoResponse extends SkillInstallResponse {
    private List<AvailableSkillInfo> availableSkills;
    private Integer totalCount;
    private String sourceUrl;

    public MultiSkillRepoResponse() {
        setStatus("multi_skill_repo");
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

    public String getSourceUrl() {
        return sourceUrl;
    }

    public void setSourceUrl(String sourceUrl) {
        this.sourceUrl = sourceUrl;
    }
}
