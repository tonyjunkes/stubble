/**
 * Mustache sections compliance BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Mustache sections spec", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "Truthy: Truthy sections should have their contents rendered.", function(){
				var output = variables.stubble.render(
					'"{{##boolean}}This should be rendered.{{/boolean}}"',
					{ boolean: true }
				);

				expect( output ).toBe( '"This should be rendered."' );
			} );

			it( "Falsey: Falsey sections should have their contents omitted.", function(){
				var output = variables.stubble.render(
					'"{{##boolean}}This should not be rendered.{{/boolean}}"',
					{ boolean: false }
				);

				expect( output ).toBe( '""' );
			} );

			it( "Null is falsey: Null is falsey.", function(){
				var output = variables.stubble.render(
					'"{{##null}}This should not be rendered.{{/null}}"',
					{ null: javaCast( "null", "" ) }
				);

				expect( output ).toBe( '""' );
			} );

			it( "Context: Objects and hashes should be pushed onto the context stack.", function(){
				var output = variables.stubble.render(
					'"{{##context}}Hi {{name}}.{{/context}}"',
					{ context: { name: "Joe" } }
				);

				expect( output ).toBe( '"Hi Joe."' );
			} );

			it( "Parent contexts: Names missing in the current context are looked up in the stack.", function(){
				var output = variables.stubble.render(
					'"{{##sec}}{{a}}, {{b}}, {{c.d}}{{/sec}}"',
					{
						a: "foo",
						b: "wrong",
						sec: { b: "bar" },
						c: { d: "baz" }
					}
				);

				expect( output ).toBe( '"foo, bar, baz"' );
			} );

			it( "Variable test: Non-false sections have their value at the top of context, accessible as {{.}} or through the parent context. This gives a simple way to display content conditionally if a variable exists.", function(){
				var output = variables.stubble.render(
					'"{{##foo}}{{.}} is {{foo}}{{/foo}}"',
					{ foo: "bar" }
				);

				expect( output ).toBe( '"bar is bar"' );
			} );

			it( "List Contexts: All elements on the context stack should be accessible within lists.", function(){
				var output = variables.stubble.render(
					"{{##tops}}{{##middles}}{{tname.lower}}{{mname}}.{{##bottoms}}{{tname.upper}}{{mname}}{{bname}}.{{/bottoms}}{{/middles}}{{/tops}}",
					{
						tops: [
							{
								tname: { upper: "A", lower: "a" },
								middles: [
									{
										mname: "1",
										bottoms: [
											{ bname: "x" },
											{ bname: "y" }
										]
									}
								]
							}
						]
					}
				);

				expect( output ).toBe( "a1.A1x.A1y." );
			} );

			it( "Deeply Nested Contexts: All elements on the context stack should be accessible.", function(){
				var template = "{{##a}}" & chr( 10 ) &
					"{{one}}" & chr( 10 ) &
					"{{##b}}" & chr( 10 ) &
					"{{one}}{{two}}{{one}}" & chr( 10 ) &
					"{{##c}}" & chr( 10 ) &
					"{{one}}{{two}}{{three}}{{two}}{{one}}" & chr( 10 ) &
					"{{##d}}" & chr( 10 ) &
					"{{one}}{{two}}{{three}}{{four}}{{three}}{{two}}{{one}}" & chr( 10 ) &
					"{{##five}}" & chr( 10 ) &
					"{{one}}{{two}}{{three}}{{four}}{{five}}{{four}}{{three}}{{two}}{{one}}" & chr( 10 ) &
					"{{one}}{{two}}{{three}}{{four}}{{.}}6{{.}}{{four}}{{three}}{{two}}{{one}}" & chr( 10 ) &
					"{{one}}{{two}}{{three}}{{four}}{{five}}{{four}}{{three}}{{two}}{{one}}" & chr( 10 ) &
					"{{/five}}" & chr( 10 ) &
					"{{one}}{{two}}{{three}}{{four}}{{three}}{{two}}{{one}}" & chr( 10 ) &
					"{{/d}}" & chr( 10 ) &
					"{{one}}{{two}}{{three}}{{two}}{{one}}" & chr( 10 ) &
					"{{/c}}" & chr( 10 ) &
					"{{one}}{{two}}{{one}}" & chr( 10 ) &
					"{{/b}}" & chr( 10 ) &
					"{{one}}" & chr( 10 ) &
					"{{/a}}" & chr( 10 );

				var expected = "1" & chr( 10 ) &
					"121" & chr( 10 ) &
					"12321" & chr( 10 ) &
					"1234321" & chr( 10 ) &
					"123454321" & chr( 10 ) &
					"12345654321" & chr( 10 ) &
					"123454321" & chr( 10 ) &
					"1234321" & chr( 10 ) &
					"12321" & chr( 10 ) &
					"121" & chr( 10 ) &
					"1" & chr( 10 );

				var output = variables.stubble.render(
					template,
					{
						a: { one: 1 },
						b: { two: 2 },
						c: {
							three: 3,
							d: {
								four: 4,
								five: 5
							}
						}
					}
				);

				expect( output ).toBe( expected );
			} );

			it( "List: Lists should be iterated; list items should visit the context stack.", function(){
				var output = variables.stubble.render(
					'"{{##list}}{{item}}{{/list}}"',
					{
						list: [
							{ item: 1 },
							{ item: 2 },
							{ item: 3 }
						]
					}
				);

				expect( output ).toBe( '"123"' );
			} );

			it( "Empty List: Empty lists should behave like falsey values.", function(){
				var output = variables.stubble.render(
					'"{{##list}}Yay lists!{{/list}}"',
					{ list: [] }
				);

				expect( output ).toBe( '""' );
			} );

			it( "Doubled: Multiple sections per template should be permitted.", function(){
				var template = "{{##bool}}" & chr( 10 ) & "* first" & chr( 10 ) & "{{/bool}}" & chr( 10 ) & "* {{two}}" & chr( 10 ) & "{{##bool}}" & chr( 10 ) & "* third" & chr( 10 ) & "{{/bool}}" & chr( 10 );
				var expected = "* first" & chr( 10 ) & "* second" & chr( 10 ) & "* third" & chr( 10 );

				var output = variables.stubble.render(
					template,
					{ bool: true, two: "second" }
				);

				expect( output ).toBe( expected );
			} );

			it( "Nested (Truthy): Nested truthy sections should have their contents rendered.", function(){
				var output = variables.stubble.render(
					"| A {{##bool}}B {{##bool}}C{{/bool}} D{{/bool}} E |",
					{ bool: true }
				);

				expect( output ).toBe( "| A B C D E |" );
			} );

			it( "Nested (Falsey): Nested falsey sections should be omitted.", function(){
				var output = variables.stubble.render(
					"| A {{##bool}}B {{##bool}}C{{/bool}} D{{/bool}} E |",
					{ bool: false }
				);

				expect( output ).toBe( "| A  E |" );
			} );

			it( "Context Misses: Failed context lookups should be considered falsey.", function(){
				var output = variables.stubble.render(
					"[{{##missing}}Found key 'missing'!{{/missing}}]",
					{}
				);

				expect( output ).toBe( "[]" );
			} );

			it( "Implicit Iterator - String: Implicit iterators should directly interpolate strings.", function(){
				var output = variables.stubble.render(
					'"{{##list}}({{.}}){{/list}}"',
					{ list: [ "a", "b", "c", "d", "e" ] }
				);

				expect( output ).toBe( '"(a)(b)(c)(d)(e)"' );
			} );

			it( "Implicit Iterator - Integer: Implicit iterators should cast integers to strings and interpolate.", function(){
				var output = variables.stubble.render(
					'"{{##list}}({{.}}){{/list}}"',
					{ list: [ 1, 2, 3, 4, 5 ] }
				);

				expect( output ).toBe( '"(1)(2)(3)(4)(5)"' );
			} );

			it( "Implicit Iterator - Decimal: Implicit iterators should cast decimals to strings and interpolate.", function(){
				var output = variables.stubble.render(
					'"{{##list}}({{.}}){{/list}}"',
					{ list: [ 1.1, 2.2, 3.3, 4.4, 5.5 ] }
				);

				expect( output ).toBe( '"(1.1)(2.2)(3.3)(4.4)(5.5)"' );
			} );

			it( "Implicit Iterator - Array: Implicit iterators should allow iterating over nested arrays.", function(){
				var output = variables.stubble.render(
					'"{{##list}}({{##.}}{{.}}{{/.}}){{/list}}"',
					{ list: [ [ 1, 2, 3 ], [ "a", "b", "c" ] ] }
				);

				expect( output ).toBe( '"(123)(abc)"' );
			} );

			it( "Implicit Iterator - HTML Escaping: Implicit iterators with basic interpolation should be HTML escaped.", function(){
				var output = variables.stubble.render(
					'"{{##list}}({{.}}){{/list}}"',
					{ list: [ "&", '"', "<", ">" ] }
				);

				expect( output ).toBe( '"(&amp;)(&quot;)(&lt;)(&gt;)"' );
			} );

			it( "Implicit Iterator - Triple mustache: Implicit iterators in triple mustache should interpolate without HTML escaping.", function(){
				var output = variables.stubble.render(
					'"{{##list}}({{{.}}}){{/list}}"',
					{ list: [ "&", '"', "<", ">" ] }
				);

				expect( output ).toBe( '"(&)(")(<)(>)"' );
			} );

			it( "Implicit Iterator - Ampersand: Implicit iterators in an Ampersand tag should interpolate without HTML escaping.", function(){
				var output = variables.stubble.render(
					'"{{##list}}({{&.}}){{/list}}"',
					{ list: [ "&", '"', "<", ">" ] }
				);

				expect( output ).toBe( '"(&)(")(<)(>)"' );
			} );

			it( "Implicit Iterator - Root-level: Implicit iterators should work on root-level lists.", function(){
				var output = variables.stubble.render(
					'"{{##.}}({{value}}){{/.}}"',
					[
						{ value: "a" },
						{ value: "b" }
					]
				);

				expect( output ).toBe( '"(a)(b)"' );
			} );

			it( "Dotted Names - Truthy: Dotted names should be valid for Section tags.", function(){
				var output = variables.stubble.render(
					'"{{##a.b.c}}Here{{/a.b.c}}" == "Here"',
					{ a: { b: { c: true } } }
				);

				expect( output ).toBe( '"Here" == "Here"' );
			} );

			it( "Dotted Names - Falsey: Dotted names should be valid for Section tags.", function(){
				var output = variables.stubble.render(
					'"{{##a.b.c}}Here{{/a.b.c}}" == ""',
					{ a: { b: { c: false } } }
				);

				expect( output ).toBe( '"" == ""' );
			} );

			it( "Dotted Names - Broken Chains: Dotted names that cannot be resolved should be considered falsey.", function(){
				var output = variables.stubble.render(
					'"{{##a.b.c}}Here{{/a.b.c}}" == ""',
					{ a: {} }
				);

				expect( output ).toBe( '"" == ""' );
			} );

			it( "Surrounding Whitespace: Sections should not alter surrounding whitespace.", function(){
				var output = variables.stubble.render(
					" | {{##boolean}}" & chr( 9 ) & "|" & chr( 9 ) & "{{/boolean}} | " & chr( 10 ),
					{ boolean: true }
				);

				expect( output ).toBe( " | " & chr( 9 ) & "|" & chr( 9 ) & " | " & chr( 10 ) );
			} );

			it( "Internal Whitespace: Sections should not alter internal whitespace.", function(){
				var output = variables.stubble.render(
					" | {{##boolean}} {{! Important Whitespace }}" & chr( 10 ) & " {{/boolean}} | " & chr( 10 ),
					{ boolean: true }
				);

				expect( output ).toBe( " |  " & chr( 10 ) & "  | " & chr( 10 ) );
			} );

			it( "Indented Inline Sections: Single-line sections should not alter surrounding whitespace.", function(){
				var output = variables.stubble.render(
					" {{##boolean}}YES{{/boolean}}" & chr( 10 ) & " {{##boolean}}GOOD{{/boolean}}" & chr( 10 ),
					{ boolean: true }
				);

				expect( output ).toBe( " YES" & chr( 10 ) & " GOOD" & chr( 10 ) );
			} );

			it( "Standalone Lines: Standalone lines should be removed from the template.", function(){
				var output = variables.stubble.render(
					"| This Is" & chr( 10 ) & "{{##boolean}}" & chr( 10 ) & "|" & chr( 10 ) & "{{/boolean}}" & chr( 10 ) & "| A Line" & chr( 10 ),
					{ boolean: true }
				);

				expect( output ).toBe( "| This Is" & chr( 10 ) & "|" & chr( 10 ) & "| A Line" & chr( 10 ) );
			} );

			it( "Indented Standalone Lines: Indented standalone lines should be removed from the template.", function(){
				var output = variables.stubble.render(
					"| This Is" & chr( 10 ) & "  {{##boolean}}" & chr( 10 ) & "|" & chr( 10 ) & "  {{/boolean}}" & chr( 10 ) & "| A Line" & chr( 10 ),
					{ boolean: true }
				);

				expect( output ).toBe( "| This Is" & chr( 10 ) & "|" & chr( 10 ) & "| A Line" & chr( 10 ) );
			} );

			it( "Standalone Line Endings: '\r\n' should be considered a newline for standalone tags.", function(){
				var output = variables.stubble.render(
					"|" & chr( 13 ) & chr( 10 ) & "{{##boolean}}" & chr( 13 ) & chr( 10 ) & "{{/boolean}}" & chr( 13 ) & chr( 10 ) & "|",
					{ boolean: true }
				);

				expect( output ).toBe( "|" & chr( 13 ) & chr( 10 ) & "|" );
			} );

			it( "Standalone Without Previous Line: Standalone tags should not require a newline to precede them.", function(){
				var output = variables.stubble.render(
					"  {{##boolean}}" & chr( 10 ) & "##{{/boolean}}" & chr( 10 ) & "/",
					{ boolean: true }
				);

				expect( output ).toBe( "##" & chr( 10 ) & "/" );
			} );

			it( "Standalone Without Newline: Standalone tags should not require a newline to follow them.", function(){
				var output = variables.stubble.render(
					"##{{##boolean}}" & chr( 10 ) & "/" & chr( 10 ) & "  {{/boolean}}",
					{ boolean: true }
				);

				expect( output ).toBe( "##" & chr( 10 ) & "/" & chr( 10 ) );
			} );

			it( "Padding: Superfluous in-tag whitespace should be ignored.", function(){
				var output = variables.stubble.render(
					"|{{## boolean }}={{/ boolean }}|",
					{ boolean: true }
				);

				expect( output ).toBe( "|=|" );
			} );
		} );
	}
}
