/**
 * StringUtil BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "StringUtil", function(){
			beforeEach( function(){
				variables.su = createObject( "component", "models.StringUtil" );
			} );

			describe( "getLineStartPos()", function(){
				it( "returns 1 for position 1", function(){
					expect( variables.su.getLineStartPos( "hello", 1 ) ).toBe( 1 );
				} );

				it( "returns 1 when there is no preceding line break", function(){
					expect( variables.su.getLineStartPos( "hello world", 6 ) ).toBe( 1 );
				} );

				it( "returns position after LF", function(){
					var template = "line1#chr( 10 )#line2";
					expect( variables.su.getLineStartPos( template, 8 ) ).toBe( 7 );
				} );

				it( "returns position after CR", function(){
					var template = "line1#chr( 13 )#line2";
					expect( variables.su.getLineStartPos( template, 8 ) ).toBe( 7 );
				} );

				it( "returns position after CRLF", function(){
					var template = "line1#chr( 13 )##chr( 10 )#line2";
					expect( variables.su.getLineStartPos( template, 9 ) ).toBe( 8 );
				} );

				it( "handles multiple lines and picks the nearest break", function(){
					var template = "a#chr( 10 )#b#chr( 10 )#c";
					// position 5 is 'c', nearest preceding LF is at position 4
					expect( variables.su.getLineStartPos( template, 5 ) ).toBe( 5 );
				} );
			} );

			describe( "findLastPosition()", function(){
				it( "returns 0 when needle is not found", function(){
					expect( variables.su.findLastPosition( "x", "hello" ) ).toBe( 0 );
				} );

				it( "returns 1-based position of the single occurrence", function(){
					expect( variables.su.findLastPosition( "l", "hello" ) ).toBe( 4 );
				} );

				it( "returns position of the last occurrence", function(){
					expect( variables.su.findLastPosition( "a", "abracadabra" ) ).toBe( 11 );
				} );

				it( "works with an empty haystack", function(){
					expect( variables.su.findLastPosition( "x", "" ) ).toBe( 0 );
				} );
			} );

			describe( "findNextLineBreakPos()", function(){
				it( "returns 0 when startPos exceeds template length", function(){
					expect( variables.su.findNextLineBreakPos( "abc", 10 ) ).toBe( 0 );
				} );

				it( "returns 0 when there is no line break", function(){
					expect( variables.su.findNextLineBreakPos( "hello", 1 ) ).toBe( 0 );
				} );

				it( "finds the next LF", function(){
					var template = "ab#chr( 10 )#cd";
					expect( variables.su.findNextLineBreakPos( template, 1 ) ).toBe( 3 );
				} );

				it( "finds the next CR", function(){
					var template = "ab#chr( 13 )#cd";
					expect( variables.su.findNextLineBreakPos( template, 1 ) ).toBe( 3 );
				} );

				it( "returns the earlier of LF and CR when both exist", function(){
					var template = "a#chr( 10 )#b#chr( 13 )#c";
					expect( variables.su.findNextLineBreakPos( template, 1 ) ).toBe( 2 );
				} );

				it( "respects the startPos parameter", function(){
					var template = "a#chr( 10 )#b#chr( 10 )#c";
					expect( variables.su.findNextLineBreakPos( template, 3 ) ).toBe( 4 );
				} );

				it( "returns CR position when no LF exists", function(){
					var template = "ab#chr( 13 )#cd";
					expect( variables.su.findNextLineBreakPos( template, 1 ) ).toBe( 3 );
				} );
			} );

			describe( "getLineBreakLength()", function(){
				it( "returns 1 for a standalone LF", function(){
					var template = "a#chr( 10 )#b";
					expect( variables.su.getLineBreakLength( template, 2 ) ).toBe( 1 );
				} );

				it( "returns 1 for a standalone CR", function(){
					var template = "a#chr( 13 )#b";
					expect( variables.su.getLineBreakLength( template, 2 ) ).toBe( 1 );
				} );

				it( "returns 2 for a CRLF sequence", function(){
					var template = "a#chr( 13 )##chr( 10 )#b";
					expect( variables.su.getLineBreakLength( template, 2 ) ).toBe( 2 );
				} );

				it( "returns 1 for CR at end of template", function(){
					var template = "a#chr( 13 )#";
					expect( variables.su.getLineBreakLength( template, 2 ) ).toBe( 1 );
				} );
			} );

			describe( "containsOnlyStandaloneWhitespace()", function(){
				it( "returns true for an empty string", function(){
					expect( variables.su.containsOnlyStandaloneWhitespace( "" ) ).toBeTrue();
				} );

				it( "returns true for spaces only", function(){
					expect( variables.su.containsOnlyStandaloneWhitespace( "   " ) ).toBeTrue();
				} );

				it( "returns true for tabs only", function(){
					expect( variables.su.containsOnlyStandaloneWhitespace( chr( 9 ) & chr( 9 ) ) ).toBeTrue();
				} );

				it( "returns true for mixed spaces and tabs", function(){
					expect( variables.su.containsOnlyStandaloneWhitespace( " #chr( 9 )# " ) ).toBeTrue();
				} );

				it( "returns false when non-whitespace is present", function(){
					expect( variables.su.containsOnlyStandaloneWhitespace( " x " ) ).toBeFalse();
				} );

				it( "returns false for line break characters", function(){
					expect( variables.su.containsOnlyStandaloneWhitespace( chr( 10 ) ) ).toBeFalse();
				} );
			} );

			describe( "containsLineBreak()", function(){
				it( "returns false for an empty string", function(){
					expect( variables.su.containsLineBreak( "" ) ).toBeFalse();
				} );

				it( "returns false when no line breaks present", function(){
					expect( variables.su.containsLineBreak( "hello world" ) ).toBeFalse();
				} );

				it( "returns true when LF is present", function(){
					expect( variables.su.containsLineBreak( "a#chr( 10 )#b" ) ).toBeTrue();
				} );

				it( "returns true when CR is present", function(){
					expect( variables.su.containsLineBreak( "a#chr( 13 )#b" ) ).toBeTrue();
				} );

				it( "returns true when CRLF is present", function(){
					expect( variables.su.containsLineBreak( "a#chr( 13 )##chr( 10 )#b" ) ).toBeTrue();
				} );
			} );

			describe( "normalizeBlockSourceText()", function(){
				it( "returns the original text when stripLeadingLineBreak is false", function(){
					var text = "#chr( 10 )#hello";
					expect( variables.su.normalizeBlockSourceText( text, false ) ).toBe( text );
				} );

				it( "returns the original text when it is empty", function(){
					expect( variables.su.normalizeBlockSourceText( "", true ) ).toBe( "" );
				} );

				it( "strips a leading LF", function(){
					expect( variables.su.normalizeBlockSourceText( "#chr( 10 )#hello", true ) ).toBe( "hello" );
				} );

				it( "strips a leading CR", function(){
					expect( variables.su.normalizeBlockSourceText( "#chr( 13 )#hello", true ) ).toBe( "hello" );
				} );

				it( "strips a leading CRLF", function(){
					expect( variables.su.normalizeBlockSourceText( "#chr( 13 )##chr( 10 )#hello", true ) ).toBe( "hello" );
				} );

				it( "only strips the first line break", function(){
					expect( variables.su.normalizeBlockSourceText( "#chr( 10 )##chr( 10 )#hello", true ) ).toBe( "#chr( 10 )#hello" );
				} );

				it( "returns unchanged text when no leading line break exists", function(){
					expect( variables.su.normalizeBlockSourceText( "hello", true ) ).toBe( "hello" );
				} );
			} );

			describe( "endsWithLineBreak()", function(){
				it( "returns false for an empty string", function(){
					expect( variables.su.endsWithLineBreak( "" ) ).toBeFalse();
				} );

				it( "returns false when no trailing line break", function(){
					expect( variables.su.endsWithLineBreak( "hello" ) ).toBeFalse();
				} );

				it( "returns true when ending with LF", function(){
					expect( variables.su.endsWithLineBreak( "hello#chr( 10 )#" ) ).toBeTrue();
				} );

				it( "returns true when ending with CR", function(){
					expect( variables.su.endsWithLineBreak( "hello#chr( 13 )#" ) ).toBeTrue();
				} );

				it( "returns true when ending with CRLF", function(){
					expect( variables.su.endsWithLineBreak( "hello#chr( 13 )##chr( 10 )#" ) ).toBeTrue();
				} );

				it( "returns false when line break is not at the end", function(){
					expect( variables.su.endsWithLineBreak( "hello#chr( 10 )#world" ) ).toBeFalse();
				} );
			} );
		} );
	}
}
