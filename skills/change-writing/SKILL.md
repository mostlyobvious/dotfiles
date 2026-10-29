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
- What can be omitted because it is filler, obvious from the diff, or likely to go stale?

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
- State how the change was verified when the format calls for verification. Never add a verification section or verification bullet to commit messages.
- For MR/PR descriptions, do not include test counts; they go stale during rebases.
- Link source material when it influenced the change: issue, MR, Slack thread, article, docs, changelog, release, or compare view.
- Trace historical and behavioural claims to a commit, date, or document. When the source cannot be found, say so instead of paraphrasing what it probably said.
- When behaviour changes, include a concrete before/after example in the commit body and MR/PR description.
- Write for a reader with no prior context. Replace assumptions about prior knowledge with a concrete example.
- For dependency upgrades, link the changelog for the traversed version range. When no changelog exists, link the release or compare view instead.
- Use plain language. Avoid marketing tone, hero language, drama, jargon, filler, and restating the diff.
- Prefer concise bullets when several facts compete for attention, and cut anything the audience does not need for the next decision.
- For benchmarks, use a table with before/after when there is a baseline, and say how each number was measured.
- Make the subject, title, or first sentence tell the audience whether the change affects them and why it matters: "Stop double-charging retried webhooks", not "Refactor webhook handler".
- Define each domain or internal term before its first use. The text must make sense without following any link.
- Match vocabulary to the audience: a user-facing changelog does not name internal classes or modules.
- In changelogs and release notes, describe what improved ("Imports finish in 2 min"), not what is no longer broken. Cut entries like "various improvements and bugfixes".
- Use passive voice deliberately in incident write-ups and reverts to keep the focus off who caused the failure.
- Write sentences specific to this change. A sentence that could move unchanged into another project's text says nothing; cut it.
- When a number, name, or mechanism is missing from the sources, say so ("We have not benchmarked query time before and after") instead of estimating one.
- Docs and code comments describe current behavior. The previous approach belongs in the commit, changelog, or migration guide.
- Write only text addressed to the reader. Instructions about the text ("keep it short") and chat wrappers ("Let me know if you'd like me to", "I've gone ahead and") stay in the conversation.

## Improving Existing Text

When asked to improve a draft someone else wrote:

- Make the smallest edit that fixes the problem, and keep the author's vocabulary and tone.
- Keep quotes, error strings, commands, and the user's own words exactly as written.
- Return "This needs no changes" when the draft already meets the standards.

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

## Review Pass

Run this on the finished draft before presenting it, and revise every hit:

1. Search the whole text, headings, titles, and list items included, for not-X-but-Y contrasts, groups of three, bold labels that restate their text, one-line closers, and chat wrappers.
2. Check that the text is:
   - Accurate against the code, diff, tests, and linked sources.
   - Complete for the audience's next action, but no broader.
   - Structured with headings or bullets that make scanning easy.
   - Consistent with project terminology and existing docs.
   - Clear about risk, rollout, compatibility, and verification when relevant and allowed by the format.
   - Free of unsupported claims, stale details, private names, jargon, drama, and needless verbosity.
