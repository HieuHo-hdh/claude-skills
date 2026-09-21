#!/usr/bin/env bash
# PreToolUse hook: block destructive git / shell operations.
# Reads the tool payload as JSON on stdin; exits 2 to block with a message.

node -e '
const DANGEROUS_PATTERNS = [
  "git push",
  "git reset --hard",
  "git clean -fd",
  "git clean -f",
  "git branch -D",
  "git checkout .",
  "git restore .",
  "push --force",
  "reset --hard",
];

let raw = "";
process.stdin.on("data", (c) => (raw += c));
process.stdin.on("end", () => {
  let cmd = "";
  try {
    const payload = JSON.parse(raw);
    cmd = payload?.tool_input?.command ?? "";
  } catch (_) {
    process.exit(0);
  }
  for (const pattern of DANGEROUS_PATTERNS) {
    if (cmd.includes(pattern)) {
      process.stderr.write(
        `BLOCKED: "${cmd}" matches dangerous pattern "${pattern}". ` +
        `The user has prevented you from doing this.\n`
      );
      process.exit(2);
    }
  }
});
'
