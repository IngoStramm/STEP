import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";

const root = path.resolve(import.meta.dirname, "..");
const toc = fs.readFileSync(path.join(root, "STEP.toc"), "utf8");
const runtimeFiles = toc
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line && !line.startsWith("#") && line.endsWith(".lua"))
  .map((relative) => relative.replaceAll("\\", path.sep));

if (runtimeFiles.length === 0) {
  console.error("STEP.toc does not contain any Lua runtime files.");
  process.exit(1);
}

const requestedRuntime = process.argv[2];
let command;
let args;

if (requestedRuntime) {
  command = requestedRuntime;
  args = ["tests/run.lua", ...runtimeFiles];
} else {
  command = process.execPath;
  args = [
    path.join(root, "node_modules", "fengari-node-cli", "src", "lua-cli.js"),
    "tests/run.lua",
    ...runtimeFiles,
  ];
}

const result = spawnSync(command, args, {
  cwd: root,
  stdio: "inherit",
  shell: false,
});

if (result.error) {
  console.error(`Could not start ${requestedRuntime || "Fengari"}: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);
