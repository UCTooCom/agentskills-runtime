/**
 * quick_validate.ts — Quick validation script for skills.
 * 功能与 quick_validate.py 完全一致
 */
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

function parseScalar(value: string): unknown {
  if (value === "true") return true;
  if (value === "false") return false;
  if (value === "null" || value === "~") return null;
  if (/^-?\d+$/.test(value)) return parseInt(value, 10);
  if (/^-?\d+\.\d+$/.test(value)) return parseFloat(value);
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
    return value.slice(1, -1);
  }
  return value;
}

function parseYaml(text: string): Record<string, unknown> {
  const lines = text.split("\n");
  const result: Record<string, unknown> = {};
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];
    if (line.trim() === "" || line.trim().startsWith("#")) {
      i++;
      continue;
    }

    const match = line.match(/^(\S+):\s*(.*)$/);
    if (!match) {
      i++;
      continue;
    }

    const key = match[1];
    const value = match[2].trim();

    if (value === "") {
      const nestedLines: string[] = [];
      let j = i + 1;
      while (j < lines.length && (lines[j].startsWith("  ") || lines[j].startsWith("\t"))) {
        nestedLines.push(lines[j]);
        j++;
      }
      if (nestedLines.length > 0) {
        if (nestedLines[0].trim().startsWith("-")) {
          result[key] = nestedLines.map(l => parseScalar(l.trim().replace(/^-\s*/, "")));
        } else {
          const nested: Record<string, unknown> = {};
          for (const nl of nestedLines) {
            const nmatch = nl.trim().match(/^(\S+):\s*(.*)$/);
            if (nmatch) {
              nested[nmatch[1]] = parseScalar(nmatch[2].trim());
            }
          }
          result[key] = nested;
        }
        i = j;
        continue;
      } else {
        result[key] = null;
      }
    } else if (value === "|" || value === ">" || value === "|-" || value === ">-" || value === "|+" || value === ">+") {
      const multiline: string[] = [];
      let j = i + 1;
      while (j < lines.length && (lines[j].startsWith("  ") || lines[j].startsWith("\t"))) {
        multiline.push(lines[j].replace(/^  |^\t/, ""));
        j++;
      }
      if (value.startsWith(">")) {
        result[key] = multiline.join(" ").trim();
      } else {
        result[key] = multiline.join("\n").trim();
      }
      i = j;
      continue;
    } else {
      result[key] = parseScalar(value);
    }
    i++;
  }

  return result;
}

export function validateSkill(skillPath: string): [boolean, string] {
  const skillMd = path.join(skillPath, "SKILL.md");
  if (!fs.existsSync(skillMd)) {
    return [false, "SKILL.md not found"];
  }

  const content = fs.readFileSync(skillMd, "utf-8").replace(/\r\n/g, "\n");
  if (!content.startsWith("---")) {
    return [false, "No YAML frontmatter found"];
  }

  const match = content.match(/^---\n(.*?)\n---/s);
  if (!match) {
    return [false, "Invalid frontmatter format"];
  }

  const frontmatterText = match[1];

  let frontmatter: Record<string, unknown>;
  try {
    frontmatter = parseYaml(frontmatterText);
    if (typeof frontmatter !== "object" || frontmatter === null || Array.isArray(frontmatter)) {
      return [false, "Frontmatter must be a YAML dictionary"];
    }
  } catch (e) {
    return [false, `Invalid YAML in frontmatter: ${e}`];
  }

  const allowedProperties = new Set(["name", "description", "license", "allowed-tools", "metadata", "compatibility"]);

  const unexpectedKeys = Object.keys(frontmatter).filter(k => !allowedProperties.has(k));
  if (unexpectedKeys.length > 0) {
    return [false, `Unexpected key(s) in SKILL.md frontmatter: ${unexpectedKeys.sort().join(", ")}. Allowed properties are: ${Array.from(allowedProperties).sort().join(", ")}`];
  }

  if (!("name" in frontmatter)) {
    return [false, "Missing 'name' in frontmatter"];
  }
  if (!("description" in frontmatter)) {
    return [false, "Missing 'description' in frontmatter"];
  }

  let name = frontmatter["name"] as unknown;
  if (typeof name !== "string") {
    return [false, `Name must be a string, got ${name === null ? "null" : typeof name}`];
  }
  name = (name as string).trim();
  if (name) {
    if (!/^[a-z0-9-]+$/.test(name as string)) {
      return [false, `Name '${name}' should be kebab-case (lowercase letters, digits, and hyphens only)`];
    }
    if ((name as string).startsWith("-") || (name as string).endsWith("-") || (name as string).includes("--")) {
      return [false, `Name '${name}' cannot start/end with hyphen or contain consecutive hyphens`];
    }
    if ((name as string).length > 64) {
      return [false, `Name is too long (${(name as string).length} characters). Maximum is 64 characters.`];
    }
  }

  let description = frontmatter["description"] as unknown;
  if (typeof description !== "string") {
    return [false, `Description must be a string, got ${description === null ? "null" : typeof description}`];
  }
  description = (description as string).trim();
  if (description) {
    if ((description as string).includes("<") || (description as string).includes(">")) {
      return [false, "Description cannot contain angle brackets (< or >)"];
    }
    if ((description as string).length > 1024) {
      return [false, `Description is too long (${(description as string).length} characters). Maximum is 1024 characters.`];
    }
  }

  const compatibility = frontmatter["compatibility"] as unknown;
  if (compatibility !== undefined && compatibility !== null) {
    if (typeof compatibility !== "string") {
      return [false, `Compatibility must be a string, got ${compatibility === null ? "null" : typeof compatibility}`];
    }
    if ((compatibility as string).length > 500) {
      return [false, `Compatibility is too long (${(compatibility as string).length} characters). Maximum is 500 characters.`];
    }
  }

  return [true, "Skill is valid!"];
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  if (process.argv.length !== 3) {
    console.log("Usage: node quick_validate.ts <skill_directory>");
    process.exit(1);
  }

  const [valid, message] = validateSkill(process.argv[2]);
  console.log(message);
  process.exit(valid ? 0 : 1);
}