/**
 * Mustache dynamic names compliance BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Mustache dynamic names spec", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "Basic Behavior - Partial: The asterisk operator is used for dynamic partials.", function(){
				var output = variables.stubble.render(
					'"{{>*dynamic}}"',
					{ dynamic: "content" },
					{ content: "Hello, world!" }
				);

				expect( output ).toBe( '"Hello, world!"' );
			} );

			it( "Basic Behavior - Name Resolution: The asterisk is not part of the name that will be resolved in the context.", function(){
				var output = variables.stubble.render(
					'"{{>*dynamic}}"',
					{
						dynamic: "content",
						"*dynamic": "wrong"
					},
					{
						content: "Hello, world!",
						wrong: "Invisible"
					}
				);

				expect( output ).toBe( '"Hello, world!"' );
			} );

			it( "Context Misses - Partial: Failed context lookups should be considered falsey.", function(){
				var output = variables.stubble.render(
					'"{{>*missing}}"',
					{},
					{ missing: "Hello, world!" }
				);

				expect( output ).toBe( '""' );
			} );

			it( "Failed Lookup - Partial: The empty string should be used when the named partial is not found.", function(){
				var output = variables.stubble.render(
					'"{{>*dynamic}}"',
					{ dynamic: "content" },
					{ foobar: "Hello, world!" }
				);

				expect( output ).toBe( '""' );
			} );

			it( "Context: The dynamic partial should operate within the current context.", function(){
				var output = variables.stubble.render(
					'"{{>*example}}"',
					{
						text: "Hello, world!",
						example: "partial"
					},
					{ partial: "*{{text}}*" }
				);

				expect( output ).toBe( '"*Hello, world!*"' );
			} );

			it( "Dotted Names: The dynamic partial should operate within the current context.", function(){
				var output = variables.stubble.render(
					'"{{>*foo.bar.baz}}"',
					{
						text: "Hello, world!",
						foo: { bar: { baz: "partial" } }
					},
					{ partial: "*{{text}}*" }
				);

				expect( output ).toBe( '"*Hello, world!*"' );
			} );

			it( "Dotted Names - Operator Precedence: The dotted name should be resolved entirely before being dereferenced.", function(){
				var output = variables.stubble.render(
					'"{{>*foo.bar.baz}}"',
					{
						text: "Hello, world!",
						foo: "test",
						test: { bar: { baz: "partial" } }
					},
					{ partial: "*{{text}}*" }
				);

				expect( output ).toBe( '""' );
			} );

			it( "Dotted Names - Failed Lookup: The dynamic partial should operate within the current context.", function(){
				var output = variables.stubble.render(
					'"{{>*foo.bar.baz}}"',
					{
						foo: {
							text: "Hello, world!",
							bar: { baz: "partial" }
						}
					},
					{ partial: "*{{text}}*" }
				);

				expect( output ).toBe( '"**"' );
			} );

			it( "Dotted names - Context Stacking: Dotted names should not push a new frame on the context stack.", function(){
				var output = variables.stubble.render(
					"{{##section1}}{{>*section2.dynamic}}{{/section1}}",
					{
						section1: { value: "section1" },
						section2: {
							dynamic: "partial",
							value: "section2"
						}
					},
					{ partial: '"{{value}}"' }
				);

				expect( output ).toBe( '"section1"' );
			} );

			it( "Dotted names - Context Stacking Under Repetition: Dotted names should not push a new frame on the context stack.", function(){
				var output = variables.stubble.render(
					"{{##section1}}{{>*section2.dynamic}}{{/section1}}",
					{
						value: "test",
						section1: [ 1, 2 ],
						section2: {
							dynamic: "partial",
							value: "section2"
						}
					},
					{ partial: "{{value}}" }
				);

				expect( output ).toBe( "testtest" );
			} );

			it( "Dotted names - Context Stacking Failed Lookup: Dotted names should resolve against the proper context stack.", function(){
				var output = variables.stubble.render(
					"{{##section1}}{{>*section2.dynamic}}{{/section1}}",
					{
						section1: [ 1, 2 ],
						section2: {
							dynamic: "partial",
							value: "section2"
						}
					},
					{ partial: '"{{value}}"' }
				);

				expect( output ).toBe( '""""' );
			} );

			it( "Recursion: Dynamic partials should properly recurse.", function(){
				var output = variables.stubble.render(
					"{{>*template}}",
					{
						template: "node",
						content: "X",
						nodes: [
							{
								content: "Y",
								nodes: []
							}
						]
					},
					{ node: "{{content}}<{{##nodes}}{{>*template}}{{/nodes}}>" }
				);

				expect( output ).toBe( "X<Y<>>" );
			} );

			it( "Dynamic Names - Double Dereferencing: Dynamic Names can't be dereferenced more than once.", function(){
				var output = variables.stubble.render(
					'"{{>**dynamic}}"',
					{
						dynamic: "test",
						test: "content"
					},
					{ content: "Hello, world!" }
				);

				expect( output ).toBe( '""' );
			} );

			it( "Dynamic Names - Composed Dereferencing: Dotted Names are resolved entirely before dereferencing begins.", function(){
				var output = variables.stubble.render(
					'"{{>*foo.*bar}}"',
					{
						foo: "fizz",
						bar: "buzz",
						fizz: {
							buzz: {
								content: javaCast( "null", "" )
							}
						}
					},
					{ content: "Hello, world!" }
				);

				expect( output ).toBe( '""' );
			} );

			it( "Surrounding Whitespace: A dynamic partial should not alter surrounding whitespace; any whitespace preceding the tag should be treated as indentation while any whitespace succeeding the tag should be left untouched.", function(){
				var output = variables.stubble.render(
					"| {{>*partial}} |",
					{ partial: "foobar" },
					{ foobar: chr( 9 ) & "|" & chr( 9 ) }
				);

				expect( output ).toBe( "| " & chr( 9 ) & "|" & chr( 9 ) & " |" );
			} );

			it( "Inline Indentation: Whitespace should be left untouched: whitespaces preceding the tag should be treated as indentation.", function(){
				var output = variables.stubble.render(
					"  {{data}}  {{>*dynamic}}" & chr( 10 ),
					{
						dynamic: "partial",
						data: "|"
					},
					{ partial: ">" & chr( 10 ) & ">" }
				);

				expect( output ).toBe( "  |  >" & chr( 10 ) & ">" & chr( 10 ) );
			} );

			it( 'Standalone Line Endings: "\r\n" should be considered a newline for standalone tags.', function(){
				var output = variables.stubble.render(
					"|" & chr( 13 ) & chr( 10 ) & "{{>*dynamic}}" & chr( 13 ) & chr( 10 ) & "|",
					{ dynamic: "partial" },
					{ partial: ">" }
				);

				expect( output ).toBe( "|" & chr( 13 ) & chr( 10 ) & ">|" );
			} );

			it( "Standalone Without Previous Line: Standalone tags should not require a newline to precede them.", function(){
				var output = variables.stubble.render(
					"  {{>*dynamic}}" & chr( 10 ) & ">",
					{ dynamic: "partial" },
					{ partial: ">" & chr( 10 ) & ">" }
				);

				expect( output ).toBe( "  >" & chr( 10 ) & "  >>" );
			} );

			it( "Standalone Without Newline: Standalone tags should not require a newline to follow them.", function(){
				var output = variables.stubble.render(
					">" & chr( 10 ) & "  {{>*dynamic}}",
					{ dynamic: "partial" },
					{ partial: ">" & chr( 10 ) & ">" }
				);

				expect( output ).toBe( ">" & chr( 10 ) & "  >" & chr( 10 ) & "  >" );
			} );

			it( "Standalone Indentation: Each line of the partial should be indented before rendering.", function(){
				var output = variables.stubble.render(
					chr( 92 ) & chr( 10 ) & " {{>*dynamic}}" & chr( 10 ) & "/" & chr( 10 ),
					{
						dynamic: "partial",
						content: "<" & chr( 10 ) & "->"
					},
					{ partial: "|" & chr( 10 ) & "{{{content}}}" & chr( 10 ) & "|" & chr( 10 ) }
				);

				expect( output ).toBe( chr( 92 ) & chr( 10 ) & " |" & chr( 10 ) & " <" & chr( 10 ) & "->" & chr( 10 ) & " |" & chr( 10 ) & "/" & chr( 10 ) );
			} );

			it( "Padding Whitespace: Superfluous in-tag whitespace should be ignored.", function(){
				var output = variables.stubble.render(
					"|{{> * dynamic }}|",
					{
						dynamic: "partial",
						boolean: true
					},
					{ partial: "[]" }
				);

				expect( output ).toBe( "|[]|" );
			} );
		} );
	}
}
