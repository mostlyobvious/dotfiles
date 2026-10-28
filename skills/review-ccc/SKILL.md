---
name: review-ccc
description: Review a branch or MR for correctness, consistency, and cohesion, including its commits and description. Use when asked to review "C C C", for correctness, consistency, and cohesion, or whether commits make logical units.
---

# Review: Correctness, Consistency, Cohesion

Review the branch against its target. Read the diff, each commit, and the MR description.

## Correctness

- The code does what the MR description claims; check each claim against the diff.
- Edge cases the change touches have tests; tests pin behaviour, not plumbing.
- Run the mutant skill on changed Ruby code when the project uses mutant.

## Consistency

- Naming, layout, and idiom match the surrounding code.
- The MR description and commit messages match the current diff, follow the change-writing skill, and leave out work this MR does not do.

## Cohesion

- Each commit is one logical change that builds and passes on its own. Flag additions that an existing mechanism, deletion, or simplification could replace.
- Commits are ordered so each one reads as a step from the previous; decisions reversed later in the branch are squashed away.
- The MR holds one concern; propose a split into stacked MRs when it holds more.

## Report

List findings by severity with `file:line`. For commit problems, propose the new commit series as a list of subjects. Apply fixes only when asked.
