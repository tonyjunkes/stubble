/**
 * Mustache comments compliance BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Mustache comments spec", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "Inline: Comment blocks should be removed from the template.", function(){
				var output = variables.stubble.render(
					"12345{{! Comment Block! }}67890",
					{}
				);

				expect( output ).toBe( "1234567890" );
			} );

			it( "Multiline: Multiline comments should be permitted.", function(){
				var output = variables.stubble.render(
					"12345{{!" & chr( 10 ) & "  This is a" & chr( 10 ) & "  multi-line comment..." & chr( 10 ) & "}}67890" & chr( 10 ),
					{}
				);

				expect( output ).toBe( "1234567890" & chr( 10 ) );
			} );

			it( "Standalone: All standalone comment lines should be removed.", function(){
				var output = variables.stubble.render(
					"Begin." & chr( 10 ) & "{{! Comment Block! }}" & chr( 10 ) & "End." & chr( 10 ),
					{}
				);

				expect( output ).toBe( "Begin." & chr( 10 ) & "End." & chr( 10 ) );
			} );

			it( "Indented Standalone: All standalone comment lines should be removed.", function(){
				var output = variables.stubble.render(
					"Begin." & chr( 10 ) & "  {{! Indented Comment Block! }}" & chr( 10 ) & "End." & chr( 10 ),
					{}
				);

				expect( output ).toBe( "Begin." & chr( 10 ) & "End." & chr( 10 ) );
			} );

			it( "Standalone Line Endings: '\r\n' should be considered a newline for standalone tags.", function(){
				var output = variables.stubble.render(
					"|" & chr( 13 ) & chr( 10 ) & "{{! Standalone Comment }}" & chr( 13 ) & chr( 10 ) & "|",
					{}
				);

				expect( output ).toBe( "|" & chr( 13 ) & chr( 10 ) & "|" );
			} );

			it( "Standalone Without Previous Line: Standalone tags should not require a newline to precede them.", function(){
				var output = variables.stubble.render(
					"  {{! I'm Still Standalone }}" & chr( 10 ) & "!",
					{}
				);

				expect( output ).toBe( "!" );
			} );

			it( "Standalone Without Newline: Standalone tags should not require a newline to follow them.", function(){
				var output = variables.stubble.render(
					"!" & chr( 10 ) & "  {{! I'm Still Standalone }}",
					{}
				);

				expect( output ).toBe( "!" & chr( 10 ) );
			} );

			it( "Multiline Standalone: All standalone comment lines should be removed.", function(){
				var output = variables.stubble.render(
					"Begin." & chr( 10 ) & "{{!" & chr( 10 ) & "Something's going on here..." & chr( 10 ) & "}}" & chr( 10 ) & "End." & chr( 10 ),
					{}
				);

				expect( output ).toBe( "Begin." & chr( 10 ) & "End." & chr( 10 ) );
			} );

			it( "Indented Multiline Standalone: All standalone comment lines should be removed.", function(){
				var output = variables.stubble.render(
					"Begin." & chr( 10 ) & "  {{!" & chr( 10 ) & "    Something's going on here..." & chr( 10 ) & "  }}" & chr( 10 ) & "End." & chr( 10 ),
					{}
				);

				expect( output ).toBe( "Begin." & chr( 10 ) & "End." & chr( 10 ) );
			} );

			it( "Indented Inline: Inline comments should not strip whitespace", function(){
				var output = variables.stubble.render(
					"  12 {{! 34 }}" & chr( 10 ),
					{}
				);

				expect( output ).toBe( "  12 " & chr( 10 ) );
			} );

			it( "Surrounding Whitespace: Comment removal should preserve surrounding whitespace.", function(){
				var output = variables.stubble.render(
					"12345 {{! Comment Block! }} 67890",
					{}
				);

				expect( output ).toBe( "12345  67890" );
			} );

			it( "Variable Name Collision: Comments must never render, even if variable with same name exists.", function(){
				var view = {};
				view[ "! comment" ] = 1;
				view[ "! comment " ] = 2;
				view[ "!comment" ] = 3;
				view[ "comment" ] = 4;

				var output = variables.stubble.render(
					"comments never show: >{{! comment }}<",
					view
				);

				expect( output ).toBe( "comments never show: ><" );
			} );
		} );
	}
}
