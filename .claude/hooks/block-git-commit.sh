#!/usr/bin/env bash
# PreToolUse hook: block any Bash command that invokes `git commit`.
# The user commits manually; Claude must not create commits.

node -e '
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
  // Match `git commit` at start, after &&/;/|, or after leading whitespace.
  if (/(^|\s|&&|;|\|)\s*git\s+commit\b/.test(cmd)) {
    process.stderr.write(
      "Blocked by project policy: Claude must not run `git commit`. " +
      "Stage the changes and let the user create the commit.\n"
    );
    process.exit(2);
  }
});
'
