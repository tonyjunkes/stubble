# AGENTS.md

## Scope

This file applies to the entire repository.

## Project

Stubble is a Mustache-inspired template engine for CFML. The core implementation lives in `models/Stubble.cfc`.

This repository aims to support the official Mustache spec.

Treat spec compatibility as a primary concern when changing parsing or rendering behavior.

## Compatibility Targets

- Keep changes CFML engine agnostic.
- Supported targets are Adobe ColdFusion 2023+, Lucee 6+, and BoxLang 1+.
- Root `server-*.json` files define the CommandBox server options used for each engine target.
- CI also exercises additional bleeding-edge Adobe and Lucee configurations.
- Prefer portable CFML constructs. If an engine-specific workaround is required, isolate it and cover it with tests.

## Repository Layout

- `models/Stubble.cfc`: tokenizer, parser, renderer, lookup behavior, and template cache logic.
- `examples/`: runnable demos, including `examples/index.cfm` and supporting templates under `examples/templates/`.
- `tests/`: project test harness, specs, fixtures, and results.
- `tests/specs/unit/`: unit coverage for tokenizer, parser, render, file-template, cache, and Mustache behaviors.
- `tests/specs/integration/`: broader integration and concurrency coverage.
- `testbox/`: installed TestBox dependency. Project tests live under `tests/`, not under `testbox/`.
- `.github/workflows/`: GitHub Actions CI definitions.

## Mustache And CFML Notes

- Real Mustache templates use native section syntax such as `{{#people}}`.
- Inside `.cfc` and `.cfm` string literals, a literal `#` must be escaped as `##`, so native Mustache section syntax appears in source as `{{##people}}`.
- When changing rendering semantics, keep existing Mustache-oriented tests aligned with the official spec behavior.

## Local Workflow

- CommandBox is the recommended way to run examples, contribute changes, and execute tests.
- Install dependencies with `box install`.
- Start a local server with one of the root `server-*.json` files, for example: `box server start serverConfigFile="server-lucee@6.json"`
- The provided server configs listen on port `8520`.
- Once the server is running, examples are available from `/examples/` or `/examples/index.cfm`.
- `box.json` configures TestBox to use `http://localhost:8520/tests/runner.cfm`.

## Test Harness

- Tests are run with TestBox.
- The HTTP runner is `tests/runner.cfm`, which includes the TestBox HTML runner and defaults to the `tests.specs` package.
- Preferred CLI command: `box testbox run`
- Browser runner: `http://127.0.0.1:8520/tests/runner.cfm`
- For machine-readable output, the runner supports reporters such as `reporter=json`.
- New functionality, bug fixes, and behavior changes must include accompanying tests.
- Test should be written in BDD format.
- Put tests in the most specific suite that matches the change. If the change affects Mustache semantics, add or update the corresponding spec-oriented tests.

## CI Expectations

- CI runs through GitHub Actions workflows in `.github/workflows/`.
- The workflow starts CommandBox servers from the relevant `server-*.json` file and executes `box testbox run` across the engine matrix.
- Keep local validation aligned with the same server configs and commands when practical.

## Documentaion & Resources

### Mustache

- Spec: https://github.com/mustache/spec

### CommandBox

- Embedded Server: https://commandbox.ortusbooks.com/embedded-server
- TestBox Integration: https://commandbox.ortusbooks.com/testbox-integration

### TestBox

- Docs: https://testbox.ortusbooks.com/
