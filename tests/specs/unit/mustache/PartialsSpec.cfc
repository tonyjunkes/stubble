/**
 * Mustache partials compliance BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Mustache partials spec", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "Basic Behavior: The greater-than operator should expand to the named partial.", function(){
				var output = variables.stubble.render(
					'"{{>text}}"',
					{},
					{ text: "from partial" }
				);

				expect( output ).toBe( '"from partial"' );
			} );

			it( "Failed Lookup: The empty string should be used when the named partial is not found.", function(){
				var output = variables.stubble.render(
					'"{{>text}}"',
					{},
					{}
				);

				expect( output ).toBe( '""' );
			} );

			it( "Context: The greater-than operator should operate within the current context.", function(){
				var output = variables.stubble.render(
					'"{{>partial}}"',
					{ text: "content" },
					{ partial: "*{{text}}*" }
				);

				expect( output ).toBe( '"*content*"' );
			} );

			it( "Recursion: The greater-than operator should properly recurse.", function(){
				var output = variables.stubble.render(
					"{{>node}}",
					{
						content: "X",
						nodes: [
							{
								content: "Y",
								nodes: []
							}
						]
					},
					{ node: "{{content}}<{{$nodes}}{{>node}}{{/nodes}}>" }
				);

				expect( output ).toBe( "X<Y<>>" );
			} );

			it( "Nested: The greater-than operator should work from within partials.", function(){
				var output = variables.stubble.render(
					"{{>outer}}",
					{ a: "hello", b: "world" },
					{
						outer: "*{{a}} {{>inner}}*",
						inner: "{{b}}!"
					}
				);

				expect( output ).toBe( "*hello world!*" );
			} );

			it( "Surrounding Whitespace: The greater-than operator should not alter surrounding whitespace.", function(){
				var output = variables.stubble.render(
					"| {{>partial}} |",
					{},
					{ partial: chr( 9 ) & "|" & chr( 9 ) }
				);

				expect( output ).toBe( "| " & chr( 9 ) & "|" & chr( 9 ) & " |" );
			} );

			it( "Inline Indentation: Whitespace should be left untouched.", function(){
				var output = variables.stubble.render(
					"  {{data}}  {{> partial}}" & chr( 10 ),
					{ data: "|" },
					{ partial: ">" & chr( 10 ) & ">" }
				);

				expect( output ).toBe( "  |  >" & chr( 10 ) & ">" & chr( 10 ) );
			} );

			it( 'Standalone Line Endings: "\r\n" should be considered a newline for standalone tags.', function(){
				var output = variables.stubble.render(
					"|" & chr( 13 ) & chr( 10 ) & "{{>partial}}" & chr( 13 ) & chr( 10 ) & "|",
					{},
					{ partial: ">" }
				);

				expect( output ).toBe( "|" & chr( 13 ) & chr( 10 ) & ">|" );
			} );

			it( "Standalone Without Previous Line: Standalone tags should not require a newline to precede them.", function(){
				var output = variables.stubble.render(
					"  {{>partial}}" & chr( 10 ) & ">",
					{},
					{ partial: ">" & chr( 10 ) & ">" }
				);

				expect( output ).toBe( "  >" & chr( 10 ) & "  >>" );
			} );

			it( "Standalone Without Newline: Standalone tags should not require a newline to follow them.", function(){
				var output = variables.stubble.render(
					">" & chr( 10 ) & "  {{>partial}}",
					{},
					{ partial: ">" & chr( 10 ) & ">" }
				);

				expect( output ).toBe( ">" & chr( 10 ) & "  >" & chr( 10 ) & "  >" );
			} );

			it( "Standalone Indentation: Each line of the partial should be indented before rendering.", function(){
				var output = variables.stubble.render(
					chr( 92 ) & chr( 10 ) & " {{>partial}}" & chr( 10 ) & "/" & chr( 10 ),
					{ content: "<" & chr( 10 ) & "->" },
					{ partial: "|" & chr( 10 ) & "{{{content}}}" & chr( 10 ) & "|" & chr( 10 ) }
				);

				expect( output ).toBe( chr( 92 ) & chr( 10 ) & " |" & chr( 10 ) & " <" & chr( 10 ) & "->" & chr( 10 ) & " |" & chr( 10 ) & "/" & chr( 10 ) );
			} );

			it( "Padding Whitespace: Superfluous in-tag whitespace should be ignored.", function(){
				var output = variables.stubble.render(
					"|{{> partial }}|",
					{ boolean: true },
					{ partial: "[]" }
				);

				expect( output ).toBe( "|[]|" );
			} );
		} );
	}
}
