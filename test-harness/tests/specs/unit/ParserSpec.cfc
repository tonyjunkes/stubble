/**
 * Parser BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Parser", function(){
			beforeEach( function(){
				variables.parser = createObject( "component", "models.Parser" );
			} );

			describe( "parse()", function(){
				it( "returns empty array for empty token list", function(){
					var ast = variables.parser.parse( [], "" );
					expect( ast ).toBeEmpty();
				} );

				it( "parses text tokens", function(){
					var tokens = [
						{ type: "text", value: "Hello World", startPos: 1, endPos: 11 }
					];
					var ast = variables.parser.parse( tokens, "Hello World" );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].type ).toBe( "text" );
					expect( ast[ 1 ].value ).toBe( "Hello World" );
				} );

				it( "parses variable tokens with name parts", function(){
					var tokens = [
						{ type: "variable", name: "user.name", startPos: 1, endPos: 13 }
					];
					var ast = variables.parser.parse( tokens, "{{user.name}}" );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].type ).toBe( "variable" );
					expect( ast[ 1 ].name ).toBe( "user.name" );
					expect( ast[ 1 ].nameParts ).toHaveLength( 2 );
					expect( ast[ 1 ].nameParts[ 1 ] ).toBe( "user" );
					expect( ast[ 1 ].nameParts[ 2 ] ).toBe( "name" );
				} );

				it( "parses unescaped tokens", function(){
					var tokens = [
						{ type: "unescaped", name: "html", startPos: 1, endPos: 10 }
					];
					var ast = variables.parser.parse( tokens, "{{& html}}" );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].type ).toBe( "unescaped" );
					expect( ast[ 1 ].name ).toBe( "html" );
					expect( ast[ 1 ].nameParts ).toHaveLength( 1 );
					expect( ast[ 1 ].nameParts[ 1 ] ).toBe( "html" );
				} );

				it( "parses partial tokens without indent", function(){
					var tokens = [
						{ type: "partial", name: "header", startPos: 1, endPos: 14 }
					];
					var ast = variables.parser.parse( tokens, "{{> header}}" );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].type ).toBe( "partial" );
					expect( ast[ 1 ].name ).toBe( "header" );
					expect( ast[ 1 ].indent ).toBe( "" );
				} );

				it( "parses partial tokens with indent", function(){
					var tokens = [
						{ type: "partial", name: "header", indent: "  ", startPos: 3, endPos: 16 }
					];
					var ast = variables.parser.parse( tokens, "  {{> header}}" );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].indent ).toBe( "  " );
				} );

				it( "skips comment tokens", function(){
					var tokens = [
						{ type: "text", value: "A", startPos: 1, endPos: 1 },
						{ type: "comment", name: "ignore", startPos: 2, endPos: 15 },
						{ type: "text", value: "B", startPos: 16, endPos: 16 }
					];
					var ast = variables.parser.parse( tokens, "A{{! ignore }}B" );

					expect( ast ).toHaveLength( 2 );
					expect( ast[ 1 ].type ).toBe( "text" );
					expect( ast[ 2 ].type ).toBe( "text" );
				} );

				it( "skips set_delimiter tokens", function(){
					var tokens = [
						{
							type: "set_delimiter",
							name: "=<% %>=",
							openDelimiter: "<%",
							closeDelimiter: "%>",
							startPos: 1,
							endPos: 15
						},
						{ type: "text", value: "hello", startPos: 16, endPos: 20 }
					];
					var ast = variables.parser.parse( tokens, "{{=<% %>=}}hello" );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].type ).toBe( "text" );
				} );

				it( "parses section with children and rawText", function(){
					var template = "{{##items}}content{{/items}}";
					var tokens = [
						{
							type: "section_start", name: "items",
							openDelimiter: "{{", closeDelimiter: "}}",
							startPos: 1, endPos: 10
						},
						{ type: "text", value: "content", startPos: 11, endPos: 17 },
						{ type: "section_end", name: "items", startPos: 18, endPos: 27 }
					];
					var ast = variables.parser.parse( tokens, template );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].type ).toBe( "section" );
					expect( ast[ 1 ].name ).toBe( "items" );
					expect( ast[ 1 ].rawText ).toBe( "content" );
					expect( ast[ 1 ].children ).toHaveLength( 1 );
					expect( ast[ 1 ].children[ 1 ].type ).toBe( "text" );
					expect( ast[ 1 ].children[ 1 ].value ).toBe( "content" );
				} );

				it( "captures render delimiters on section nodes", function(){
					var template = "{{##a}}x{{/a}}";
					var tokens = [
						{
							type: "section_start", name: "a",
							openDelimiter: "{{", closeDelimiter: "}}",
							startPos: 1, endPos: 6
						},
						{ type: "text", value: "x", startPos: 7, endPos: 7 },
						{ type: "section_end", name: "a", startPos: 8, endPos: 13 }
					];
					var ast = variables.parser.parse( tokens, template );

					expect( ast[ 1 ] ).toHaveKey( "renderOpenDelimiter" );
					expect( ast[ 1 ] ).toHaveKey( "renderCloseDelimiter" );
					expect( ast[ 1 ].renderOpenDelimiter ).toBe( "{{" );
					expect( ast[ 1 ].renderCloseDelimiter ).toBe( "}}" );
				} );

				it( "parses inverted sections", function(){
					var template = "{{^empty}}fallback{{/empty}}";
					var tokens = [
						{
							type: "inverted_start", name: "empty",
							openDelimiter: "{{", closeDelimiter: "}}",
							startPos: 1, endPos: 10
						},
						{ type: "text", value: "fallback", startPos: 11, endPos: 18 },
						{ type: "section_end", name: "empty", startPos: 19, endPos: 28 }
					];
					var ast = variables.parser.parse( tokens, template );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].type ).toBe( "inverted" );
					expect( ast[ 1 ].name ).toBe( "empty" );
					expect( ast[ 1 ].rawText ).toBe( "fallback" );
				} );

				it( "parses empty sections with empty rawText", function(){
					var template = "{{##a}}{{/a}}";
					var tokens = [
						{
							type: "section_start", name: "a",
							openDelimiter: "{{", closeDelimiter: "}}",
							startPos: 1, endPos: 6
						},
						{ type: "section_end", name: "a", startPos: 7, endPos: 12 }
					];
					var ast = variables.parser.parse( tokens, template );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].rawText ).toBe( "" );
					expect( ast[ 1 ].children ).toBeEmpty();
				} );

				it( "parses nested sections", function(){
					var template = "{{##a}}{{##b}}x{{/b}}{{/a}}";
					var tokens = [
						{ type: "section_start", name: "a", openDelimiter: "{{", closeDelimiter: "}}", startPos: 1, endPos: 6 },
						{ type: "section_start", name: "b", openDelimiter: "{{", closeDelimiter: "}}", startPos: 7, endPos: 12 },
						{ type: "text", value: "x", startPos: 13, endPos: 13 },
						{ type: "section_end", name: "b", startPos: 14, endPos: 19 },
						{ type: "section_end", name: "a", startPos: 20, endPos: 25 }
					];
					var ast = variables.parser.parse( tokens, template );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].type ).toBe( "section" );
					expect( ast[ 1 ].children ).toHaveLength( 1 );
					expect( ast[ 1 ].children[ 1 ].type ).toBe( "section" );
					expect( ast[ 1 ].children[ 1 ].name ).toBe( "b" );
				} );

				it( "throws on closing tag without opening", function(){
					var tokens = [
						{ type: "section_end", name: "people", startPos: 1, endPos: 12 }
					];
					expect( function(){
						variables.parser.parse( tokens, "{{/people}}" );
					} ).toThrow( type = "Stubble.ParserSectionException" );
				} );

				it( "throws on section name mismatch", function(){
					var tokens = [
						{ type: "section_start", name: "a", openDelimiter: "{{", closeDelimiter: "}}", startPos: 1, endPos: 6 },
						{ type: "section_end", name: "b", startPos: 7, endPos: 12 }
					];
					expect( function(){
						variables.parser.parse( tokens, "{{##a}}{{/b}}" );
					} ).toThrow( type = "Stubble.ParserSectionException" );
				} );

				it( "throws on unclosed section", function(){
					var tokens = [
						{ type: "section_start", name: "a", openDelimiter: "{{", closeDelimiter: "}}", startPos: 1, endPos: 6 },
						{ type: "text", value: "x", startPos: 7, endPos: 7 }
					];
					expect( function(){
						variables.parser.parse( tokens, "{{##a}}x" );
					} ).toThrow( type = "Stubble.ParserSectionException" );
				} );

				it( "throws on unsupported token type", function(){
					expect( function(){
						variables.parser.parse( [ { type: "bogus" } ], "" );
					} ).toThrow( type = "Stubble.ParserTokenException" );
				} );

				it( "parses block container nodes", function(){
					var template = "{{$title}}Default{{/title}}";
					var tokens = [
						{ type: "block_start", name: "title", startPos: 1, endPos: 10 },
						{ type: "text", value: "Default", startPos: 11, endPos: 17 },
						{ type: "section_end", name: "title", startPos: 18, endPos: 27 }
					];
					var ast = variables.parser.parse( tokens, template );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].type ).toBe( "block" );
					expect( ast[ 1 ].name ).toBe( "title" );
				} );

				it( "parses parent container nodes", function(){
					var template = "{{<layout}}content{{/layout}}";
					var tokens = [
						{ type: "parent_start", name: "layout", startPos: 1, endPos: 11 },
						{ type: "text", value: "content", startPos: 12, endPos: 18 },
						{ type: "section_end", name: "layout", startPos: 19, endPos: 29 }
					];
					var ast = variables.parser.parse( tokens, template );

					expect( ast ).toHaveLength( 1 );
					expect( ast[ 1 ].type ).toBe( "parent" );
					expect( ast[ 1 ].name ).toBe( "layout" );
				} );
			} );

			describe( "buildNameParts()", function(){
				it( "returns single dot for dot name", function(){
					var parts = variables.parser.buildNameParts( "." );
					expect( parts ).toHaveLength( 1 );
					expect( parts[ 1 ] ).toBe( "." );
				} );

				it( "returns single element for simple name", function(){
					var parts = variables.parser.buildNameParts( "name" );
					expect( parts ).toHaveLength( 1 );
					expect( parts[ 1 ] ).toBe( "name" );
				} );

				it( "splits dotted names into parts", function(){
					var parts = variables.parser.buildNameParts( "a.b.c" );
					expect( parts ).toHaveLength( 3 );
					expect( parts[ 1 ] ).toBe( "a" );
					expect( parts[ 2 ] ).toBe( "b" );
					expect( parts[ 3 ] ).toBe( "c" );
				} );

				it( "handles two-level dotted names", function(){
					var parts = variables.parser.buildNameParts( "user.name" );
					expect( parts ).toHaveLength( 2 );
					expect( parts[ 1 ] ).toBe( "user" );
					expect( parts[ 2 ] ).toBe( "name" );
				} );
			} );
		} );
	}
}
