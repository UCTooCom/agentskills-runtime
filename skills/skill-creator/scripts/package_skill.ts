/**
 * package_skill.ts — Creates a distributable .skill file of a skill folder.
 * 功能与 package_skill.py 完全一致
 * 使用内置 zlib 手动构建 ZIP 文件格式
 */
import * as fs from "fs";
import * as path from "path";
import * as zlib from "zlib";
import { fileURLToPath } from "url";
import { validateSkill } from "./quick_validate.ts";

const EXCLUDE_DIRS = new Set(["__pycache__", "node_modules"]);
const EXCLUDE_GLOBS = ["*.pyc"];
const EXCLUDE_FILES = new Set([".DS_Store"]);
const ROOT_EXCLUDE_DIRS = new Set(["evals"]);

function fnmatch(name: string, pattern: string): boolean {
  const regex = pattern
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\*/g, ".*")
    .replace(/\?/g, ".");
  // 大小写不敏感：对齐 Python fnmatch.fnmatch 在 Windows 上的 normcase 行为
  return new RegExp(`^${regex}$`, "i").test(name);
}

function shouldExclude(relPath: string): boolean {
  const parts = relPath.split(path.sep);
  if (parts.some(part => EXCLUDE_DIRS.has(part))) {
    return true;
  }
  if (parts.length > 1 && ROOT_EXCLUDE_DIRS.has(parts[1])) {
    return true;
  }
  const name = parts[parts.length - 1];
  if (EXCLUDE_FILES.has(name)) {
    return true;
  }
  return EXCLUDE_GLOBS.some(pat => fnmatch(name, pat));
}

// CRC-32 查找表
const crc32Table: number[] = (() => {
  const table = new Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) {
      if (c & 1) c = 0xedb88320 ^ (c >>> 1);
      else c = c >>> 1;
    }
    table[i] = c;
  }
  return table;
})();

function crc32(data: Buffer): number {
  let crc = 0xffffffff;
  for (let i = 0; i < data.length; i++) {
    crc = crc32Table[(crc ^ data[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

interface ZipEntry {
  filename: string;
  offset: number;
  crc: number;
  compressedSize: number;
  uncompressedSize: number;
  compressionMethod: number;
}

class ZipWriter {
  private chunks: Buffer[] = [];
  private entries: ZipEntry[] = [];

  addFile(filename: string, data: Buffer): void {
    const offset = this.getTotalSize();
    const crc = crc32(data);

    let compressionMethod: number;
    let fileData: Buffer;

    try {
      const compressed = zlib.deflateRawSync(data);
      if (compressed.length < data.length) {
        compressionMethod = 8;
        fileData = compressed;
      } else {
        compressionMethod = 0;
        fileData = data;
      }
    } catch {
      compressionMethod = 0;
      fileData = data;
    }

    const header = Buffer.alloc(30);
    header.writeUInt32LE(0x04034b50, 0);
    header.writeUInt16LE(20, 4);
    header.writeUInt16LE(0, 6);
    header.writeUInt16LE(compressionMethod, 8);
    header.writeUInt16LE(0, 10);
    header.writeUInt16LE(0, 12);
    header.writeUInt32LE(crc, 14);
    header.writeUInt32LE(fileData.length, 18);
    header.writeUInt32LE(data.length, 22);
    header.writeUInt16LE(filename.length, 26);
    header.writeUInt16LE(0, 28);

    const filenameBuffer = Buffer.from(filename, "utf-8");
    this.chunks.push(header, filenameBuffer, fileData);

    this.entries.push({
      filename,
      offset,
      crc,
      compressedSize: fileData.length,
      uncompressedSize: data.length,
      compressionMethod,
    });
  }

  private getTotalSize(): number {
    return this.chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  }

  toBuffer(): Buffer {
    const centralDirOffset = this.getTotalSize();
    const centralDirChunks: Buffer[] = [];

    for (const entry of this.entries) {
      const header = Buffer.alloc(46);
      header.writeUInt32LE(0x02014b50, 0);
      header.writeUInt16LE(20, 4);
      header.writeUInt16LE(20, 6);
      header.writeUInt16LE(0, 8);
      header.writeUInt16LE(entry.compressionMethod, 10);
      header.writeUInt16LE(0, 12);
      header.writeUInt16LE(0, 14);
      header.writeUInt32LE(entry.crc, 16);
      header.writeUInt32LE(entry.compressedSize, 20);
      header.writeUInt32LE(entry.uncompressedSize, 24);
      header.writeUInt16LE(entry.filename.length, 28);
      header.writeUInt16LE(0, 30);
      header.writeUInt16LE(0, 32);
      header.writeUInt16LE(0, 34);
      header.writeUInt16LE(0, 36);
      header.writeUInt32LE(0, 38);
      header.writeUInt32LE(entry.offset, 42);

      const filenameBuffer = Buffer.from(entry.filename, "utf-8");
      centralDirChunks.push(header, filenameBuffer);
    }

    const centralDirSize = centralDirChunks.reduce((sum, chunk) => sum + chunk.length, 0);

    const eocd = Buffer.alloc(22);
    eocd.writeUInt32LE(0x06054b50, 0);
    eocd.writeUInt16LE(0, 4);
    eocd.writeUInt16LE(0, 6);
    eocd.writeUInt16LE(this.entries.length, 8);
    eocd.writeUInt16LE(this.entries.length, 10);
    eocd.writeUInt32LE(centralDirSize, 12);
    eocd.writeUInt32LE(centralDirOffset, 16);
    eocd.writeUInt16LE(0, 20);

    return Buffer.concat([...this.chunks, ...centralDirChunks, eocd]);
  }
}

function walkDir(dir: string): string[] {
  const result: string[] = [];
  for (const entry of fs.readdirSync(dir)) {
    const fullPath = path.join(dir, entry);
    if (fs.statSync(fullPath).isFile()) {
      result.push(fullPath);
    } else if (fs.statSync(fullPath).isDirectory()) {
      result.push(...walkDir(fullPath));
    }
  }
  return result;
}

export function packageSkill(skillPathArg: string, outputDir: string | null = null): string | null {
  const skillPath = path.resolve(skillPathArg);

  if (!fs.existsSync(skillPath)) {
    console.log(`❌ Error: Skill folder not found: ${skillPath}`);
    return null;
  }

  if (!fs.statSync(skillPath).isDirectory()) {
    console.log(`❌ Error: Path is not a directory: ${skillPath}`);
    return null;
  }

  const skillMd = path.join(skillPath, "SKILL.md");
  if (!fs.existsSync(skillMd)) {
    console.log(`❌ Error: SKILL.md not found in ${skillPath}`);
    return null;
  }

  console.log("🔍 Validating skill...");
  const [valid, message] = validateSkill(skillPath);
  if (!valid) {
    console.log(`❌ Validation failed: ${message}`);
    console.log("   Please fix the validation errors before packaging.");
    return null;
  }
  console.log(`✅ ${message}\n`);

  const skillName = path.basename(skillPath);
  let outputPath: string;
  if (outputDir) {
    outputPath = path.resolve(outputDir);
    fs.mkdirSync(outputPath, { recursive: true });
  } else {
    outputPath = process.cwd();
  }

  const skillFilename = path.join(outputPath, `${skillName}.skill`);

  try {
    const zipWriter = new ZipWriter();
    const allFiles = walkDir(skillPath);

    for (const filePath of allFiles) {
      // ZIP 规范要求条目名用 "/" 分隔；Windows 上 path.relative 产出反斜杠，
      // 对齐 Python zipfile 自动归一化 os.sep → "/" 的行为
      const arcname = path.relative(path.dirname(skillPath), filePath).split(path.sep).join("/");
      if (shouldExclude(arcname)) {
        console.log(`  Skipped: ${arcname}`);
        continue;
      }
      const data = fs.readFileSync(filePath);
      zipWriter.addFile(arcname, data);
      console.log(`  Added: ${arcname}`);
    }

    fs.writeFileSync(skillFilename, zipWriter.toBuffer());
    console.log(`\n✅ Successfully packaged skill to: ${skillFilename}`);
    return skillFilename;
  } catch (e) {
    console.log(`❌ Error creating .skill file: ${e}`);
    return null;
  }
}

function main() {
  if (process.argv.length < 3) {
    console.log("Usage: node package_skill.ts <path/to/skill-folder> [output-directory]");
    console.log("\nExample:");
    console.log("  node package_skill.ts skills/public/my-skill");
    console.log("  node package_skill.ts skills/public/my-skill ./dist");
    process.exit(1);
  }

  const skillPath = process.argv[2];
  const outputDir = process.argv[3] ?? null;

  console.log(`📦 Packaging skill: ${skillPath}`);
  if (outputDir) {
    console.log(`   Output directory: ${outputDir}`);
  }
  console.log();

  const result = packageSkill(skillPath, outputDir);
  process.exit(result ? 0 : 1);
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  main();
}