# Stubble

Stubble is a Mustache-inspired, template engine for CFML. It tokenizes templates, parses them into an AST, renders against CFML data. When enabled, it also caches parsed templates in a thread-safe LRU cache.

## Why?

Why not? :D There are a handful of Mustache options in the JVM world that can integrate with CFML applications, but the goal is for a native implementation that aligns with the syntax at its core initially, and then build on top of it.

The real experiment here is that a vast majority of this project is built using AI Agents in an effort to test the limits of building efficient, but functional, CFML tooling in an ever-changing AI ecosystem.

### A Word of Caution

> As is tradition with AI built projects, your mileage may vary, and this is an ongoing adventure to make good software with the assistance of AI models.

## High-Level

- Mustache compatibility is a primary goal.
- Supported runtimes are Adobe ColdFusion 2023+, Lucee 6+, and BoxLang 1+.
- Works with inline templates, `.mustache` files, nested partials, and advanced Mustache features.
- Includes cache controls and concurrency coverage for shared-instance rendering.

The test suite covers the core Mustache areas shipped in `tests/resources/mustache-specs/`, including interpolation, sections, inverted sections, comments, partials, alternate delimiters, lambdas, dynamic names, and inheritance.

> Older CFML engines are still likely to work, providing they support the syntax/functions leveraged, but this project aims to focus targeting supported runtimes.

## Feature Highlights

- Escaped variables: `{{name}}`
- Unescaped variables: `{{{html}}}` and `{{& html}}`
- Comments: `{{! comment }}`
- Partials from strings or functions
- Sections and inverted sections
- Current-context lookup: `{{.}}`
- Dotted names and numeric array indexes: `{{user.name}}`, `{{users.2.name}}`
- Parent-context fallback inside nested sections
- Alternate delimiters: `{{=<% %>=}}`
- Dynamic partial names: `{{>*partialName}}`
- Mustache inheritance with parents and blocks: `{{<layout}}`, `{{$body}}...{{/body}}`
- Variable and section lambdas
- Public cache controls: `configureCache()`, `clearCache()`, `getCacheStats()`

## Basic Usage

When working inside this repository, instantiate the component directly from `models`:

```cfml
<cfscript>
stubble = new models.Stubble();

output = stubble.render(
    "Hello {{name}}",
    { name: "Ada" }
);

writeOutput( output );
</cfscript>
```

## CFML Template Notes

Use native Mustache syntax in `.mustache` files:

```mustache
{{#people}}
- {{name}}
{{/people}}
```

Inside `.cfc` or `.cfm` string literals, CFML treats `#` as interpolation syntax. Escape Mustache section starts as `##` so CFML emits a literal `#`:

```cfml
template =
    "Users:" & chr(10) &
    "{{##people}}- {{name}}" & chr(10) &
    "{{/people}}";
```

That produces the same Mustache template as:

```mustache
Users:
{{#people}}- {{name}}
{{/people}}
```

## Rendering With Partials

```cfml
<cfscript>
stubble = new models.Stubble();

template =
    "Users:" & chr(10) &
    "{{##users}}{{> userRow}}{{/users}}";

data = {
    users: [
        { name: "Ada", email: "ada@example.com" },
        { name: "Linus", email: "linus@example.com" }
    ]
};

partials = {
    userRow: "- {{name}} <{{email}}>" & chr(10)
};

writeOutput( stubble.render( template, data, partials ) );
</cfscript>
```

Partial values can be plain strings or functions that return template text.

## Rendering File-Based Templates

Stubble renders strings, so file-based workflows read template and partial contents first and then pass those strings to `render()`.

```cfml
<cfscript>
stubble = new models.Stubble();

template = fileRead( expandPath( "./examples/templates/releaseReport.mustache" ) );

partials = {
    projectCard: fileRead( expandPath( "./examples/templates/partials/projectCard.mustache" ) )
};

result = stubble.render( template, data, partials );
writeOutput( result );
</cfscript>
```

See `examples/basic-demo.cfm`, `examples/file-template-partial-demo.cfm`, and `examples/index.cfm` for runnable examples.

## Advanced Mustache Features

### Alternate Delimiters

```mustache
{{=<% %>=}}(<%text%>)
```

### Dynamic Partials

```mustache
{{>*currentPartial}}
```

Resolve `currentPartial` from the current context and render the matching partial from the `partials` struct.

### Inheritance

```mustache
{{<layout}}
  {{$body}}Hello {{name}}{{/body}}
{{/layout}}
```

Use parent templates with block overrides to compose layouts while keeping rendering inside the current context.

## Public API

- `render( required string template, any data = {}, struct partials = {} )`
  Renders a template string against the supplied data and partial map.
- `tokenize( required string template, string openDelimiter = "{{", string closeDelimiter = "}}" )`
  Returns low-level tokens and supports custom starting delimiters.
- `parse( required array tokens, required string template )`
  Parses tokens into the AST used by the renderer.
- `configureCache( boolean enabled = true, numeric maxEntries = 200 )`
  Enables or disables the cache and sets the maximum LRU size. Values below `1` are normalized to `1`.
- `clearCache()`
  Removes all cached parsed templates.
- `getCacheStats()`
  Returns `enabled`, `maxEntries`, and `currentEntries`.

## Examples

- `examples/index.cfm` lists the shipped demos.
- `examples/basic-demo.cfm` shows variables, sections, partials, lambdas, and cache stats.
- `examples/file-template-partial-demo.cfm` shows file-backed templates and partials with nested data.

## Local Development And Tests

Install dependencies:

```bash
box install
```

Start a local server with one of the checked-in server configs. Example:

```bash
box server start serverConfigFile="server-lucee@6.json"
```

The root server configs cover the supported engine targets:

- `server-adobe@2023.json`
- `server-adobe@2025.json`
- `server-adobe@be.json`
- `server-lucee@6.json`
- `server-lucee@7.json`
- `server-lucee@be.json`
- `server-boxlang-cfml@1.json`

Once the server is running on port `8520`, open:

- Examples: `http://127.0.0.1:8520/examples/index.cfm`
- Test runner: `http://127.0.0.1:8520/tests/runner.cfm`
- JSON test output: `http://127.0.0.1:8520/tests/runner.cfm?reporter=json`

Run the CLI test suite with TestBox:

```bash
box testbox run
```

Project tests live under `tests/specs/` and use BDD-style TestBox specs.
