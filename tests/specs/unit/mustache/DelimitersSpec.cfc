/**
 * Mustache delimiters compliance BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Mustache delimiters spec", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "Pair Behavior: The equals sign (used on both sides) should permit delimiter changes.", function(){
				var output = variables.stubble.render(
					"{{=<% %>=}}(<%text%>)",
					{ text: "Hey!" }
				);

				expect( output ).toBe( "(Hey!)" );
			} );

			it( "Special Characters: Characters with special meaning regexen should be valid delimiters.", function(){
				var output = variables.stubble.render(
					"({{=[ ]=}}[text])",
					{ text: "It worked!" }
				);

				expect( output ).toBe( "(It worked!)" );
			} );

			it( "Sections: Delimiters set outside sections should persist.", function(){
				var template = "[" & chr( 10 ) &
					"{{##section}}" & chr( 10 ) &
					"  {{data}}" & chr( 10 ) &
					"  |data|" & chr( 10 ) &
					"{{/section}}" & chr( 10 ) &
					chr( 10 ) &
					"{{= | | =}}" & chr( 10 ) &
					"|##section|" & chr( 10 ) &
					"  {{data}}" & chr( 10 ) &
					"  |data|" & chr( 10 ) &
					"|/section|" & chr( 10 ) &
					"]" & chr( 10 );

				var expected = "[" & chr( 10 ) &
					"  I got interpolated." & chr( 10 ) &
					"  |data|" & chr( 10 ) &
					chr( 10 ) &
					"  {{data}}" & chr( 10 ) &
					"  I got interpolated." & chr( 10 ) &
					"]" & chr( 10 );

				var output = variables.stubble.render(
					template,
					{ section: true, data: "I got interpolated." }
				);

				expect( output ).toBe( expected );
			} );

			it( "Inverted Sections: Delimiters set outside inverted sections should persist.", function(){
				var template = "[" & chr( 10 ) &
					"{{^section}}" & chr( 10 ) &
					"  {{data}}" & chr( 10 ) &
					"  |data|" & chr( 10 ) &
					"{{/section}}" & chr( 10 ) &
					chr( 10 ) &
					"{{= | | =}}" & chr( 10 ) &
					"|^section|" & chr( 10 ) &
					"  {{data}}" & chr( 10 ) &
					"  |data|" & chr( 10 ) &
					"|/section|" & chr( 10 ) &
					"]" & chr( 10 );

				var expected = "[" & chr( 10 ) &
					"  I got interpolated." & chr( 10 ) &
					"  |data|" & chr( 10 ) &
					chr( 10 ) &
					"  {{data}}" & chr( 10 ) &
					"  I got interpolated." & chr( 10 ) &
					"]" & chr( 10 );

				var output = variables.stubble.render(
					template,
					{ section: false, data: "I got interpolated." }
				);

				expect( output ).toBe( expected );
			} );

			it( "Partial Inheritence: Delimiters set in a parent template should not affect a partial.", function(){
				var template = "[ {{>include}} ]" & chr( 10 ) & "{{= | | =}}" & chr( 10 ) & "[ |>include| ]" & chr( 10 );
				var output = variables.stubble.render(
					template,
					{ value: "yes" },
					{ include: ".{{value}}." }
				);

				expect( output ).toBe( "[ .yes. ]" & chr( 10 ) & "[ .yes. ]" & chr( 10 ) );
			} );

			it( "Post-Partial Behavior: Delimiters set in a partial should not affect the parent template.", function(){
				var output = variables.stubble.render(
					"[ {{>include}} ]" & chr( 10 ) & "[ .{{value}}.  .|value|. ]" & chr( 10 ),
					{ value: "yes" },
					{ include: ".{{value}}. {{= | | =}} .|value|." }
				);

				expect( output ).toBe( "[ .yes.  .yes. ]" & chr( 10 ) & "[ .yes.  .|value|. ]" & chr( 10 ) );
			} );

			it( "Surrounding Whitespace: Surrounding whitespace should be left untouched.", function(){
				var output = variables.stubble.render( "| {{=@ @=}} |", {} );
				expect( output ).toBe( "|  |" );
			} );

			it( "Outlying Whitespace (Inline): Whitespace should be left untouched.", function(){
				var output = variables.stubble.render( " | {{=@ @=}}" & chr( 10 ), {} );
				expect( output ).toBe( " | " & chr( 10 ) );
			} );

			it( "Standalone Tag: Standalone lines should be removed from the template.", function(){
				var output = variables.stubble.render( "Begin." & chr( 10 ) & "{{=@ @=}}" & chr( 10 ) & "End." & chr( 10 ), {} );
				expect( output ).toBe( "Begin." & chr( 10 ) & "End." & chr( 10 ) );
			} );

			it( "Indented Standalone Tag: Indented standalone lines should be removed from the template.", function(){
				var output = variables.stubble.render( "Begin." & chr( 10 ) & "  {{=@ @=}}" & chr( 10 ) & "End." & chr( 10 ), {} );
				expect( output ).toBe( "Begin." & chr( 10 ) & "End." & chr( 10 ) );
			} );

			it( 'Standalone Line Endings: "\r\n" should be considered a newline for standalone tags.', function(){
				var output = variables.stubble.render( "|" & chr( 13 ) & chr( 10 ) & "{{= @ @ =}}" & chr( 13 ) & chr( 10 ) & "|", {} );
				expect( output ).toBe( "|" & chr( 13 ) & chr( 10 ) & "|" );
			} );

			it( "Standalone Without Previous Line: Standalone tags should not require a newline to precede them.", function(){
				var output = variables.stubble.render( "  {{=@ @=}}" & chr( 10 ) & "=", {} );
				expect( output ).toBe( "=" );
			} );

			it( "Standalone Without Newline: Standalone tags should not require a newline to follow them.", function(){
				var output = variables.stubble.render( "=" & chr( 10 ) & "  {{=@ @=}}", {} );
				expect( output ).toBe( "=" & chr( 10 ) );
			} );

			it( "Pair with Padding: Superfluous in-tag whitespace should be ignored.", function(){
				var output = variables.stubble.render( "|{{= @   @ =}}|", {} );
				expect( output ).toBe( "||" );
			} );
		} );
	}
}
