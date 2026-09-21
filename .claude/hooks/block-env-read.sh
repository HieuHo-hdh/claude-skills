#!/usr/bin/env bash
# PreToolUse hook: block Claude from reading any .env* file.
# Reads the tool payload as JSON on stdin; exits 2 to block with a message.

node -e '
let raw = "";
process.stdin.on("data", (c) => (raw += c));
process.stdin.on("end", () => {
  let filePath = "";
  try {
    const payload = JSON.parse(raw);
    filePath = payload?.tool_input?.file_path ?? "";
  } catch (_) {
    process.exit(0);
  }
  const base = filePath.split("/").pop() || "";
  // Templates are safe to read; only real env files are blocked.
  const ALLOW = new Set([".env.example", ".env.sample"]);
  if (/^\.env(\..+)?$/.test(base) && !ALLOW.has(base)) {
    process.stderr.write(
      "Blocked by project policy: reading .env* files is not allowed. " +
      "See .env.example for the shape of the required variables.\n"
    );
    process.exit(2);
  }
});
'
