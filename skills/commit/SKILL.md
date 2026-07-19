---
name: commit
description: Create a git commit following project conventions. Use this skill when asked to commit changes, group changes into commits, or prepare commits.
---

# Commit

## Format

```
<Capitalized imperative subject ≤50 chars>

<Body wrapped at 72 cols, explaining why.>
```

- Subject: Capitalized imperative ("Fix bug", not "Fixed"). No trailing period.
- Blank line between subject and body. Body wrapped at 72 cols.
- Prefer `*` bullet points in the body over prose paragraphs. Hanging indent for wrapped lines. Blank lines between points.
- Body explains **why** (and, when non-obvious, **how** and **what effects** — benchmarks, side effects, follow-ups). Skip questions that don't apply. Never restate the diff.
- Link the source when it has a URL: the reference article or blog post that informed the change, the guide or documentation it follows, or the decision behind it (task, issue, message).

## Scope

- One logical change per commit; split unrelated concerns.

## Procedure

1. `git status` + `git diff --staged` (and `git diff` if unstaged) to confirm scope.
2. Draft subject + body.
3. Present the staged files and message for approval
4. Wait for user confirmation before committing
5. No `--no-verify`. No amending published commits. No force-push without explicit request.
