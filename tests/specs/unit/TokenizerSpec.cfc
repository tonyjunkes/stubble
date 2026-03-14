/**
 * Tokenizer BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Tokenizer", function(){
			beforeEach( function(){
				variables.tokenizer = createObject( "component", "models.Tokenizer" );
			} );

			describe( "tokenize()", function(){
				it( "returns empty array for empty template", function(){
					var tokens = variables.tokenizer.tokenize( "" );
					expect( tokens ).toBeEmpty();
				} );

				it( "tokenizes plain text", function(){
					var tokens = variables.tokenizer.tokenize( "Hello" );

					expect( tokens ).toHaveLength( 1 );
					expect( tokens[ 1 ].type ).toBe( "text" );
					expect( tokens[ 1 ].value ).toBe( "Hello" );
					expect( tokens[ 1 ].startPos ).toBe( 1 );
					expect( tokens[ 1 ].endPos ).toBe( 5 );
				} );

				it( "tokenizes a variable tag", function(){
					var tokens = variables.tokenizer.tokenize( "{{name}}" );

					expect( tokens ).toHaveLength( 1 );
					expect( tokens[ 1 ].type ).toBe( "variable" );
					expect( tokens[ 1 ].name ).toBe( "name" );
					expect( tokens[ 1 ].openDelimiter ).toBe( "{{" );
					expect( tokens[ 1 ].closeDelimiter ).toBe( "}}" );
				} );

				it( "tokenizes text before and after a variable tag", function(){
					var tokens = variables.tokenizer.tokenize( "Hi {{name}}!" );

					expect( tokens ).toHaveLength( 3 );
					expect( tokens[ 1 ].type ).toBe( "text" );
					expect( tokens[ 1 ].value ).toBe( "Hi " );
					expect( tokens[ 2 ].type ).toBe( "variable" );
					expect( tokens[ 2 ].name ).toBe( "name" );
					expect( tokens[ 3 ].type ).toBe( "text" );
					expect( tokens[ 3 ].value ).toBe( "!" );
				} );

				it( "tokenizes unescaped with ampersand", function(){
					var tokens = variables.tokenizer.tokenize( "{{& html}}" );

					expect( tokens ).toHaveLength( 1 );
					expect( tokens[ 1 ].type ).toBe( "unescaped" );
					expect( tokens[ 1 ].name ).toBe( "html" );
				} );

				it( "tokenizes triple mustache as unescaped", function(){
					var tokens = variables.tokenizer.tokenize( "{{{html}}}" );

					expect( tokens ).toHaveLength( 1 );
					expect( tokens[ 1 ].type ).toBe( "unescaped" );
					expect( tokens[ 1 ].name ).toBe( "html" );
				} );

				it( "tokenizes comment tags", function(){
					var tokens = variables.tokenizer.tokenize( "{{! a comment }}" );

					expect( tokens ).toHaveLength( 1 );
					expect( tokens[ 1 ].type ).toBe( "comment" );
				} );

				it( "tokenizes partial tags", function(){
					var tokens = variables.tokenizer.tokenize( "A{{> header}}B" );

					expect( tokens ).toHaveLength( 3 );
					expect( tokens[ 2 ].type ).toBe( "partial" );
					expect( tokens[ 2 ].name ).toBe( "header" );
				} );

				it( "tokenizes section start and end tags", function(){
					var tokens = variables.tokenizer.tokenize( "{{##items}}X{{/items}}" );

					expect( tokens ).toHaveLength( 3 );
					expect( tokens[ 1 ].type ).toBe( "section_start" );
					expect( tokens[ 1 ].name ).toBe( "items" );
					expect( tokens[ 3 ].type ).toBe( "section_end" );
					expect( tokens[ 3 ].name ).toBe( "items" );
				} );

				it( "tokenizes inverted section tags", function(){
					var tokens = variables.tokenizer.tokenize( "{{^empty}}fallback{{/empty}}" );

					expect( tokens ).toHaveLength( 3 );
					expect( tokens[ 1 ].type ).toBe( "inverted_start" );
					expect( tokens[ 1 ].name ).toBe( "empty" );
				} );

				it( "tokenizes block tags", function(){
					var tokens = variables.tokenizer.tokenize( "{{$title}}default{{/title}}" );

					expect( tokens ).toHaveLength( 3 );
					expect( tokens[ 1 ].type ).toBe( "block_start" );
					expect( tokens[ 1 ].name ).toBe( "title" );
				} );

				it( "tokenizes parent tags", function(){
					var tokens = variables.tokenizer.tokenize( "{{<layout}}content{{/layout}}" );

					expect( tokens ).toHaveLength( 3 );
					expect( tokens[ 1 ].type ).toBe( "parent_start" );
					expect( tokens[ 1 ].name ).toBe( "layout" );
				} );

				it( "strips ## prefix from closing tags", function(){
					var tokens = variables.tokenizer.tokenize( "{{##items}}X{{/##items}}" );

					expect( tokens[ 3 ].type ).toBe( "section_end" );
					expect( tokens[ 3 ].name ).toBe( "items" );
				} );

				it( "tokenizes set delimiter tags", function(){
					var tokens = variables.tokenizer.tokenize( "{{=<% %>=}}<%name%>" );

					expect( tokens ).toHaveLength( 2 );
					expect( tokens[ 1 ].type ).toBe( "set_delimiter" );
					expect( tokens[ 1 ].openDelimiter ).toBe( "<%" );
					expect( tokens[ 1 ].closeDelimiter ).toBe( "%>" );
					expect( tokens[ 2 ].type ).toBe( "variable" );
					expect( tokens[ 2 ].name ).toBe( "name" );
				} );

				it( "supports custom delimiters", function(){
					var tokens = variables.tokenizer.tokenize(
						template = "<%name%>",
						openDelimiter = "<%",
						closeDelimiter = "%>"
					);

					expect( tokens ).toHaveLength( 1 );
					expect( tokens[ 1 ].type ).toBe( "variable" );
					expect( tokens[ 1 ].name ).toBe( "name" );
				} );

				it( "handles standalone comment removing surrounding whitespace", function(){
					var template = "A#chr( 10 )#  {{! standalone }}#chr( 10 )#B";
					var tokens = variables.tokenizer.tokenize( template );

					expect( tokens ).toHaveLength( 3 );
					expect( tokens[ 1 ].type ).toBe( "text" );
					expect( tokens[ 1 ].value ).toBe( "A#chr( 10 )#" );
					expect( tokens[ 2 ].type ).toBe( "comment" );
					expect( tokens[ 3 ].type ).toBe( "text" );
					expect( tokens[ 3 ].value ).toBe( "B" );
				} );

				it( "assigns indent to standalone partial tags", function(){
					var template = "  {{> partial}}#chr( 10 )#";
					var tokens = variables.tokenizer.tokenize( template );

					var partialToken = {};
					for ( var t in tokens ) {
						if ( t.type == "partial" ) {
							partialToken = t;
							break;
						}
					}

					expect( partialToken ).toHaveKey( "indent" );
					expect( partialToken.indent ).toBe( "  " );
				} );

				it( "throws on unclosed tag", function(){
					expect( function(){
						variables.tokenizer.tokenize( "Hello {{name" );
					} ).toThrow( type = "Stubble.Tokenizer" );
				} );

				it( "throws on unclosed triple mustache", function(){
					expect( function(){
						variables.tokenizer.tokenize( "Hello {{{name}}" );
					} ).toThrow( type = "Stubble.Tokenizer" );
				} );

				it( "throws on invalid set delimiter tag", function(){
					expect( function(){
						variables.tokenizer.tokenize( "{{=bad=}}" );
					} ).toThrow( type = "Stubble.Tokenizer" );
				} );

				it( "tokenizes multiple adjacent tags", function(){
					var tokens = variables.tokenizer.tokenize( "{{a}}{{b}}{{c}}" );

					expect( tokens ).toHaveLength( 3 );
					expect( tokens[ 1 ].name ).toBe( "a" );
					expect( tokens[ 2 ].name ).toBe( "b" );
					expect( tokens[ 3 ].name ).toBe( "c" );
				} );

				it( "preserves position information", function(){
					var tokens = variables.tokenizer.tokenize( "AB{{x}}CD" );

					expect( tokens[ 1 ].startPos ).toBe( 1 );
					expect( tokens[ 1 ].endPos ).toBe( 2 );
					expect( tokens[ 2 ].startPos ).toBe( 3 );
					expect( tokens[ 2 ].endPos ).toBe( 7 );
					expect( tokens[ 3 ].startPos ).toBe( 8 );
					expect( tokens[ 3 ].endPos ).toBe( 9 );
				} );
			} );
		} );
	}
}
