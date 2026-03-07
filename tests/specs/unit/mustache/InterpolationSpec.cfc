/**
 * Mustache interpolation compliance BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Mustache interpolation spec", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "No Interpolation: Mustache-free templates should render as-is.", function(){
				var output = variables.stubble.render(
					'Hello from {Mustache}!' & chr( 10 ),
					{}
				);

				expect( output ).toBe( 'Hello from {Mustache}!' & chr( 10 ) );
			} );

			it( "Basic Interpolation: Unadorned tags should interpolate content into the template.", function(){
				var output = variables.stubble.render(
					'Hello, {{subject}}!' & chr( 10 ),
					{ subject: 'world' }
				);

				expect( output ).toBe( 'Hello, world!' & chr( 10 ) );
			} );

			it( "No Re-interpolation: Interpolated tag output should not be re-interpolated.", function(){
				var output = variables.stubble.render(
					'{{template}}: {{planet}}',
					{
						template: '{{planet}}',
						planet: 'Earth'
					}
				);

				expect( output ).toBe( '{{planet}}: Earth' );
			} );

			it( "HTML Escaping: Basic interpolation should be HTML escaped.", function(){
				var output = variables.stubble.render(
					'These characters should be HTML escaped: {{forbidden}}' & chr( 10 ),
					{ forbidden: '& " < >' }
				);

				expect( output ).toBe( 'These characters should be HTML escaped: &amp; &quot; &lt; &gt;' & chr( 10 ) );
			} );

			it( "Triple Mustache: Triple mustaches should interpolate without HTML escaping.", function(){
				var output = variables.stubble.render(
					'These characters should not be HTML escaped: {{{forbidden}}}' & chr( 10 ),
					{ forbidden: '& " < >' }
				);

				expect( output ).toBe( 'These characters should not be HTML escaped: & " < >' & chr( 10 ) );
			} );

			it( "Ampersand: Ampersand should interpolate without HTML escaping.", function(){
				var output = variables.stubble.render(
					'These characters should not be HTML escaped: {{&forbidden}}' & chr( 10 ),
					{ forbidden: '& " < >' }
				);

				expect( output ).toBe( 'These characters should not be HTML escaped: & " < >' & chr( 10 ) );
			} );

			it( "Basic Integer Interpolation: Integers should interpolate seamlessly.", function(){
				var output = variables.stubble.render(
					'"{{mph}} miles an hour!"',
					{ mph: 85 }
				);

				expect( output ).toBe( '"85 miles an hour!"' );
			} );

			it( "Triple Mustache Integer Interpolation: Integers should interpolate seamlessly.", function(){
				var output = variables.stubble.render(
					'"{{{mph}}} miles an hour!"',
					{ mph: 85 }
				);

				expect( output ).toBe( '"85 miles an hour!"' );
			} );

			it( "Ampersand Integer Interpolation: Integers should interpolate seamlessly.", function(){
				var output = variables.stubble.render(
					'"{{&mph}} miles an hour!"',
					{ mph: 85 }
				);

				expect( output ).toBe( '"85 miles an hour!"' );
			} );

			it( "Basic Decimal Interpolation: Decimals should interpolate seamlessly with proper significance.", function(){
				var output = variables.stubble.render(
					'"{{power}} jiggawatts!"',
					{ power: 1.21 }
				);

				expect( output ).toBe( '"1.21 jiggawatts!"' );
			} );

			it( "Triple Mustache Decimal Interpolation: Decimals should interpolate seamlessly with proper significance.", function(){
				var output = variables.stubble.render(
					'"{{{power}}} jiggawatts!"',
					{ power: 1.21 }
				);

				expect( output ).toBe( '"1.21 jiggawatts!"' );
			} );

			it( "Ampersand Decimal Interpolation: Decimals should interpolate seamlessly with proper significance.", function(){
				var output = variables.stubble.render(
					'"{{&power}} jiggawatts!"',
					{ power: 1.21 }
				);

				expect( output ).toBe( '"1.21 jiggawatts!"' );
			} );

			it( "Basic Null Interpolation: Nulls should interpolate as the empty string.", function(){
				var output = variables.stubble.render(
					'I ({{cannot}}) be seen!',
					{ cannot: javaCast( "null", "" ) }
				);

				expect( output ).toBe( 'I () be seen!' );
			} );

			it( "Triple Mustache Null Interpolation: Nulls should interpolate as the empty string.", function(){
				var output = variables.stubble.render(
					'I ({{{cannot}}}) be seen!',
					{ cannot: javaCast( "null", "" ) }
				);

				expect( output ).toBe( 'I () be seen!' );
			} );

			it( "Ampersand Null Interpolation: Nulls should interpolate as the empty string.", function(){
				var output = variables.stubble.render(
					'I ({{&cannot}}) be seen!',
					{ cannot: javaCast( "null", "" ) }
				);

				expect( output ).toBe( 'I () be seen!' );
			} );

			it( "Basic Context Miss Interpolation: Failed context lookups should default to empty strings.", function(){
				var output = variables.stubble.render(
					'I ({{cannot}}) be seen!',
					{}
				);

				expect( output ).toBe( 'I () be seen!' );
			} );

			it( "Triple Mustache Context Miss Interpolation: Failed context lookups should default to empty strings.", function(){
				var output = variables.stubble.render(
					'I ({{{cannot}}}) be seen!',
					{}
				);

				expect( output ).toBe( 'I () be seen!' );
			} );

			it( "Ampersand Context Miss Interpolation: Failed context lookups should default to empty strings.", function(){
				var output = variables.stubble.render(
					'I ({{&cannot}}) be seen!',
					{}
				);

				expect( output ).toBe( 'I () be seen!' );
			} );

			it( "Dotted Names - Basic Interpolation: Dotted names should be considered a form of shorthand for sections.", function(){
				var output = variables.stubble.render(
					'"{{person.name}}" == "{{$person}}{{name}}{{/person}}"',
					{ person: { name: 'Joe' } }
				);

				expect( output ).toBe( '"Joe" == "Joe"' );
			} );

			it( "Dotted Names - Triple Mustache Interpolation: Dotted names should be considered a form of shorthand for sections.", function(){
				var output = variables.stubble.render(
					'"{{{person.name}}}" == "{{$person}}{{{name}}}{{/person}}"',
					{ person: { name: 'Joe' } }
				);

				expect( output ).toBe( '"Joe" == "Joe"' );
			} );

			it( "Dotted Names - Ampersand Interpolation: Dotted names should be considered a form of shorthand for sections.", function(){
				var output = variables.stubble.render(
					'"{{&person.name}}" == "{{$person}}{{&name}}{{/person}}"',
					{ person: { name: 'Joe' } }
				);

				expect( output ).toBe( '"Joe" == "Joe"' );
			} );

			it( "Dotted Names - Arbitrary Depth: Dotted names should be functional to any level of nesting.", function(){
				var output = variables.stubble.render(
					'"{{a.b.c.d.e.name}}" == "Phil"',
					{
						a: {
							b: {
								c: {
									d: {
										e: {
											name: 'Phil'
										}
									}
								}
							}
						}
					}
				);

				expect( output ).toBe( '"Phil" == "Phil"' );
			} );

			it( "Dotted Names - Broken Chains: Any falsey value prior to the last part of the name should yield ''.", function(){
				var output = variables.stubble.render(
					'"{{a.b.c}}" == ""',
					{ a: {} }
				);

				expect( output ).toBe( '"" == ""' );
			} );

			it( "Dotted Names - Broken Chain Resolution: Each part of a dotted name should resolve only against its parent.", function(){
				var output = variables.stubble.render(
					'"{{a.b.c.name}}" == ""',
					{
						a: {
							b: {}
						},
						c: {
							name: 'Jim'
						}
					}
				);

				expect( output ).toBe( '"" == ""' );
			} );

			it( "Dotted Names - Initial Resolution: The first part of a dotted name should resolve as any other name.", function(){
				var output = variables.stubble.render(
					'"{{$a}}{{b.c.d.e.name}}{{/a}}" == "Phil"',
					{
						a: {
							b: {
								c: {
									d: {
										e: {
											name: 'Phil'
										}
									}
								}
							}
						},
						b: {
							c: {
								d: {
									e: {
										name: 'Wrong'
									}
								}
							}
						}
					}
				);

				expect( output ).toBe( '"Phil" == "Phil"' );
			} );

			it( "Dotted Names - Context Precedence: Dotted names should be resolved against former resolutions.", function(){
				var output = variables.stubble.render(
					'{{$a}}{{b.c}}{{/a}}',
					{
						a: {
							b: {}
						},
						b: {
							c: 'ERROR'
						}
					}
				);

				expect( output ).toBe( '' );
			} );

			it( "Dotted Names are never single keys: Dotted names shall not be parsed as single, atomic keys", function(){
				var output = variables.stubble.render(
					'{{a.b}}',
					{ 'a.b': 'c' }
				);

				expect( output ).toBe( '' );
			} );

			it( "Dotted Names - No Masking: Dotted Names in a given context are unvavailable due to dot splitting", function(){
				var output = variables.stubble.render(
					'{{a.b}}',
					{
						'a.b': 'c',
						a: { b: 'd' }
					}
				);

				expect( output ).toBe( 'd' );
			} );

			it( "Implicit Iterators - Basic Interpolation: Unadorned tags should interpolate content into the template.", function(){
				var output = variables.stubble.render(
					'Hello, {{.}}!' & chr( 10 ),
					'world'
				);

				expect( output ).toBe( 'Hello, world!' & chr( 10 ) );
			} );

			it( "Implicit Iterators - HTML Escaping: Basic interpolation should be HTML escaped.", function(){
				var output = variables.stubble.render(
					'These characters should be HTML escaped: {{.}}' & chr( 10 ),
					'& " < >'
				);

				expect( output ).toBe( 'These characters should be HTML escaped: &amp; &quot; &lt; &gt;' & chr( 10 ) );
			} );

			it( "Implicit Iterators - Triple Mustache: Triple mustaches should interpolate without HTML escaping.", function(){
				var output = variables.stubble.render(
					'These characters should not be HTML escaped: {{{.}}}' & chr( 10 ),
					'& " < >'
				);

				expect( output ).toBe( 'These characters should not be HTML escaped: & " < >' & chr( 10 ) );
			} );

			it( "Implicit Iterators - Ampersand: Ampersand should interpolate without HTML escaping.", function(){
				var output = variables.stubble.render(
					'These characters should not be HTML escaped: {{&.}}' & chr( 10 ),
					'& " < >'
				);

				expect( output ).toBe( 'These characters should not be HTML escaped: & " < >' & chr( 10 ) );
			} );

			it( "Implicit Iterators - Basic Integer Interpolation: Integers should interpolate seamlessly.", function(){
				var output = variables.stubble.render(
					'"{{.}} miles an hour!"',
					85
				);

				expect( output ).toBe( '"85 miles an hour!"' );
			} );

			it( "Interpolation - Surrounding Whitespace: Interpolation should not alter surrounding whitespace.", function(){
				var output = variables.stubble.render(
					'| {{string}} |',
					{ string: '---' }
				);

				expect( output ).toBe( '| --- |' );
			} );

			it( "Triple Mustache - Surrounding Whitespace: Interpolation should not alter surrounding whitespace.", function(){
				var output = variables.stubble.render(
					'| {{{string}}} |',
					{ string: '---' }
				);

				expect( output ).toBe( '| --- |' );
			} );

			it( "Ampersand - Surrounding Whitespace: Interpolation should not alter surrounding whitespace.", function(){
				var output = variables.stubble.render(
					'| {{&string}} |',
					{ string: '---' }
				);

				expect( output ).toBe( '| --- |' );
			} );

			it( "Interpolation - Standalone: Standalone interpolation should not alter surrounding whitespace.", function(){
				var output = variables.stubble.render(
					'  {{string}}' & chr( 10 ),
					{ string: '---' }
				);

				expect( output ).toBe( '  ---' & chr( 10 ) );
			} );

			it( "Triple Mustache - Standalone: Standalone interpolation should not alter surrounding whitespace.", function(){
				var output = variables.stubble.render(
					'  {{{string}}}' & chr( 10 ),
					{ string: '---' }
				);

				expect( output ).toBe( '  ---' & chr( 10 ) );
			} );

			it( "Ampersand - Standalone: Standalone interpolation should not alter surrounding whitespace.", function(){
				var output = variables.stubble.render(
					'  {{&string}}' & chr( 10 ),
					{ string: '---' }
				);

				expect( output ).toBe( '  ---' & chr( 10 ) );
			} );

			it( "Interpolation With Padding: Superfluous in-tag whitespace should be ignored.", function(){
				var output = variables.stubble.render(
					'|{{ string }}|',
					{ string: '---' }
				);

				expect( output ).toBe( '|---|' );
			} );

			it( "Triple Mustache With Padding: Superfluous in-tag whitespace should be ignored.", function(){
				var output = variables.stubble.render(
					'|{{{ string }}}|',
					{ string: '---' }
				);

				expect( output ).toBe( '|---|' );
			} );

			it( "Ampersand With Padding: Superfluous in-tag whitespace should be ignored.", function(){
				var output = variables.stubble.render(
					'|{{& string }}|',
					{ string: '---' }
				);

				expect( output ).toBe( '|---|' );
			} );
		} );
	}
}
