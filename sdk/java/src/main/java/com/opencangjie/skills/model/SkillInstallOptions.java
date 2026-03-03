package com.opencangjie.skills.model;

public class SkillInstallOptions {
    private String source;
    private Boolean validate;
    private String creator;
    private String installPath;
    private String branch;
    private String tag;
    private String commit;
    private String skillSubpath;

    public String getSource() {
        return source;
    }

    public void setSource(String source) {
        this.source = source;
    }

    public Boolean getValidate() {
        return validate;
    }

    public void setValidate(Boolean validate) {
        this.validate = validate;
    }

    public String getCreator() {
        return creator;
    }

    public void setCreator(String creator) {
        this.creator = creator;
    }

    public String getInstallPath() {
        return installPath;
    }

    public void setInstallPath(String installPath) {
        this.installPath = installPath;
    }

    public String getBranch() {
        return branch;
    }

    public void setBranch(String branch) {
        this.branch = branch;
    }

    public String getTag() {
        return tag;
    }

    public void setTag(String tag) {
        this.tag = tag;
    }

    public String getCommit() {
        return commit;
    }

    public void setCommit(String commit) {
        this.commit = commit;
    }

    public String getSkillSubpath() {
        return skillSubpath;
    }

    public void setSkillSubpath(String skillSubpath) {
        this.skillSubpath = skillSubpath;
    }
}
