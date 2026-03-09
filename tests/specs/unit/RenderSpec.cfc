/**
 * Stubble render() BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Stubble render()", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "escapes variables and preserves unescaped output", function(){
				var output = variables.stubble.render(
					"{{html}}|{{{html}}}|{{& html}}",
					{ html: "<b>x</b>" }
				);

				expect( output ).toBe( "&lt;b&gt;x&lt;&##x2f;b&gt;|<b>x</b>|<b>x</b>" );
			} );

			it( "escapes ampersands, angle brackets, quotes, and apostrophes", function(){
				var raw = '&<>"' & chr( 39 );
				var output = variables.stubble.render(
					"{{html}}",
					{ html: raw }
				);

				expect( output ).toBe( "&amp;&lt;&gt;&quot;&##x27;" );
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

			it( "rethrows object accessor errors instead of treating them as missing values", function(){
				var mockObject = {
					getCoolThing: () => {
						throw( type = "Stubble.MockError", message = "Mock Error!" );
					}
				};

				expect( function(){
					variables.stubble.render(
						"{{action.getCoolThing}}",
						{ action: mockObject }
					);
				} ).toThrow( type = "Stubble.MockError", message = "MockError!" );
			} );

			it( "falls back to parent context when a key is missing in the current item", function(){
				var output = variables.stubble.render(
					"{{##people}}{{name}}-{{title}};{{/people}}",
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
					"{{##items}}({{.}}){{/items}}",
					{ items: [ "a", "b", "c" ] }
				);

				expect( output ).toBe( "(a)(b)(c)" );
			} );

			it( "renders sections for struct contexts", function(){
				var output = variables.stubble.render(
					"{{##person}}{{name}}:{{role}}{{/person}}",
					{ person: { name: "Ada", role: "Engineer" } }
				);

				expect( output ).toBe( "Ada:Engineer" );
			} );

			it( "honors falsey values and inverted sections", function(){
				var output = variables.stubble.render(
					"{{##count}}C{{/count}}|{{##empty}}E{{/empty}}|{{^count}}NC{{/count}}|{{^empty}}NE{{/empty}}",
					{ count: 0, empty: "" }
				);

				expect( output ).toBe( "||NC|NE" );
			} );

			it( "handles empty arrays for sections and inverted sections", function(){
				var output = variables.stubble.render(
					"{{##items}}X{{/items}}|{{^items}}Y{{/items}}",
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
					"{{##zero}}x{{/zero}}|{{##one}}Hi {{name}}{{/one}}|{{##two}}Hi {{name}}{{/two}}",
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
					"A{{missing}}B{{##unknown}}X{{/unknown}}C",
					{}
				);

				expect( output ).toBe( "ABC" );
			} );
		} );
	}
}
