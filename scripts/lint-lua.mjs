import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import luaparse from "luaparse";

const root = path.resolve(import.meta.dirname, "..");
const toc = fs.readFileSync(path.join(root, "STEP.toc"), "utf8");
const packageMetadata = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
const tocVersion = toc.match(/^## Version:\s*(.+?)\s*$/m)?.[1];
if (!tocVersion || tocVersion !== packageMetadata.version) {
  console.error(`Version mismatch: STEP.toc=${tocVersion || "missing"}, package.json=${packageMetadata.version}`);
  process.exitCode = 1;
}

const files = toc
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line && !line.startsWith("#") && line.endsWith(".lua"));

for (const relative of files) {
  const filename = path.join(root, relative.replaceAll("\\", path.sep));
  const source = fs.readFileSync(filename, "utf8");
  try {
    luaparse.parse(source, { luaVersion: "5.1" });
  } catch (error) {
    console.error(`${relative}: ${error.message}`);
    process.exitCode = 1;
  }
}

if (!process.exitCode) {
  console.log(`Lua 5.1 syntax validated for ${files.length} runtime files.`);
}
