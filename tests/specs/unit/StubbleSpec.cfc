/**
 * Stubble BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Stubble", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "Stubble" );
			} );

			describe( "tokenize()", function(){
				it( "tokenizes plain text with no tags", function(){
					var tokens = variables.stubble.tokenize( "Hello" );

					expect( tokens ).toHaveLength( 1 );
					expect( tokens[ 1 ].type ).toBe( "text" );
					expect( tokens[ 1 ].value ).toBe( "Hello" );
					expect( tokens[ 1 ].startPos ).toBe( 1 );
					expect( tokens[ 1 ].endPos ).toBe( 5 );
				} );

				it( "tokenizes comments, partials, sections, and inverted tags", function(){
					var template = "{{! note}}{{> row}}{{$items}}A{{/items}}{{^empty}}B{{/empty}}";
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

				it( "supports closing tags with /$name shorthand", function(){
					var tokens = variables.stubble.tokenize( "{{$items}}X{{/$items}}" );

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

			describe( "parse()", function(){
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
					var template = "{{$people}}- {{name}}{{/people}}";
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
					var template = "{{$a}}{{/a}}";
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
					var template = "{{$a}}x{{/b}}";
					expect( function(){
						variables.stubble.parse( variables.stubble.tokenize( template ), template );
					} ).toThrow( type = "Stubble.Parser" );
				} );

				it( "throws on unclosed sections", function(){
					var template = "{{$a}}x";
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

			describe( "render()", function(){
				it( "escapes variables and preserves unescaped output", function(){
					var output = variables.stubble.render(
						"{{html}}|{{{html}}}|{{& html}}",
						{ html: "<b>x</b>" }
					);

					expect( output ).toBe( "&lt;b&gt;x&lt;/b&gt;|<b>x</b>|<b>x</b>" );
				} );

				it( "escapes ampersands, angle brackets, quotes, and apostrophes", function(){
					var raw = '&<>"' & chr( 39 );
					var output = variables.stubble.render(
						"{{html}}",
						{ html: raw }
					);

					expect( output ).toBe( "&amp;&lt;&gt;&quot;&##39;" );
				} );

				it( "renders dotted paths and numeric array indexes", function(){
					var output = variables.stubble.render(
						"{{user.name}}|{{users.2.name}}",
						{
							user: { name: "Ada" },
							users: [
								{ name: "Grace" },
								{ name: "Linus" }
							]
						}
					);

					expect( output ).toBe( "Ada|Linus" );
				} );

				it( "resolves values from CFC objects via dynamic path lookup", function(){
					var person = createObject( "component", "tests.resources.DynamicLookupFixture" )
						.init( "Ada", "Architect" );
					var output = variables.stubble.render(
						"{{person.name}}|{{person.role}}|{{person.missing}}",
						{ person: person }
					);

					expect( output ).toBe( "Ada|Architect|" );
				} );

				it( "falls back to parent context when a key is missing in the current item", function(){
					var output = variables.stubble.render(
						"{{$people}}{{name}}-{{title}};{{/people}}",
						{
							title: "Team",
							people: [
								{ name: "Ada" },
								{ name: "Linus" }
							]
						}
					);

					expect( output ).toBe( "Ada-Team;Linus-Team;" );
				} );

				it( "uses current context with dot lookups inside array sections", function(){
					var output = variables.stubble.render(
						"{{$items}}({{.}}){{/items}}",
						{ items: [ "a", "b", "c" ] }
					);

					expect( output ).toBe( "(a)(b)(c)" );
				} );

				it( "renders sections for struct contexts", function(){
					var output = variables.stubble.render(
						"{{$person}}{{name}}:{{role}}{{/person}}",
						{ person: { name: "Ada", role: "Engineer" } }
					);

					expect( output ).toBe( "Ada:Engineer" );
				} );

				it( "honors falsey values and inverted sections", function(){
					var output = variables.stubble.render(
						"{{$count}}C{{/count}}|{{$empty}}E{{/empty}}|{{^count}}NC{{/count}}|{{^empty}}NE{{/empty}}",
						{ count: 0, empty: "" }
					);

					expect( output ).toBe( "||NC|NE" );
				} );

				it( "handles empty arrays for sections and inverted sections", function(){
					var output = variables.stubble.render(
						"{{$items}}X{{/items}}|{{^items}}Y{{/items}}",
						{ items: [] }
					);

					expect( output ).toBe( "|Y" );
				} );

				it( "ignores comments and missing partials during rendering", function(){
					var output = variables.stubble.render(
						"A{{! comment }}{{> missing}}B",
						{},
						{}
					);

					expect( output ).toBe( "AB" );
				} );

				it( "renders partials from string and closure values", function(){
					var fromString = variables.stubble.render(
						"User: {{> row}}",
						{ name: "Ada" },
						{ row: "{{name}}" }
					);

					var fromClosure = variables.stubble.render(
						"User: {{> row}}",
						{ name: "Linus" },
						{
							row: function(){
								return "{{name}}";
							}
						}
					);

					expect( fromString ).toBe( "User: Ada" );
					expect( fromClosure ).toBe( "User: Linus" );
				} );

				it( "supports variable lambdas with arity 0 and 1", function(){
					var output = variables.stubble.render(
						"{{calc}}|{{greet}}|{{templateValue}}",
						{
							name: "Stubble",
							calc: function(){
								return 2 + 2;
							},
							greet: function( context ){
								return "Hi " & arguments.context.name;
							},
							templateValue: function(){
								return "{{name}}";
							}
						}
					);

					expect( output ).toBe( "4|Hi Stubble|Stubble" );
				} );

				it( "supports section lambdas with arity 0, 1, and 2", function(){
					var output = variables.stubble.render(
						"{{$zero}}x{{/zero}}|{{$one}}Hi {{name}}{{/one}}|{{$two}}Hi {{name}}{{/two}}",
						{
							name: "Ada",
							zero: function(){
								return "{{name}}";
							},
							one: function( text ){
								return "<" & arguments.text & ">";
							},
							two: function( text, renderer ){
								return "[" & arguments.renderer( arguments.text ) & "]";
							}
						}
					);

					expect( output ).toBe( "Ada|<Hi Ada>|[Hi Ada]" );
				} );

				it( "returns empty output for missing variables and sections", function(){
					var output = variables.stubble.render(
						"A{{missing}}B{{$unknown}}X{{/unknown}}C",
						{}
					);

					expect( output ).toBe( "ABC" );
				} );
			} );

			describe( "cache controls", function(){
				it( "reports default cache stats", function(){
					var stats = variables.stubble.getCacheStats();

					expect( stats ).toHaveKey( "enabled" );
					expect( stats ).toHaveKey( "maxEntries" );
					expect( stats ).toHaveKey( "currentEntries" );
					expect( stats.enabled ).toBeTrue();
					expect( stats.maxEntries ).toBe( 200 );
					expect( stats.currentEntries ).toBe( 0 );
				} );

				it( "enforces a minimum cache size of 1", function(){
					variables.stubble.configureCache( enabled = true, maxEntries = 0 );
					var stats = variables.stubble.getCacheStats();

					expect( stats.maxEntries ).toBe( 1 );
				} );

				it( "caches parsed templates by template text", function(){
					variables.stubble.render( "Hello {{name}}", { name: "Ada" } );
					var firstStats = variables.stubble.getCacheStats();

					variables.stubble.render( "Hello {{name}}", { name: "Linus" } );
					var secondStats = variables.stubble.getCacheStats();

					expect( firstStats.currentEntries ).toBe( 1 );
					expect( secondStats.currentEntries ).toBe( 1 );
				} );

				it( "can disable cache and avoid storing parsed templates", function(){
					variables.stubble.render( "A {{name}}", { name: "Ada" } );
					variables.stubble.configureCache( enabled = false );

					var disabledStats = variables.stubble.getCacheStats();
					expect( disabledStats.enabled ).toBeFalse();
					expect( disabledStats.currentEntries ).toBe( 0 );

					variables.stubble.render( "B {{name}}", { name: "Ada" } );
					var afterRenderStats = variables.stubble.getCacheStats();
					expect( afterRenderStats.currentEntries ).toBe( 0 );
				} );

				it( "evicts least recently used templates when max entries is exceeded", function(){
					variables.stubble.configureCache( enabled = true, maxEntries = 1 );

					variables.stubble.render( "One {{name}}", { name: "Ada" } );
					variables.stubble.render( "Two {{name}}", { name: "Ada" } );
					var stats = variables.stubble.getCacheStats();

					expect( stats.maxEntries ).toBe( 1 );
					expect( stats.currentEntries ).toBe( 1 );
				} );

				it( "clears cache entries manually", function(){
					variables.stubble.render( "Hello {{name}}", { name: "Ada" } );
					variables.stubble.clearCache();

					var stats = variables.stubble.getCacheStats();
					expect( stats.currentEntries ).toBe( 0 );
				} );
			} );
		} );
	}
}
