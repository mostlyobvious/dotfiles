---
name: change-writing
description: Write or improve technical prose about code changes. Use for commit bodies, MR/PR descriptions, changelogs, release notes, technical docs, API docs, user guides, or reviewer-facing summaries.
---

# Change Writing

## When Invoked

1. Identify the writing job: commit message, MR/PR description, technical doc, API reference, guide, changelog, release note, or reviewer summary.
2. Identify the audience: future maintainer, reviewer, operator, API consumer, end user, administrator, or SDK user.
3. Review the source material: diff, commits, code, tests, existing docs, issue/MR links, changelogs, incidents, user feedback, and project templates.
4. Find gaps: missing context, unclear problem statement, unverified claims, absent examples, undocumented risks, inconsistent terminology, or stale docs.
5. Write the smallest complete artifact that helps the audience succeed.

## Planning Phase

Before writing, answer the useful subset of:

- What is the audience trying to decide or do?
- What problem, decision, or user journey does this document?
- What existing docs, templates, or project conventions must be preserved?
- What terms should stay consistent with the codebase or product language?
- What does the reader need first: context, steps, examples, trade-offs, or proof?
- What success signal matters: review approval, safe rollout, fewer support questions, easier onboarding, or correct API usage?

## Content Types

Choose the shape that matches the task:

- Commit message: decision record for future maintainers.
- MR/PR description: reviewer guide to scope, intent, risk, and verification.
- Developer docs: concepts, setup, integration paths, examples, and troubleshooting.
- API docs: endpoints, parameters, request/response examples, authentication, errors, and compatibility notes.
- User/admin guides: task-based steps, expected results, caveats, and recovery paths.
- Changelog/release notes: user-visible change, upgrade impact, migration notes, and links.

## Writing Standards

- Lead with the problem, not the implementation.
- Explain why the change is needed and what outcome it creates.
- Use progressive disclosure: start with what the reader needs now, then add details.
- Prefer task-based writing for guides: goal, prerequisites, steps, expected result, troubleshooting.
- Include examples when they reduce ambiguity; keep them tested or clearly illustrative.
- Include diagrams, screenshots, or tables only when they clarify more than text would.
- Include only implementation details that affect review, operation, migration, API use, or future changes.
- Call out risks, compatibility behavior, rollout constraints, and follow-ups when they matter.
- State how the change was verified. If not verified, say so plainly.
- Link source material when it influenced the change: issue, MR, Slack thread, article, docs, changelog, release, or compare view.
- Use plain language. Avoid marketing tone, filler, and restating the diff.
- Prefer concise bullets when several facts compete for attention.
- For benchmarks, use a table with before/after when there is a baseline, and say how each number was measured.

## API Documentation Checklist

When writing API or SDK docs, include the relevant subset:

- Purpose and when to use the API.
- Authentication and authorization requirements.
- Parameters, types, defaults, constraints, and examples.
- Request and response examples.
- Error cases and recovery guidance.
- Versioning, deprecations, compatibility, and rate limits.
- Minimal working example before advanced usage.

## User Guide Checklist

When writing user-facing or admin-facing docs, include the relevant subset:

- Goal and prerequisites.
- Steps in the order the user performs them.
- Expected result after each major step.
- Common mistakes and troubleshooting.
- Safety notes, permissions, rollback, or data impact.
- Links to deeper reference material.

## Excellence Checklist

Before presenting prose, check that it is:

- Accurate against the code, diff, tests, and linked sources.
- Complete for the audience's next action, but no broader.
- Structured with headings or bullets that make scanning easy.
- Consistent with project terminology and existing docs.
- Clear about risk, rollout, compatibility, and verification when relevant.
- Free of unsupported claims, stale details, private names, and needless verbosity.
