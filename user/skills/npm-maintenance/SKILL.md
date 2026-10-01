---
name: npm-maintenance
description: Triage and fix npm dependency problems in Node.js apps, including npm audit vulnerabilities, Dependabot/Renovate security alerts, a CVE in a JS package, outdated packages, `npm ci` / lockfile-out-of-sync failures, ERESOLVE peer dependency errors, and Node.js runtime upgrades (.nvmrc, engines, Docker base image, CI). Use whenever package.json or package-lock.json is involved.
argument-hint: "[package | CVE/GHSA id | audit | node upgrade]"
---

# npm maintenance

## Rule: never open package-lock.json
It is thousands of lines. Use instead:
- `npm-audit-summary` for vulnerabilities + outdated in ~30 lines ([script](./scripts/npm-audit-summary.sh); or `bash <this skill's folder>/scripts/npm-audit-summary.sh`). Env: `INCLUDE_DEV=1`, `MIN_SEVERITY=high`, `SKIP_OUTDATED=1`.
- `npm ls <pkg>` (who pulls it in), `npm explain <pkg>` (why), `npm view <pkg> version` (latest).

## Vulnerabilities
1. Run `npm-audit-summary` (production deps, moderate and up by default).
2. Prioritize critical/high in production deps. Dev-only findings rarely matter at runtime but do matter for CI supply chain; mention them in one line.
3. Fix ladder, stop at the first step that works:
   1. `npm audit fix` (semver-compatible changes only).
   2. Upgrade the direct parent shown by `npm ls <vuln-pkg>` to a version that pulls the fixed transitive.
   3. `overrides` in package.json, e.g. `"overrides": { "qs": "^6.14.0" }` or scoped `{ "express": { "qs": "^6.14.0" } }`, then `npm install`.
   4. No fix available: write down reachability/exposure and a revisit date (accepted risk).
   Never `npm audit fix --force`; it applies semver-major bumps blindly. Items marked `(MAJOR)` need a changelog check.
4. Verify: `npm ci && npm test && npm run build`, then rerun the summary.

## Outdated
Patch/minor updates: batch them into one PR. `[MAJOR]`: handle one package per PR and read only that package's breaking-changes notes.

## `npm ci` / ERESOLVE failures
- "lock file out of sync": run `npm install` with the same npm major version as CI and commit the lockfile.
- ERESOLVE: find which package declares the conflicting peer range (`npm explain <pkg>`) and upgrade it. Use `legacy-peer-deps=true` in `.npmrc` only as a documented last resort.

## Node.js runtime upgrade
Change all of these in one PR: `.nvmrc`, `engines.node`, every Dockerfile base image, CI `node-version`/`node-version-file`, and the `@types/node` major.
Check current LTS and end-of-life dates at nodejs.org/en/about/previous-releases instead of relying on memory.
Then: `rm -rf node_modules && npm ci` (rebuilds native modules), run the full test suite, and scan for removed APIs and OpenSSL-related changes in the Node release notes.
