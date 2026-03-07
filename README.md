# Stubble

A Mustache-inspired template engine for CFML.

## What It Is

Stubble is a renderer that:

- Tokenizes template text (`tokenize()`)
- Parses tokens into an AST (`parse()`)
- Renders templates against data (`render()`)
- Caches parsed templates with a thread-safe LRU cache

## What It Does

Stubble lets you render dynamic templates using familiar Mustache-style tags.

```cfml
<cfscript>
stubble = new Stubble();

output = stubble.render(
    "Hello {{name}}",
    { name: "Ada" }
);

writeOutput( output ); // Hello Ada
</cfscript>
```

## Features

- Escaped variables: `{{name}}`
- Unescaped variables: `{{{html}}}` and `{{& html}}`
- Comments: `{{! comment }}`
- Partials: `{{> partialName}}`
- Sections: `{{#items}} ... {{/items}}`
- Inverted sections: `{{^items}} ... {{/items}}`
- Dotted path lookup: `{{user.name}}`
- Numeric array index lookup: `{{users.2.name}}`
- Current context lookup: `{{.}}`
- Parent context fallback inside nested sections
- Lambda support for variable and section tags (arity 0/1/2)
- Public cache controls:
  - `configureCache( enabled=true, maxEntries=200 )`
  - `clearCache()`
  - `getCacheStats()`
- Concurrency-tested rendering and cache behavior

## Template Notes

Stubble now uses native Mustache `{{#name}}` section starts.

When writing templates inside `.cfc` or `.cfm` string literals, escape the section sigil as `##` so CFML emits a literal `#`.

```mustache
{{#people}}
- {{name}}
{{/people}}
```

```cfml
template = "Users:\n{{##users}}- {{name}} <{{email}}>\n{{/users}}";
```

## Quick Usage

```cfml
<cfscript>
stubble = new Stubble();

template = "Users:\n{{##users}}- {{name}} <{{email}}>\n{{/users}}";

data = {
    users: [
        { name: "Ada", email: "ada@example.com" },
        { name: "Linus", email: "linus@example.com" }
    ]
};

result = stubble.render( template, data );
writeOutput( result );
</cfscript>
```

## Public API

- `render( required string template, any data = {}, struct partials = {} )`
  - Main entry point for rendering output.
- `tokenize( required string template )`
  - Returns low-level token structures.
- `parse( required array tokens, required string template )`
  - Parses tokens into an AST.
- `configureCache( boolean enabled = true, numeric maxEntries = 200 )`
  - Enables/disables caching and sets max cache size.
- `clearCache()`
  - Clears all cached parsed templates.
- `getCacheStats()`
  - Returns cache metadata: enabled, maxEntries, currentEntries.

## Running Tests With TestBox

> Test cases cover the [Mustache spec](https://github.com/mustache/spec) as of 3/2026

The test suite lives under `tests/specs/` and uses TestBox and can be executed from the CLI via CommandBox or browser.

### 1. Install Dependencies

```bash
box install
```

### 2. Start the Local Server

```bash
box server start
```

By default, `server.json` sets the server to Lucee on port `8520`.

### 3. Run Tests

```bash
box testbox run
```

Browser:

- `http://127.0.0.1:8520/tests/runner.cfm`
