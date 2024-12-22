# Harmon Stack
This repo allows you to create a new project using the Harmon Stack template which bootstraps numerous configurations and tools for you.
Author: Evan Harmon

[![Validate](https://github.com/evanharmon1/harmon-stack/actions/workflows/validate.yml/badge.svg)](https://github.com/evanharmon1/harmon-stack/actions/workflows/validate.yml)
[![Security](https://github.com/evanharmon1/harmon-stack/actions/workflows/security.yml/badge.svg)](https://github.com/evanharmon1/harmon-stack/actions/workflows/security.yml)

## Usage
Create a new project with: `copier copy harmon-stack new-project --trust`

test

The command will ask you a series of questions to create a new project.
Before using for the first time you will probaby want to customize the copier.yml file. Most importantly, the variables that aren't presented to you when you create a project (i.e, the varables that are set to `when: false`).

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
