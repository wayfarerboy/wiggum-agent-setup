# Agent Guardrails & Guidelines

This file provides contextual guardrails for AI agents working in this repository.
When executing tasks, you must strictly adhere to the following rules:

## Coding Standards

- **Simplicity:** Keep code as simple and atomic as possible. Avoid over-engineering.
- **Style:** Adhere to the existing project style and formatting rules.
- **Type Safety:** If using TypeScript, ensure all new code is strictly typed. Avoid `any`.

## Testing & Verification

- **Never Commit Broken Code:** Before concluding any task, you must run the local test suite, linter and builder.
- **Test Commands:** `pnpm test`, `pnpm run lint` and `pnpm run build` (or adjust these to your project's commands).
- **Test Coverage:** If you write new utility functions or hooks, write corresponding Vitest unit tests (see Unit Tests below).

### Unit Tests

- **Framework:** Use [Vitest](https://vitest.dev/). Do not use Jest or any other test runner for unit tests.
- **File placement:** Co-locate test files alongside the source file they test (e.g., `lib/utils.test.ts` next to `lib/utils.ts`).
- **When to write:** Any new utility function, hook, or pure logic should have a corresponding Vitest unit test. Prefer many small, focused tests over large ones.
- **Running unit tests:** `pnpm test` (runs Vitest). Target a single file with `pnpm test path/to/file.test.ts`.
- **Passing bar:** All unit tests must pass before a task is considered complete. Fix failing tests — do not skip or delete them.

### End-to-End (E2E) Tests

- **When to write an e2e test:** Any task that fixes a user-facing flow (auth, navigation, form submission, redirects, visible UI state) or that a unit test cannot adequately cover should have a corresponding e2e test. If in doubt, ask: "could a real user trigger this regression?" — if yes, write the test.
- **When NOT to write an e2e test:** Pure refactors, internal utility changes, data model migrations, or tasks already covered by unit/integration tests.
- **Framework:** Use Playwright. Tests live in `tests/e2e/`. Follow existing naming conventions (e.g., `feature.spec.ts`). Reuse shared helpers (e.g., `tests/e2e/helpers/auth.ts`) rather than duplicating setup logic.
- **Running e2e tests:** `pnpm exec playwright test` (or target a specific file with `pnpm exec playwright test tests/e2e/feature.spec.ts`). Run only the relevant spec file during development; run the full suite before committing.
- **Passing bar:** All e2e tests must pass before a task is considered complete. If an e2e test you wrote fails, fix the implementation — do not skip or delete the test.

## GitHub Issues

When creating a GitHub issue:

- **Type:** Every issue must be labelled with either `type: bug` (something broken or not working correctly) or `type: feature` (something not yet built or a new capability).
- **Priority:** Every issue must be labelled with a priority. Use one of:
  - `priority: now` — urgent, blocking work
  - `priority: high` — important, should be addressed soon
  - `priority: medium` — normal priority
  - `priority: low` — nice to have, can wait
  - If the priority is not clear from context, **ask the user before creating the issue**.
- **State:** New issues should be labelled `state: pending` so the Ralph runner picks them up.

## Git & Commits

- Commit messages should follow the conventional commits format (e.g., `feat: ...`, `fix: ...`, `chore: ...`).
- Do not push directly to the `main` branch unless explicitly instructed.
- Only commit files that are directly related to the current task.
