# Harmon Stack
This repo allows you to create a new project using the Harmon Stack template which bootstraps numerous configurations and tools for you.

Author: Evan Harmon

[![Validate](https://github.com/evanharmon1/harmon-stack/actions/workflows/validate.yml/badge.svg)](https://github.com/evanharmon1/harmon-stack/actions/workflows/validate.yml)
[![Security](https://github.com/evanharmon1/harmon-stack/actions/workflows/security.yml/badge.svg)](https://github.com/evanharmon1/harmon-stack/actions/workflows/security.yml)
[![Copier](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/copier-org/copier/master/img/badge/badge-grayscale-inverted-border-orange.json)](https://github.com/copier-org/copier)

## Usage
Create a new project with: `copier copy harmon-stack new-project --trust`

The command will ask you a series of questions to create a new project.
Before using for the first time you will probaby want to customize the copier.yml file. Most importantly, the variables that aren't presented to you when you create a project (i.e, the varables that are set to `when: false`).

### Standard Procedure For New Projects
1. From your git directory: `copier copy harmon-stack new-project --trust`, replacing `new-project` with the name of your new project.
2. Initialize git repo?: Yes
3. Create new repo on GitHub?: Yes
4. Create initial release on GitHub?: Yes
After initial questions, GitHub will ask questions about creating the repo on GitHub.
1. Choose "Push an existing localy repository to GitHub" and choose the current path (.)

## Setup & Installation

### Requirements
- Homebrew
- Python
- [Taskfile](https://taskfile.dev/)
- [Copier](https://copier.readthedocs.io/en/stable/)

### Task Runner
[Taskfile.yaml](Taskfile.yaml)

### Testing

#### Validate
`task validate`

#### Security
`task security`

#### Linting, Formatting, Conventions, Style Guidelines, etc
- .pre-commit-config.yaml
- .shellcheckrc
- .ansible-lint-ignore

## Todo File
[todo.md](todo.md)
