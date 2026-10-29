---
name: mutmut
description: Run mutmut, investigate surviving or untested Python mutants, improve tests or simplify code, justify exclusions, and verify the mutation gate. Use for Python mutation testing, mutmut runs, surviving mutants, mutation scope changes, or mutmut CI failures.
---

# Mutmut

Use mutation testing to discover behaviour the tests do not constrain and power the implementation does not need. The target is useful evidence rather than a higher score by itself. Every non-killed mutant must lead to a supported behavioural example, a simpler implementation, dead-code removal, a justified exclusion, or a diagnosed test-selection or infrastructure problem.

## Establish the project contract

Before running mutmut:

1. Read the repository instructions, test documentation, `[tool.mutmut]` configuration, CI mutation job, and any mutation-gate checker.
2. Identify the project command prefix, such as `uv run`, and run it through the repository's development environment.
3. Read `source_paths`, `only_mutate`, `do_not_mutate`, `also_copy`, pytest arguments, cache settings, and process-isolation settings.
4. Confirm that generated `mutants/` state stays outside version control and build contexts.
5. Run the selected tests without mutation. A failing baseline cannot classify mutants reliably.
6. Determine the gate's actual completion criterion. `mutmut run` alone is not proof that the gate passes.

## Run and inspect

Use the repository's command prefix in place of `uv run` when it differs.

```sh
uv run mutmut run
uv run mutmut results
uv run mutmut show <mutant-name>
uv run mutmut tests-for-mutant <mutant-name>
```

Run one mutant or a wildcard while iterating:

```sh
uv run mutmut run '<mutant-name>'
uv run mutmut run 'package.module.function*'
```

Use `mutmut browse` when the terminal interface makes a large result set easier to inspect.

For each non-killed result, read:

- the mutation diff;
- the complete function and its callers;
- the selected tests shown by `tests-for-mutant`;
- the domain contract, schemas, fixtures, reference runs, and historical rationale that define valid inputs.

Infer the contract from producers, schemas, callers, reference data, and history, using the current tests as supporting evidence.

## Classify every non-killed result

### Survived

A survived mutant ran relevant tests and none failed. Ask whether the mutated behaviour is valid for every supported input.

Choose the next action. A behavioural example may establish the invariant before a later simplification:

1. **Add a behavioural example** when the mutant violates the contract. The example must pass on the original source and fail with that exact mutant. Keep the decisive input visible in the test body.
2. **Simplify the implementation** when the mutation is correct for every supported input and expresses a tighter invariant. Apply the semantic change directly with Edit, then run tests, typechecking, linting, and the targeted mutant.
3. **Remove dead code** when no supported execution reads the result or reaches the branch. Search callers and history, then follow the repository's dead-code process. Do not add a test that preserves dead code.
4. **Exclude an equivalent mutant** only when no supported input distinguishes the forms, the mutated form cannot safely replace the source, and no clearer implementation removes the mutation axis.

Use inputs that the producer, schema, or public interface can create. A test for an impossible shape preserves accidental power rather than behaviour.

### No tests

`no_tests` means the selected tests do not execute the mutated code. Check:

- whether the code is dead;
- whether `pytest_add_cli_args_test_selection` or deselection removed the relevant test;
- whether mutmut copied every required test, fixture, data file, and helper through its normal inputs or `also_copy`;
- whether the test imports code outside the mutation sandbox;
- whether `max_stack_depth` excludes incidental coverage.

Fix the scope or test placement when the behaviour should be covered. Do not mark a configuration failure as equivalent.

### Suspicious, timeout, segfault, interrupted, skipped, or unchecked

Treat every non-killed status as unresolved unless the repository explicitly defines another policy.

- `suspicious`: inspect the unknown pytest exit code and rerun the selected tests manually.
- `timeout`: determine whether the mutant exposes missing termination behaviour or the timeout is too tight.
- `segfault`: reproduce with the selected tests; consider `process_isolation = "forkserver"` when test setup is not fork-safe.
- interrupted, skipped, or unchecked: complete the run before claiming coverage.

Infrastructure failures are not killed mutants.

## Prefer supported examples

A useful mutation test names a domain outcome and places the distinguishing value at the boundary the mutant changes. Common examples include:

- values immediately below, at, and above a threshold;
- two rows where `continue` and `break` differ;
- objects whose fields return different values, exposing which field is read;
- omitted optional arguments when the default is contractual;
- multiple elements where first, next, ordering, deduplication, or caps matter;
- public adapter calls using a fake transport rather than direct tests of private helpers.

Keep setup helpers for incidental structure. Do not hide the membership, ordering, date, count, or field value that explains the expected result.

## Accept simplifications deliberately

A surviving mutation often identifies an unused fallback, guard, parameter, conversion, or state update. Before accepting it:

1. Prove the stronger invariant from producers, schemas, callers, or reference data.
2. Check that the mutation preserves behaviour across the full supported input domain.
3. Apply the smallest source change that states the invariant.
4. Run the targeted tests and mutant.
5. Run typechecking and linting; a runtime-equivalent mutation can still violate the type contract.

A source rewrite must improve the implementation or state the domain more accurately, rather than merely removing a mutation axis.

When tests establish the invariant before a simplification, keep the test and simplification as separate logical commits.

## Exclude only proven equivalents

Use `# pragma: no mutate`, `do_not_mutate_patterns`, or `do_not_mutate` only after test, simplification, and deletion have been rejected with evidence.

For an inline pragma:

- keep the excluded statement as small as possible;
- state why no supported input distinguishes the forms;
- state why the mutation cannot replace the source;
- check every other mutant hidden by the same pragma, because mutmut suppresses the whole statement;
- keep nearby behavioural examples for the parts of the statement that remain contractual.

When a valid domain input distinguishes the forms, classify the mutant as killable rather than equivalent.

Whole-file exclusions must name their reason in configuration, such as an LLM path measured by evals, an I/O edge covered elsewhere, generated code, or deterministic code whose mutation burn-down is explicitly deferred.

## Expand mutation scope as a burn-down

When bringing existing code under mutmut:

1. Add the broad intended source scope and list deferred files under `do_not_mutate` by reason.
2. Select one cohesive file or module.
3. Run its mutants and classify every non-killed result.
4. Add supported examples, simplify code, remove dead code, or justify minimal exclusions.
5. Remove the file from `do_not_mutate` only after its complete mutant set is resolved.
6. Keep the gate-only configuration change in the final commit for that file.

A new deterministic module should enter the gate with its first commit when practical. Do not expand scope and leave unexplained survivors behind a passing percentage threshold when the project requires a clean gate.

## Verify the real gate

For projects with a strict CI gate, run the complete sequence, not only mutmut:

```sh
uv run mutmut run
uv run mutmut export-cicd-stats
uv run python <project-mutation-checker>
```

The checker should reject:

- survived, no-tests, suspicious, timeout, interrupted, segfault, skipped, or unchecked mutants;
- incomplete totals where `killed != total` under a killed-only policy;
- empty runs.

Also run the normal test suite, typechecker, and linter. Run reference or characterization suites that CI omits when a simplification relies on their domain coverage.

For large runs, reduce concurrency with `--max-children` when workers exhaust memory. Report resource failure separately from mutation results.

## Reporting format

Lead with the mutation verdict and counts. For each unresolved mutant, report:

```text
<Classification>: <mutant name>

Mutation: <original -> mutated behaviour>
Evidence: <supported input, invariant, caller, schema, or selected tests>
Action: <test, simplification, deletion, exclusion, config fix, or infrastructure fix>
Verification: <targeted mutant and relevant project checks>
```

Use one of these classifications: **Killable**, **Simplification**, **Dead code**, **Equivalent exclusion**, **Configuration gap**, or **Infrastructure failure**.

## Completion criteria

- Every configured mutant has a resolved status under the project's policy.
- Every new test fails against the mutant it was added to kill.
- Tests cover supported domain inputs rather than impossible shapes.
- Accepted mutations make the implementation smaller or state a stronger invariant.
- Dead code is removed instead of preserved by tests.
- Every exclusion records why testing, applying the mutation, and clearer restructuring failed.
- The full project mutation gate, tests, typechecking, and linting pass.
- The report states the final killed and total counts and any remaining exclusions.
