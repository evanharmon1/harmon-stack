# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Harmon Stack is a **Copier project template** that scaffolds new projects with pre-configured DevOps tooling, CI/CD pipelines, linting, security checks, and task runners. This is NOT an application — it is a template repository used to generate new projects via the [Copier](https://copier.readthedocs.io/en/stable/) templating tool.

## Common Commands

```bash
# Generate a new project from this template
copier copy harmon-stack new-project --trust

# Validate (runs pre-commit hooks)
task validate

# Run pre-commit hooks directly
task preCommit
# or: pre-commit run --all-files

# Security scanning (secrets + SAST)
task security

# Version bumping (tags, pushes, creates GitHub release)
task vBumpPatch
task vBumpMinor
task vBumpMajor
```

## Architecture

### Two-Layer Structure

This repo has two layers that mirror each other:

1. **Root level** — Config files for developing/maintaining the template itself (`Taskfile.yml`, `package.json`, `.pre-commit-config.yaml`, etc.)
2. **`template/` directory** — The Copier template root (`_subdirectory: template` in `copier.yml`). Contains files that get copied into generated projects, often with `.jinja` extensions for variable substitution.

### Key Files

- **`copier.yml`** — Template configuration: defines all questions/variables presented during project creation, post-copy tasks (`_tasks`), and Copier settings. Variables with `when: false` are hidden from the user and use defaults.
- **`template/`** — Everything in here becomes the generated project. Jinja2 conditionals in filenames control inclusion (e.g., `{% if docker %}docker{% endif %}/` — directory only created if user answers yes to docker).
- **`Taskfile.yml`** — Task runner commands for this repo (validate, security, versioning).
- **`check_for_pattern.sh`** — Bash script for detecting secret files during security scans.

### Copier Template Patterns

- Files ending in `.jinja` have template variables substituted during generation (e.g., `README.md.jinja`, `Taskfile.yml.jinja`).
- Directories/files with Jinja2 conditionals in their names are conditionally included based on user answers.
- Post-copy tasks in `copier.yml` `_tasks` run after file generation (git init, GitHub repo creation, etc.).

## CI/CD (GitHub Actions)

- **`validate.yml`** — Runs pre-commit hooks on PRs.
- **`security.yml`** — Runs secret scanning (`check_for_pattern.sh` + `whispers`) and SAST (`snyk test`) on PRs.
- **`release.yml`** — Auto-bumps patch version and creates a GitHub release on push to main.

## Code Style

- No direct commits to main (enforced by `no-commit-to-branch` pre-commit hook).
- Indentation: 2 spaces for JS/TS/JSON/CSS/HTML/YAML/Markdown; 4 spaces for Python/Dockerfile/Bash (see `.editorconfig`).
- Python formatted with Black; JS/TS with Prettier + ESLint.
- Shell scripts linted with ShellCheck (excludes SC3037, SC2148).
