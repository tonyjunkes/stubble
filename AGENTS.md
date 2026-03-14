# AGENTS.md

## Scope

This file applies to the entire repository.

## Project

Stubble is a Mustache-inspired template engine for CFML. It can be used as a standalone library or installed as a ColdBox module.

The implementation is split across several components in `models/`. `Stubble.cfc` is the main orchestrator that delegates tokenization, parsing, and caching to dedicated CFCs.

This repository aims to support the official Mustache spec.

Treat spec compatibility as a primary concern when changing parsing or rendering behavior.

## Compatibility Targets

- Keep changes CFML engine agnostic.
- Supported targets are Adobe ColdFusion 2023+, Adobe ColdFusion 2025+, Lucee 6+, Lucee 7+, and BoxLang 1+.
- Root `server-*.json` files define the CommandBox server options used for each engine target.
- CI also exercises bleeding-edge Adobe and Lucee builds as experimental targets.
- Prefer portable CFML constructs. If an engine-specific workaround is required, isolate it and cover it with tests.

## Repository Layout

- `models/Stubble.cfc`: main orchestrator — render pipeline, context lookup, lambda support, HTML escaping. Marked as a singleton.
- `models/Tokenizer.cfc`: stateless scanner that converts a template string into an array of tokens.
- `models/Parser.cfc`: stateless builder that converts a token array into an AST node tree. Handles nesting validation, block/parent inheritance, and standalone whitespace.
- `models/TemplateCache.cfc`: thread-safe LRU cache for parsed ASTs. Uses exclusive locks for concurrent access.
- `models/StringUtil.cfc`: static utility methods for line break detection, indentation analysis, and whitespace normalization.
- `ModuleConfig.cfc`: ColdBox module descriptor. Registers WireBox mappings, a global helper, and cache settings.
- `helpers/StubbleHelper.cfm`: global `renderMustache()` convenience function available in ColdBox applications when the module is loaded.
- `examples/`: runnable demos, including `examples/index.cfm` and supporting templates under `examples/templates/`.
- `test-harness/`: embedded ColdBox app and executable test harness used to run the base Stubble suites alongside ColdBox module tests.
- `test-harness/tests/`: TestBox runner, browser UI, specs, fixtures, and test resources.
- `test-harness/tests/specs/unit/`: component-level tests for Tokenizer, Parser, Render, FileTemplate, TemplateCache, and StringUtil.
- `test-harness/tests/specs/unit/mustache/`: Mustache spec compliance suites — interpolation, sections, inverted, partials, lambdas, comments, delimiters, inheritance, and dynamic names.
- `test-harness/tests/specs/integration/`: broader integration and concurrency coverage for the standalone engine.
- `test-harness/tests/specs/ModuleSpec.cfc`: ColdBox module bootstrap and integration coverage exercised through the harness app.
- `test-harness/tests/resources/`: test fixtures including instrumented subclasses (`InstrumentedStubble.cfc`, `InstrumentedParser.cfc`), CFC fixtures (`DynamicLookupFixture.cfc`), and `.mustache` template files.
- `test-harness/testbox/`: installed TestBox dependency for the harness. Project tests live under `test-harness/tests/`, not under `test-harness/testbox/`.
- `.github/workflows/`: GitHub Actions CI definitions.

## Architecture

The render pipeline flows through several components:

1. `Stubble.render()` receives a template string, data, and optional partials.
2. `TemplateCache.getOrSet()` checks for a cached AST. On a miss it invokes the parse function.
3. `Tokenizer.tokenize()` scans the template string into tokens.
4. `Parser.parse()` builds an AST from the tokens.
5. `Stubble._renderNodes()` walks the AST, resolving context via `_lookup()` and recursing into sections, blocks, and partials.

Tokenizer, Parser, and StringUtil are stateless and inherently thread-safe. TemplateCache uses exclusive locks. Stubble itself is a singleton.

`Stubble.init()` accepts optional `Tokenizer`, `Parser`, and `TemplateCache` arguments. When omitted, default instances are created internally. This allows WireBox injection in ColdBox apps and mock injection in tests.

When making changes, match the concern to the component: token recognition belongs in Tokenizer, AST structure in Parser, rendering logic in Stubble, and cache behavior in TemplateCache.

## ColdBox Module Usage

- Stubble is packaged as a ColdBox module (`type: modules` in `box.json`).
- `ModuleConfig.cfc` enables `autoMapModels`, so all CFCs in `models/` are automatically registered with WireBox.
- `Stubble` is a singleton, accessible as `Stubble@stubble` via `getInstance()` or property injection.
- Module settings expose `cacheEnabled` and `cacheMaxEntries`. These are applied during `onLoad()` and the cache is cleared during `onUnload()`.
- `helpers/StubbleHelper.cfm` registers a global `renderMustache(template, data, partials)` function available throughout the ColdBox application.
- For standalone (non-ColdBox) usage, instantiate directly: `new models.Stubble()`.

## Mustache And CFML Notes

- Real Mustache templates use native section syntax such as `{{#people}}`.
- Inside `.cfc` and `.cfm` string literals, a literal `#` must be escaped as `##`, so native Mustache section syntax appears in source as `{{##people}}`.
- When changing rendering semantics, keep existing Mustache-oriented tests aligned with the official spec behavior.

## Local Workflow

- CommandBox is the recommended way to run examples, contribute changes, and execute tests.
- Install dependencies with `box run-script install:dependencies` or run `box install` in both the repository root and `test-harness/`.
- Start a local server with one of the root `server-*.json` files, for example: `box server start serverConfigFile="server-lucee@6.json"`
- The provided server configs listen on port `8520`.
- The server configs use `test-harness` as the webroot, and the root `box.json` points TestBox at `http://localhost:8520/tests/runner.cfm` for the combined standalone and ColdBox module suites.

## Test Harness

- Tests are run with TestBox through the ColdBox harness in `test-harness/`.
- The HTTP runner file is `test-harness/tests/runner.cfm`, which includes the TestBox HTML runner and defaults to the `tests.specs` package.
- Because the server webroot is `test-harness`, the runner is exposed at `http://127.0.0.1:8520/tests/runner.cfm`.
- Preferred CLI command: `box testbox run`
- Browser runner: `http://127.0.0.1:8520/tests/runner.cfm`
- For machine-readable output, the runner supports reporters such as `reporter=json`.
- New functionality, bug fixes, and behavior changes must include accompanying tests.
- Tests should be written in BDD format.
- Component-level tests (Tokenizer, Parser, TemplateCache, StringUtil, Render, FileTemplate) belong in `test-harness/tests/specs/unit/`.
- Mustache spec compliance tests belong in `test-harness/tests/specs/unit/mustache/`. Each file maps to a section of the official spec (interpolation, sections, inverted, partials, lambdas, comments, delimiters, inheritance, dynamic names).
- Integration and concurrency tests belong in `test-harness/tests/specs/integration/`.
- ColdBox module wiring and helper behavior should be covered through harness-driven specs such as `test-harness/tests/specs/ModuleSpec.cfc`.
- Test fixtures live in `test-harness/tests/resources/`. `InstrumentedStubble.cfc` and `InstrumentedParser.cfc` track parse invocations for cache verification.
- Put tests in the most specific suite that matches the change. If the change affects Mustache semantics, add or update the corresponding spec-oriented tests in `test-harness/tests/specs/unit/mustache/`.

## CI Expectations

- CI runs through GitHub Actions workflows in `.github/workflows/`.
- The workflow starts CommandBox servers from the relevant `server-*.json` file, serves `test-harness` as the webroot, and executes `box testbox run` against the combined standalone and ColdBox module suites across the engine matrix.
- Stable engine matrix: `lucee@6`, `lucee@7`, `adobe@2023`, `adobe@2025`, `boxlang-cfml@1`.
- Experimental engines (continue-on-error): `lucee@be`, `adobe@be`.
- CI requires Java 21.
- Keep local validation aligned with the same server configs and commands when practical.

## Documentation & Resources

### Mustache

- Spec: https://github.com/mustache/spec

### CommandBox

- Embedded Server: https://commandbox.ortusbooks.com/embedded-server
- TestBox Integration: https://commandbox.ortusbooks.com/testbox-integration

### TestBox

- Docs: https://testbox.ortusbooks.com/
