---
applyTo: "**/package.json,**/.npmrc,**/.nvmrc,**/Dockerfile*,**/docker-compose*.yml,**/compose*.yaml"
description: Node.js / npm operational conventions
---
- package-lock.json is the source of truth. Never hand-edit it; regenerate with npm. CI installs with `npm ci`.
- Investigate dependencies with `npm ls <pkg>` / `npm explain <pkg>`, never by reading the lockfile.
- Keep `engines.node`, `.nvmrc`, the Dockerfile base image and the CI node version in sync.
- Fix transitive vulnerabilities by upgrading the direct parent first, then `overrides`. Never `npm audit fix --force` without reviewing each major bump.
- Dockerfile: multi-stage build, pinned base image tag (digest if possible), `npm ci --omit=dev` in the runtime stage, `USER node`, `NODE_ENV=production`, `.dockerignore` excluding node_modules and .git.
- Registry tokens in `.npmrc` come from env vars (`//registry.npmjs.org/:_authToken=${NPM_TOKEN}`), never literal values.
