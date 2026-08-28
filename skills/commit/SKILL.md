---
name: commit
description: Create a git commit following project conventions. Use this skill when asked to commit changes, group changes into commits, or prepare commits.
---

# Commit

Before drafting the message, read and apply `../change-writing/SKILL.md`.

## Format

```
<Capitalized imperative subject ≤50 chars>

<Body wrapped at 72 cols, explaining why.>
```

- Subject: Capitalized imperative ("Fix bug", not "Fixed"). No trailing period.
- Blank line between subject and body. Body wrapped at 72 cols.
- Prefer `*` bullet points in the body over prose paragraphs. Hanging indent for wrapped lines. Blank lines between points.
- Body explains **why** (and, when non-obvious, **how** and **what effects** — benchmarks, side effects, risks, follow-ups). Skip questions that don't apply. Never restate the diff.
- Write for the next maintainer: record the problem or decision, the expected outcome, and any operational or compatibility impact.
- Link the source when it has a URL: the reference article or blog post that informed the change, the guide or documentation it follows, the dependency changelog/release/compare view, or the decision behind it (task, issue, message).
- Include verification when it is part of the evidence for the change.

## Scope

- One logical change per commit; split unrelated concerns.

## Procedure

1. Read `../change-writing/SKILL.md`.
2. `git status` + `git diff --staged` (and `git diff` if unstaged) to confirm scope.
3. Draft subject + body.
4. Present the staged files and message for approval
5. Wait for user confirmation before committing
6. No `--no-verify`. No amending published commits. No force-push without explicit request.
