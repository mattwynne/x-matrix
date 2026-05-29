# Fabro Readiness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prepare x-matrix to run Fabro iteration implementation workflows in the proven remote Docker/devenv sandbox shape.

**Architecture:** Move the Fabro image contract into `devenv.nix`, so the same project environment builds the runtime image. Harden the sandbox boundary with explicit writable paths, certificate/locale configuration, wrappers for `git` and `devenv`, an idempotent `bin/dev`, and a workflow preflight that proves the actual contract before coding starts.

**Tech Stack:** devenv/Nix containers, Fabro workflows, Phoenix/Elixir, Postgres, process-compose, Docker/GHCR.

---

### Task 1: Harden the devenv Fabro image

**Files:**
- Modify: `devenv.nix`

**Steps:**
1. Add `fabroGit`, `fabroDevenv`, and `fabroWritableDirs` let-bindings.
2. Add certificate, locale, and writable Mix/Hex environment variables.
3. Add `containers."fabro-dev"` with `ghcr.io/mattwynne/x-matrix-fabro-dev:latest`, bare tools in `/bin`, writable `/workspace` and `/repos`, disabled entrypoint, and `sleep infinity` startup.
4. Keep existing local packages, Elixir, JavaScript, Postgres, and Phoenix process definitions.

### Task 2: Make `bin/dev` the hard runtime boundary

**Files:**
- Modify: `bin/dev`

**Steps:**
1. Re-enter `devenv shell` exactly once with stale `DEVENV_*` and `PG*` variables cleared.
2. Require `argc` after shell entry.
3. Make `up` idempotent using `pg_isready`, `devenv processes down`, `devenv processes up --strict-ports -d postgres`, and readiness checks.
4. Add best-effort `down`.
5. Make `check` own service startup/cleanup and run `mix precommit`.

### Task 3: Update the Fabro workflow runtime

**Files:**
- Modify: `.fabro/workflows/iteration-implementation/workflow.toml`
- Modify: `.fabro/workflows/iteration-implementation/workflow.fabro`
- Optionally modify: `.fabro/environments/x-matrix-dev-docker/Dockerfile`

**Steps:**
1. Point the workflow image at `ghcr.io/mattwynne/x-matrix-fabro-dev:latest`.
2. Disable built-in clone and prepare `/workspace` explicitly.
3. Clone `https://github.com/mattwynne/x-matrix` into `/workspace`.
4. Add a preflight node after `read_plan` that checks tools, writable paths, `dev --help`, `dev up`, and a native dependency smoke compile.
5. Keep the existing implementation, dev-check, review, repair, and final summary flow.

### Task 4: Validate locally

**Files:**
- All modified files

**Steps:**
1. Run `fabro validate .fabro/workflows/iteration-implementation/workflow.fabro`.
2. Run `PATH="$PWD/bin:$PATH" dev check`.
3. Fix any failures.
