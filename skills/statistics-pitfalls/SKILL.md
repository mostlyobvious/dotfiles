---
name: statistics-pitfalls
description: Check a comparison or claim drawn from data before reporting it. Use when comparing metrics across periods, segments or groups, ranking subgroups, explaining why a score moved, deciding whether a change is real, sizing a sample, or reviewing an analysis, dashboard or A/B test.
---

# Statistics Pitfalls

A finding ships only when it clears every check below. Otherwise report it as noise, or name the check it fails.

## Procedure

1. Name the comparison: the metric, the unit one row represents, the groups or periods, n per group, and the baseline.
2. Fix the decision rule before looking at results: significance level, the smallest change that matters, and the test.
3. Apply every section under "Checks". Mark each pass, fail, or not applicable.
4. Compute the effect size with its confidence interval, then the p-value. Use a statistics library (scipy, statsmodels), not hand arithmetic.
5. Report the effect, its interval, and n for every number, plus each failed check that limits the conclusion.

Done when every reported number carries n and an interval, and every check has a mark.

## Checks

### Count each unit once

- When one item carries several labels, de-duplicate before summing. Label counts add up to more than the items behind them.
- Test at the level where observations are independent. One customer giving many responses is one cluster: aggregate per customer or use cluster-robust errors.
- Bucket by when the event happened, not when it was processed. Trim periods with incomplete data, such as the current week or an ingestion gap.

### Compare against the right baseline

- Compare a subgroup with the population where its field is filled in. A sparse field carries selection bias, and the global average turns that bias into false outliers.
- Exclude fields that restate the outcome, such as a routing field derived from the category being analysed.
- Report percentages as absolute points (65% → 70% is +5 pp) and give relative change separately. Relative change on a small base is mostly noise.
- Average a ratio as the ratio of sums, or weight each group by its n.

### Rank by effect size

- At large n almost every difference reaches p < 0.001, so the p-value stops separating findings. Sort by effect size and filter by the lower bound of its confidence interval (Wilson interval for proportions).
- Require both statistical significance and the minimum meaningful change fixed in step 2.
- A non-significant result with a wide interval means "not enough data", not "no change". Report the interval.

### Correct for many comparisons

- Twenty segments tested at α = 0.05 yield one false hit on average. Apply Holm for a handful of tests, Benjamini-Hochberg for dozens or more.
- Count every test run, including the ones discarded.
- A subgroup found by scanning is a hypothesis. Confirm it on a later period before calling it a finding.

### Explain movement by its parts

- Split an aggregate change into each group's own change (rate) and the shift in group sizes (mix). Simpson's paradox: an aggregate can fall while every group rises.
- Groups picked for being extreme last period drift back toward the mean this period. Compare against groups that were not picked.
- Name who answered. Survey respondents and surviving customers differ from the population.
- Driver analysis shows association. Name plausible confounders before stating a cause.

### Size the sample

- n per group ≈ 15.7 σ² / δ² for 80% power at α = 0.05, where δ is the smallest change that matters. For a proportion, σ² = p(1 − p).
- Below about 5 expected per cell, switch to an exact test.

## Test selection

| Data | Two groups | Several groups | Small counts |
|---|---|---|---|
| Proportions | Two-proportion z-test | Chi-square | Fisher's exact |
| Means | Welch's t-test | Welch ANOVA, then pairwise with Holm | Mann-Whitney |
| Skewed values (durations, spend) | Mann-Whitney or t-test on logs | Kruskal-Wallis | Permutation test |
| Counts per period | Poisson rate test with exposure | Poisson or negative binomial regression | Exact Poisson |
| Trend over time | Regression slope with autocorrelation-robust errors; remove seasonality first | | |

A zero baseline (0 → 6) still has a test: compare the new count against the expected rate with an exact Poisson test.
