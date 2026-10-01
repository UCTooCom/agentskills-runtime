/**
 * utils.ts — Shared utilities for skill-creator scripts.
 * 功能与 utils.py 完全一致
 */
import * as path from "path";
import * as fs from "fs";

export interface ParsedSkill {
  name: string;
  description: string;
  content: string;
}

/**
 * Parse a SKILL.md file, returning {name, description, content}.
 */
export function parseSkillMd(skillPath: string): ParsedSkill {
  const fullPath = path.join(skillPath, "SKILL.md");
  const content = fs.readFileSync(fullPath, "utf-8");
  const lines = content.split("\n");

  if (lines[0].trim() !== "---") {
    throw new Error("SKILL.md missing frontmatter (no opening ---)");
  }

  let endIdx: number | null = null;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === "---") {
      endIdx = i;
      break;
    }
  }

  if (endIdx === null) {
    throw new Error("SKILL.md missing frontmatter (no closing ---)");
  }

  let name = "";
  let description = "";
  const frontmatterLines = lines.slice(1, endIdx);
  let i = 0;
  while (i < frontmatterLines.length) {
    const line = frontmatterLines[i];
    if (line.startsWith("name:")) {
      name = line.slice("name:".length).trim().replace(/^["']|["']$/g, "").trim();
    } else if (line.startsWith("description:")) {
      const value = line.slice("description:".length).trim();
      // Handle YAML multiline indicators (>, |, >-, |-)
      if ([">", "|", ">-", "|-"].includes(value)) {
        const continuationLines: string[] = [];
        i++;
        while (
          i < frontmatterLines.length &&
          (frontmatterLines[i].startsWith("  ") || frontmatterLines[i].startsWith("\t"))
        ) {
          continuationLines.push(frontmatterLines[i].trim());
          i++;
        }
        description = continuationLines.join(" ");
        continue;
      } else {
        description = value.replace(/^["']|["']$/g, "").trim();
      }
    }
    i++;
  }

  return { name, description, content };
}