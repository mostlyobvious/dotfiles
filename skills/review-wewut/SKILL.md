---
name: review-wewut
description: Review or refactor tests for readable setup, behavioural assertions, public-interface coverage, and low implementation coupling. Use when asked to improve test design, test readability, hidden setup, test doubles, solitary or sociable tests, or to review tests according to WEWUT.
---

# Review Test Design

Review the named tests or the tests changed against the target branch. Change tests only when asked to refactor them.

## Procedure

1. Establish the scope and the command that runs it. Run the scoped tests before reviewing so existing failures stay separate from findings.
2. Read each test and the production interface it exercises. Judge what behaviour the test protects, not only how the test is written.
3. Account for every test in scope. Use searches and metrics to find candidates, then inspect each candidate before reporting it.
4. Apply the principles below. Distinguish a readability problem from a test that prevents a behaviour-preserving production refactor.
5. For a review, report findings and change nothing. For a requested refactor, make the smallest behaviour-preserving changes and rerun the scoped tests.

## Principles

### Show the example's story

- Keep decisive setup in the example. Extract incidental construction, not inputs that explain the behaviour.
- Arrange each example as setup, action, then assertions.
- Name the behaviour and distinguishing case. A reader should understand a failure from the example name.
- Use literal expected values. Calculating the expected value can reproduce the production mistake and makes the reader execute both implementations mentally.

### Give failures one meaning

- Give each independent behaviour its own example.
- Compare a coherent result as one value when its fields express one outcome; split assertions that represent separate outcomes.
- Replace loops with parameterized examples that receive independent names and results.
- Keep negative examples for meaningful boundaries, not every imaginable absence.

### Protect behaviour, not implementation

- Exercise public interfaces. Direct tests of private methods turn internal structure into a contract.
- Assert observable state when state expresses the result. Verify messages when sending the message is the result or no observable state exists.
- Constrain arguments, counts, and order only when the public behaviour requires them.
- Prefer verified doubles for collaborators. Give each double the smallest interface the example needs.
- Use solitary tests when real collaborators obscure the subject's decisions. Use sociable tests when collaboration itself forms the behaviour. Keep broad-stack tests deliberate and separate from focused tests.

### Make dependencies visible

- Avoid automatic fixtures, global stubs, and shared setup that supply behaviour the example depends on without showing it.
- Replace broad factories or object mothers with focused builders when defaults hide why the example passes.
- If a test cannot substitute a collaborator without patching construction or every instance, identify the missing production seam rather than adding more test magic.

## Report

List findings in priority order. Each finding includes:

- `file:line`
- the affected behaviour
- the principle violated
- the concrete maintenance, diagnostic, or refactoring cost
- the smallest useful rewrite
- whether production code needs a new seam

Then state what already works well, the scope reviewed, exclusions, and the baseline test result. Do not report counts or search matches as findings until inspection confirms the problem.
