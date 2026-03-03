package com.opencangjie.skills;

import com.opencangjie.skills.model.*;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        try {
            // Create client
            SkillsClient client = new SkillsClient();
            
            // Health check
            SkillsClient.HealthCheckResponse healthCheck = client.healthCheck();
            System.out.println("Health check: " + healthCheck.getStatus() + " - " + healthCheck.getMessage());
            
            // List skills
            SkillsClient.ListSkillsOptions listOptions = new SkillsClient.ListSkillsOptions();
            listOptions.setLimit(10);
            listOptions.setPage(0);
            SkillListResponse skills = client.listSkills(listOptions);
            System.out.println("Total skills: " + skills.getTotalCount());
            for (Skill skill : skills.getSkills()) {
                System.out.println("Skill: " + skill.getName() + " (" + skill.getId() + ")");
            }
            
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
