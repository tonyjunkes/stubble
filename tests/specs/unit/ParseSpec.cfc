/**
 * Stubble parse() BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Stubble parse()", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "builds variable and unescaped nodes with dotted name parts", function(){
				var template = "{{user.name}} {{& html}}";
				var ast      = variables.stubble.parse( variables.stubble.tokenize( template ), template );

				expect( ast ).toHaveLength( 3 );
				expect( ast[ 1 ].type ).toBe( "variable" );
				expect( ast[ 1 ].name ).toBe( "user.name" );
				expect( ast[ 1 ].nameParts ).toHaveLength( 2 );
				expect( ast[ 1 ].nameParts[ 1 ] ).toBe( "user" );
				expect( ast[ 1 ].nameParts[ 2 ] ).toBe( "name" );
				expect( ast[ 3 ].type ).toBe( "unescaped" );
				expect( ast[ 3 ].name ).toBe( "html" );
			} );

			it( "captures section raw text and nested children", function(){
				var template = "{{##people}}- {{name}}{{/people}}";
				var ast      = variables.stubble.parse( variables.stubble.tokenize( template ), template );

				expect( ast ).toHaveLength( 1 );
				expect( ast[ 1 ].type ).toBe( "section" );
				expect( ast[ 1 ].name ).toBe( "people" );
				expect( ast[ 1 ].rawText ).toBe( "- {{name}}" );
				expect( ast[ 1 ].children ).toHaveLength( 2 );
				expect( ast[ 1 ].children[ 1 ].type ).toBe( "text" );
				expect( ast[ 1 ].children[ 2 ].type ).toBe( "variable" );
			} );

			it( "ignores comment tokens in the AST", function(){
				var template = "A{{! ignore }}B";
				var ast      = variables.stubble.parse( variables.stubble.tokenize( template ), template );

				expect( ast ).toHaveLength( 2 );
				expect( ast[ 1 ].type ).toBe( "text" );
				expect( ast[ 1 ].value ).toBe( "A" );
				expect( ast[ 2 ].type ).toBe( "text" );
				expect( ast[ 2 ].value ).toBe( "B" );
			} );

			it( "captures empty section bodies as empty raw text", function(){
				var template = "{{##a}}{{/a}}";
				var ast      = variables.stubble.parse( variables.stubble.tokenize( template ), template );

				expect( ast ).toHaveLength( 1 );
				expect( ast[ 1 ].type ).toBe( "section" );
				expect( ast[ 1 ].rawText ).toBe( "" );
				expect( ast[ 1 ].children ).toHaveLength( 0 );
			} );

			it( "throws when closing section has no opening", function(){
				var template = "{{/people}}";
				expect( function(){
					variables.stubble.parse( variables.stubble.tokenize( template ), template );
				} ).toThrow( type = "Stubble.Parser" );
			} );

			it( "throws when section names mismatch", function(){
				var template = "{{##a}}x{{/b}}";
				expect( function(){
					variables.stubble.parse( variables.stubble.tokenize( template ), template );
				} ).toThrow( type = "Stubble.Parser" );
			} );

			it( "throws on unclosed sections", function(){
				var template = "{{##a}}x";
				expect( function(){
					variables.stubble.parse( variables.stubble.tokenize( template ), template );
				} ).toThrow( type = "Stubble.Parser" );
			} );

			it( "throws on unsupported token types", function(){
				expect( function(){
					variables.stubble.parse( [ { type: "unknown" } ], "" );
				} ).toThrow( type = "Stubble.Parser" );
			} );
		} );
	}
}
