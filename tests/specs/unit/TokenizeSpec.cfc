/**
 * Stubble tokenize() BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Stubble tokenize()", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "tokenizes plain text with no tags", function(){
				var tokens = variables.stubble.tokenize( "Hello" );

				expect( tokens ).toHaveLength( 1 );
				expect( tokens[ 1 ].type ).toBe( "text" );
				expect( tokens[ 1 ].value ).toBe( "Hello" );
				expect( tokens[ 1 ].startPos ).toBe( 1 );
				expect( tokens[ 1 ].endPos ).toBe( 5 );
			} );

			it( "tokenizes comments, partials, sections, and inverted tags", function(){
				var template = "{{! note}}{{> row}}{{##items}}A{{/items}}{{^empty}}B{{/empty}}";
				var tokens   = variables.stubble.tokenize( template );

				expect( tokens ).toHaveLength( 8 );
				expect( tokens[ 1 ].type ).toBe( "comment" );
				expect( tokens[ 2 ].type ).toBe( "partial" );
				expect( tokens[ 2 ].name ).toBe( "row" );
				expect( tokens[ 3 ].type ).toBe( "section_start" );
				expect( tokens[ 3 ].name ).toBe( "items" );
				expect( tokens[ 5 ].type ).toBe( "section_end" );
				expect( tokens[ 5 ].name ).toBe( "items" );
				expect( tokens[ 6 ].type ).toBe( "inverted_start" );
				expect( tokens[ 6 ].name ).toBe( "empty" );
			} );

			it( "supports closing tags with /##name shorthand", function(){
				var tokens = variables.stubble.tokenize( "{{##items}}X{{/##items}}" );

				expect( tokens ).toHaveLength( 3 );
				expect( tokens[ 1 ].type ).toBe( "section_start" );
				expect( tokens[ 1 ].name ).toBe( "items" );
				expect( tokens[ 3 ].type ).toBe( "section_end" );
				expect( tokens[ 3 ].name ).toBe( "items" );
			} );

			it( "tokenizes variables and unescaped tags", function(){
				var tokens = variables.stubble.tokenize( "Hi {{name}} {{{html}}} {{& raw}}" );

				expect( tokens ).toHaveLength( 6 );
				expect( tokens[ 2 ].type ).toBe( "variable" );
				expect( tokens[ 2 ].name ).toBe( "name" );
				expect( tokens[ 4 ].type ).toBe( "unescaped" );
				expect( tokens[ 4 ].name ).toBe( "html" );
				expect( tokens[ 6 ].type ).toBe( "unescaped" );
				expect( tokens[ 6 ].name ).toBe( "raw" );
			} );

			it( "throws on unclosed tags", function(){
				expect( function(){
					variables.stubble.tokenize( "Hello {{name" );
				} ).toThrow( type = "Stubble.Tokenizer" );
			} );

			it( "throws on unclosed triple mustache tags", function(){
				expect( function(){
					variables.stubble.tokenize( "Hello {{{name}}" );
				} ).toThrow( type = "Stubble.Tokenizer" );
			} );
		} );
	}
}
