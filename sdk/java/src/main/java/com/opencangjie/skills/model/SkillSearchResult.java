package com.opencangjie.skills.model;

import java.util.List;

public class SkillSearchResult {
    private int totalCount;
    private List<SkillSearchResultItem> results;

    public int getTotalCount() {
        return totalCount;
    }

    public void setTotalCount(int totalCount) {
        this.totalCount = totalCount;
    }

    public List<SkillSearchResultItem> getResults() {
        return results;
    }

    public void setResults(List<SkillSearchResultItem> results) {
        this.results = results;
    }
}
