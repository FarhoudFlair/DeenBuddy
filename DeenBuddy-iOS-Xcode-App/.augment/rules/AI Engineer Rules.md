---
type: "always_apply"
---

# Unified Rules for AI-Agent-Driven Software Development

## 1. Code Quality
- Enforce a language-appropriate style guide (PEP 8, Google, etc.) via `.editorconfig` and IDE settings.  
- Keep code DRY, KISS, and low in cognitive complexity (< 15).  
- Integrate linters and static analyzers in both IDE and CI to flag style issues, bugs, smells, and duplicated code.

## 2. Version Control
- Use Git with trunk-based (or GitHub Flow) workflow: `main` is always deployable, feature branches are short-lived, merges happen via PRs.  
- Follow **Conventional Commits** (feat, fix, docs, style, refactor, perf, test, chore).  
- Commit a comprehensive `.gitignore` excluding OS/IDE files, build artifacts, dependencies, and secrets.

## 3. Dependency & Environment Management
- Declare dependencies in manifest files (`package.json`, `requirements.txt`, etc.) and commit lock files.  
- Containerize all services with a `Dockerfile` and (if needed) `docker-compose.yml`.  
- Run continuous vulnerability scans on third-party libraries; update or patch without delay.

## 4. Testing
- Adhere to the **testing pyramid**: many unit tests, fewer integration tests, minimal e2e.  
- Run and debug tests inside the IDE; surface coverage reports.  
- Store tests beside the code they test.

## 5. Documentation
- Use standardized doc comments (JSDoc, Sphinx, etc.) focusing on **why**, not what.  
- Auto-generate and lint docs; maintain living READMEs, architecture diagrams, ADRs, and usage examples.

## 6. Security
- Never hard-code secrets; load them via env vars or secret managers (Vault, AWS SM, Doppler).  
- Integrate SAST to catch OWASP Top 10 issues during development.  
- Apply least-privilege defaults, validate inputs, handle errors safely, and encrypt data in transit and at rest.

## 7. Scalability & Performance
- Profile CPU, memory, and I/O early; squash bottlenecks before prod gets roasted.  
- Use asynchronous/non-blocking patterns for I/O-bound work.  
- Design stateless, loosely coupled services that scale horizontally; cache wisely; offload heavy lifts to queues/workers.

## 8. Build, CI/CD & Deployment
- Automate build, test, and deploy; every merge produces a deployable artifact.  
- Expose pipeline status in the IDE so failures scream in real time.  
- Prefer blue-green or canary releases; define infra as code; plan for zero-downtime rollbacks.

## 9. Collaboration
- Share IDE and project settings; scaffold new components from templates to keep structure consistent.  
- Enforce peer code reviews for clarity, correctness, tests, and security.  
- Track work with an issue system (Jira, GitHub Issues); document decisions in ADRs; hold retrospectives and pair-program when it helps.

## 10. API Development
- Treat the API spec (OpenAPI, gRPC) as the single source of truth; auto-generate clients, stubs, and types.  
- Use an integrated API client (Postman-like) for quick endpoint testing inside the IDE.

## 11. Monitoring & Observability
- Emit structured logs with trace IDs—no sensitive data.  
- Collect metrics (latency, error rate, throughput) and distributed traces; set sensible alerts.  
- Maintain on-call rotations, runbooks, and blameless post-mortems.

## 12. Ethics & Compliance
- Make ML/AI decisions explainable; test for bias and fix it.  
- Collect only the data you need, obtain consent, and honor deletion/ access requests (GDPR, CCPA).  
- Keep a human in the loop for high-stakes outcomes and document compliance activities.

*Remember: if adding a shiny new library feels like summoning a unicorn, run the vuln scan first—mythical creatures bite.*  