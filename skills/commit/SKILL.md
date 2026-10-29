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
- Do not reference related commits by hash; rebases replace hashes. Link a durable issue, merge request, or document instead.
- Context you would otherwise give a reviewer in chat or a review comment belongs in the body.
- Exclude review chatter and links that expire, such as preview or test-environment URLs.

## Scope

- One logical change per commit; split unrelated concerns.

## Procedure

1. Read `../change-writing/SKILL.md`.
2. `git status` + `git diff --staged` (and `git diff` if unstaged) to confirm scope.
3. Draft subject + body.
4. When the staged files match one logical change and the message follows this skill, write the exact message to a temporary file with Write.
5. Commit with `git commit -F <message-file>`.
6. Verify that `git show -s --format=%B HEAD` matches the draft exactly.
7. Report the commit hash and subject.
8. No `--no-verify`. No amending published commits. Use `--force-with-lease` without asking only after an amend or rebase in the current task, on the current feature branch. Ask before any other force push. Never use plain `--force`.
