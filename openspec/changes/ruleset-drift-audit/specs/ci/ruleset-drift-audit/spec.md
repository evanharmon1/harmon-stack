## Purpose

Detects divergence between the branch-protection ruleset committed to a repository and the corresponding live GitHub ruleset without changing either source.

## ADDED Requirements

### Requirement: Read-only ruleset comparison

The audit command SHALL read the ruleset name from the checked-in ruleset JSON, locate the matching live ruleset through the repository ruleset API, normalize comparison-only metadata, and print a readable comparison. It MUST NOT write repository or ruleset state.

#### Scenario: Identical rulesets

- **WHEN** the normalized checked-in and live rulesets contain the same rules, flags, and required-check contexts
- **THEN** the audit prints an identical result and exits with status 0

#### Scenario: Ruleset drift

- **WHEN** normalization finds a missing or extra rule, flag, or required-check context
- **THEN** the audit prints a readable diff and exits with status 1

#### Scenario: Non-comparable live state

- **WHEN** the repository is not a GitHub repository, the CLI lacks permission, or the named live ruleset is absent
- **THEN** the audit explains the unavailable state and exits with status 2

### Requirement: Profile-aware generated audit

The generated project SHALL include the audit task and script, and its comparison input SHALL retain only the required-check contexts enabled by the rendered profile, including conditional CodeQL, Terraform, and devcontainer contexts.

#### Scenario: Profile contexts

- **WHEN** a generated profile enables or disables a conditional workflow
- **THEN** the rendered ruleset contains exactly the corresponding required-check context and the fixture comparison can report it without treating valid profile variation as drift

### Requirement: Hermetic regression coverage

The repository SHALL provide fixture-driven tests that exercise successful comparison, missing required-check context, an extra live flag, an absent ruleset, and permission denial without contacting GitHub.

#### Scenario: Fixture failure modes

- **WHEN** each comparison fixture is supplied to the audit implementation
- **THEN** the test verifies the expected readable result and exit class for that fixture
