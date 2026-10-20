---
name: production-check
description: Check whether a deployed change is healthy in staging or production. Use when asked how production or staging is doing, whether a deploy or change is healthy, for new errors, deprecations, or log volume changes, or to monitor something being deployed.
---

# Production Check

Use the repository's MCP servers: `rollbar` for errors, `grafana` for Prometheus metrics, and `otel-clickhouse` for traces and logs in ClickHouse. Pass `--context` on every `kubectl` and `argo` command; the contexts are `production`, `production-us`, `staging`, and `infra`.

## Procedure

1. Pin the window: find when the change deployed (`rollbar` get-deployments, or the image rollout time with `kubectl --context <ctx>`). Compare the window after the deploy with the same length of time before it.
2. Cover every environment the change runs in. Production means both `production` and `production-us`.
3. Check, for the app the change belongs to:
   - new or reactivated Rollbar items since the deploy, and items whose rate rose
   - new deprecation warnings in logs
   - error and warning log volume
   - job throughput and failures (Sidekiq or workflow runs)
   - request rate and latency for affected endpoints
   - signals specific to the change, such as connection pool errors after a pool change
4. Present one table per environment:

   | Signal | Before | After | Source and query |
   | --- | ---: | ---: | --- |

5. State the verdict first: healthy, or the anomaly with its evidence. Name each anomaly as a Rollbar item link or a query someone can rerun. Report only what the queries showed.
