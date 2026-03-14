/**
 * Mustache inverted sections compliance BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Mustache inverted sections spec", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "Falsey: Falsey sections should have their contents rendered.", function(){
				var output = variables.stubble.render(
					'"{{^boolean}}This should be rendered.{{/boolean}}"',
					{ boolean: false }
				);

				expect( output ).toBe( '"This should be rendered."' );
			} );

			it( "Truthy: Truthy sections should have their contents omitted.", function(){
				var output = variables.stubble.render(
					'"{{^boolean}}This should not be rendered.{{/boolean}}"',
					{ boolean: true }
				);

				expect( output ).toBe( '""' );
			} );

			it( "Null is falsey: Null is falsey.", function(){
				var output = variables.stubble.render(
					'"{{^null}}This should be rendered.{{/null}}"',
					{ null: javaCast( "null", "" ) }
				);

				expect( output ).toBe( '"This should be rendered."' );
			} );

			it( "Context: Objects and hashes should behave like truthy values.", function(){
				var output = variables.stubble.render(
					'"{{^context}}Hi {{name}}.{{/context}}"',
					{ context: { name: "Joe" } }
				);

				expect( output ).toBe( '""' );
			} );

			it( "List: Lists should behave like truthy values.", function(){
				var output = variables.stubble.render(
					'"{{^list}}{{n}}{{/list}}"',
					{
						list: [
							{ n: 1 },
							{ n: 2 },
							{ n: 3 }
						]
					}
				);

				expect( output ).toBe( '""' );
			} );

			it( "Empty List: Empty lists should behave like falsey values.", function(){
				var output = variables.stubble.render(
					'"{{^list}}Yay lists!{{/list}}"',
					{ list: [] }
				);

				expect( output ).toBe( '"Yay lists!"' );
			} );

			it( "Doubled: Multiple inverted sections per template should be permitted.", function(){
				var template = "{{^bool}}" & chr( 10 ) & "* first" & chr( 10 ) & "{{/bool}}" & chr( 10 ) & "* {{two}}" & chr( 10 ) & "{{^bool}}" & chr( 10 ) & "* third" & chr( 10 ) & "{{/bool}}" & chr( 10 );
				var expected = "* first" & chr( 10 ) & "* second" & chr( 10 ) & "* third" & chr( 10 );

				var output = variables.stubble.render(
					template,
					{ bool: false, two: "second" }
				);

				expect( output ).toBe( expected );
			} );

			it( "Nested (Falsey): Nested falsey sections should have their contents rendered.", function(){
				var output = variables.stubble.render(
					"| A {{^bool}}B {{^bool}}C{{/bool}} D{{/bool}} E |",
					{ bool: false }
				);

				expect( output ).toBe( "| A B C D E |" );
			} );

			it( "Nested (Truthy): Nested truthy sections should be omitted.", function(){
				var output = variables.stubble.render(
					"| A {{^bool}}B {{^bool}}C{{/bool}} D{{/bool}} E |",
					{ bool: true }
				);

				expect( output ).toBe( "| A  E |" );
			} );

			it( "Context Misses: Failed context lookups should be considered falsey.", function(){
				var output = variables.stubble.render(
					"[{{^missing}}Cannot find key 'missing'!{{/missing}}]",
					{}
				);

				expect( output ).toBe( "[Cannot find key 'missing'!]" );
			} );

			it( "Dotted Names - Truthy: Dotted names should be valid for Inverted Section tags.", function(){
				var output = variables.stubble.render(
					'"{{^a.b.c}}Not Here{{/a.b.c}}" == ""',
					{ a: { b: { c: true } } }
				);

				expect( output ).toBe( '"" == ""' );
			} );

			it( "Dotted Names - Falsey: Dotted names should be valid for Inverted Section tags.", function(){
				var output = variables.stubble.render(
					'"{{^a.b.c}}Not Here{{/a.b.c}}" == "Not Here"',
					{ a: { b: { c: false } } }
				);

				expect( output ).toBe( '"Not Here" == "Not Here"' );
			} );

			it( "Dotted Names - Broken Chains: Dotted names that cannot be resolved should be considered falsey.", function(){
				var output = variables.stubble.render(
					'"{{^a.b.c}}Not Here{{/a.b.c}}" == "Not Here"',
					{ a: {} }
				);

				expect( output ).toBe( '"Not Here" == "Not Here"' );
			} );

			it( "Surrounding Whitespace: Inverted sections should not alter surrounding whitespace.", function(){
				var output = variables.stubble.render(
					" | {{^boolean}}" & chr( 9 ) & "|" & chr( 9 ) & "{{/boolean}} | " & chr( 10 ),
					{ boolean: false }
				);

				expect( output ).toBe( " | " & chr( 9 ) & "|" & chr( 9 ) & " | " & chr( 10 ) );
			} );

			it( "Internal Whitespace: Inverted should not alter internal whitespace.", function(){
				var output = variables.stubble.render(
					" | {{^boolean}} {{! Important Whitespace }}" & chr( 10 ) & " {{/boolean}} | " & chr( 10 ),
					{ boolean: false }
				);

				expect( output ).toBe( " |  " & chr( 10 ) & "  | " & chr( 10 ) );
			} );

			it( "Indented Inline Sections: Single-line sections should not alter surrounding whitespace.", function(){
				var output = variables.stubble.render(
					" {{^boolean}}NO{{/boolean}}" & chr( 10 ) & " {{^boolean}}WAY{{/boolean}}" & chr( 10 ),
					{ boolean: false }
				);

				expect( output ).toBe( " NO" & chr( 10 ) & " WAY" & chr( 10 ) );
			} );

			it( "Standalone Lines: Standalone lines should be removed from the template.", function(){
				var output = variables.stubble.render(
					"| This Is" & chr( 10 ) & "{{^boolean}}" & chr( 10 ) & "|" & chr( 10 ) & "{{/boolean}}" & chr( 10 ) & "| A Line" & chr( 10 ),
					{ boolean: false }
				);

				expect( output ).toBe( "| This Is" & chr( 10 ) & "|" & chr( 10 ) & "| A Line" & chr( 10 ) );
			} );

			it( "Standalone Indented Lines: Standalone indented lines should be removed from the template.", function(){
				var output = variables.stubble.render(
					"| This Is" & chr( 10 ) & "  {{^boolean}}" & chr( 10 ) & "|" & chr( 10 ) & "  {{/boolean}}" & chr( 10 ) & "| A Line" & chr( 10 ),
					{ boolean: false }
				);

				expect( output ).toBe( "| This Is" & chr( 10 ) & "|" & chr( 10 ) & "| A Line" & chr( 10 ) );
			} );

			it( 'Standalone Line Endings: "\r\n" should be considered a newline for standalone tags.', function(){
				var output = variables.stubble.render(
					"|" & chr( 13 ) & chr( 10 ) & "{{^boolean}}" & chr( 13 ) & chr( 10 ) & "{{/boolean}}" & chr( 13 ) & chr( 10 ) & "|",
					{ boolean: false }
				);

				expect( output ).toBe( "|" & chr( 13 ) & chr( 10 ) & "|" );
			} );

			it( "Standalone Without Previous Line: Standalone tags should not require a newline to precede them.", function(){
				var output = variables.stubble.render(
					"  {{^boolean}}" & chr( 10 ) & "^{{/boolean}}" & chr( 10 ) & "/",
					{ boolean: false }
				);

				expect( output ).toBe( "^" & chr( 10 ) & "/" );
			} );

			it( "Standalone Without Newline: Standalone tags should not require a newline to follow them.", function(){
				var output = variables.stubble.render(
					"^{{^boolean}}" & chr( 10 ) & "/" & chr( 10 ) & "  {{/boolean}}",
					{ boolean: false }
				);

				expect( output ).toBe( "^" & chr( 10 ) & "/" & chr( 10 ) );
			} );

			it( "Padding: Superfluous in-tag whitespace should be ignored.", function(){
				var output = variables.stubble.render(
					"|{{^ boolean }}={{/ boolean }}|",
					{ boolean: false }
				);

				expect( output ).toBe( "|=|" );
			} );
		} );
	}
}
