# Stubble

## Introduction

Stubble is a Mustache-inspired engine for rendering Mustache template syntax in CFML. It tokenizes templates, parses them into an AST, and renders against CFML data (view). When enabled, it also caches parsed templates in a thread-safe LRU cache.

### Why?

Why not? :D There have been a handful of Mustache options in the JVM world that can integrate with CFML applications (with some exceptions), but the goal was for a native implementation that aligns as close to complete with the syntax specs, and then build on top of it.

The real experiment was that a vast majority of this project is built using AI Agents in an effort to test the capabilities of building functional, yet efficient CFML tooling in an ever-changing AI ecosystem.

## Requirements

- Adobe ColdFusion 2023+
- Lucee 6+
- BoxLang 1+ (both CFML compat module and native)

> Older CFML engines may still work, providing they support the functionality leveraged, but this project targets supported runtimes.

## Supported Mustache Features

For a high-level overview of the syntax itself, see the [Mustache manual](https://mustache.github.io/mustache.5.html).

The initial implementation of Stubble has put a good amount of focus on the existing [Mustache spec](https://github.com/mustache/spec) which includes some of the following tag types/features:

- Variables (escaped and unescaped)
- Sections and inverted sections
- Dotted names
- Implicit iterator
- Partials
- Comments
- Alternate delimiters
- Lambdas
- Inheritance with blocks and parents


## Installation

Install the latest stable release from ForgeBox:

```bash
box install stubble
```

## Usage

Stubble supports being instantiated directly or used as a ColdBox module. The main API is the `render()` method which accepts a template string, view data, and optional partials.

### Direct CFC Instance

```cfml
<cfscript>
stubble = new models.Stubble();
template = "Hello {{name}}!";
view = { name: "World" };
result = stubble.render(template, view);
writeOutput(result); // Outputs: Hello World!
</cfscript>
```

### In A ColdBox App

#### From A Handler

```javascript
component {
  property name="stubble" inject="Stubble@stubble";

  any function index( event, rc, prc ) {
    // Renders "Hello ColdBox!"
    prc.greeting = variables.stubble.render(
      template = "Hello {{name}}!",
      view = { name : "ColdBox" }
    );
    event.setView( "main/index" );
  }
}
```

#### Using the Module Helper In A View

```cfml
<cfset template = "Hello {{name}}!">
<cfset view = { name: "ColdBox" }>
<!--- Outputs: Hello ColdBox! --->
<cfoutput>#renderMustache(template, view)#</cfoutput>
```

### Templates

Stubble renders template strings which contain any number of Mustache tags. File-based workflows read template and partial contents first and then pass those strings to `render()`.

```cfml
<cfscript>
template = fileRead( expandPath( "./examples/templates/releaseReport.mustache" ) );
partials = {
    projectCard: fileRead( expandPath( "./examples/templates/partials/projectCard.mustache" ) )
};
result = stubble.render( template, view, partials );
writeOutput( result );
</cfscript>
```

### Variables

View:

```javascript
{
  name: "Stubble",
  version: "1.0.0"
}
```

Template:

```mustache
{{name}} v{{version}}
```

Output:

```
Stubble v1.0.0
```

#### Dotted Names

View:

```javascript
{
  engines: [
    { name: "ColdFusion", org: "Adobe" },
    { name: "Lucee", org: "Lucee Association" },
    { name: "BoxLang", org: "Ortus Solutions" }
  ]
}
```

Template:

```mustache
{{#engines}}
  {{name}} by {{org}}
{{/engines}}
```

Output:

```
ColdFusion by Adobe
Lucee by Lucee Association
BoxLang by Ortus Solutions
```

### Sections

> A note on sections in CFML:
> - Native Mustache syntax in `.mustache` files works as expected.
> - Inside `.cfc` and `.cfm` string literals, a literal `#` must be escaped as `##`, so native Mustache section syntax appears in source as `{{##people}}`.

View:

```javascript
{
  engines: [
    { name: "ColdFusion" },
    { name: "Lucee" },
    { name: "BoxLang" }
  ]
}
```

Template:

```mustache
{{#engines}}
  {{name}}
{{/engines}}
```

Output:

```
ColdFusion
Lucee
BoxLang
```

#### Implicit Iterator

View:

```javascript
{
  engines: [
    "ColdFusion",
    "Lucee",
    "BoxLang"
  ]
}
```

Template:

```mustache
{{#engines}}
  {{.}}
{{/engines}}
```

Output:

```
ColdFusion
Lucee
BoxLang
```

### Lambdas

#### Function Expression

View:

```javascript
{
  greeting: "Hello",
  name: function() {
    return "World";
  }
}
```

Template:

```mustache
{{greeting}} {{name}}
```

Output:

```
Hello World
```

#### Arrow Function Expression

View:

```javascript
{
  calc: () => { return 2 * 4; }
}
```

Template:

```mustache
2 * 4 = {{calc}}
```

Output:

```
2 * 4 = 8
```

### Advanced Mustache Features

#### Alternate Delimiters

```mustache
{{=<% %>=}}(<%text%>)
```

#### Dynamic Partials

```mustache
{{>*currentPartial}}
```

Resolve `currentPartial` from the current context and render the matching partial from the `partials` struct.

#### Inheritance

```mustache
{{<layout}}
  {{$body}}Hello {{name}}{{/body}}
{{/layout}}
```

Use parent templates with block overrides to compose layouts while keeping rendering inside the current context.

## Examples

There are runnable examples included in the `examples/` directory that demonstrate various features of Stubble, including basic variable interpolation, sections, partials, lambdas, and file-based templates. You can access these examples by starting a local server pointed to the project root and navigating to `http://127.0.0.1:8520/examples/index.cfm`.

- `examples/index.cfm` lists the shipped demos.
- `examples/basic-demo.cfm` shows variables, sections, partials, lambdas, and cache stats.
- `examples/file-template-partial-demo.cfm` shows file-backed templates and partials with nested data.

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


## Testing

Tests are located in the `test-harness/tests/specs/` directory and are written with TestBox in a BDD style, covering both unit and integration scenarios for the standalone engine, official Mustache specs, and ColdBox module.

The recommended way to run tests is via CommandBox and the provided server configs (configured to run on port `8520`). Once dependencies have been installed and the server is running, navigate to `http://127.0.0.1:8520/tests/runner.cfm` or run `box testbox run`.

### Install Dependencies

```bash
box run-script install:dependencies
```

### Start From Server Config JSON

```bash
box server start serverConfigFile="server-lucee@7.json"
```

The following supported server configs are available in the root of the repository:

- `server-adobe@2023.json`
- `server-adobe@2025.json`
- `server-adobe@be.json`
- `server-lucee@6.json`
- `server-lucee@7.json`
- `server-lucee@be.json`
- `server-boxlang-cfml@1.json`
- `server-boxlang@1.json`
- `server-boxlang@be.json`

## Acknowledgments

Stubble was heavily based and inspired by the [vast Mustache ecosystem](https://mustache.github.io/) and the many developers who have made it all possible. Thanks!
