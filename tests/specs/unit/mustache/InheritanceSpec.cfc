/**
 * Mustache inheritance compliance BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Mustache inheritance spec", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "Default: Default content should be rendered if the block isn't overridden", function(){
				var output = variables.stubble.render(
					"{{$title}}Default title{{/title}}" & chr( 10 ),
					{}
				);

				expect( output ).toBe( "Default title" & chr( 10 ) );
			} );

			it( "Variable: Default content renders variables", function(){
				var output = variables.stubble.render(
					"{{$foo}}default {{bar}} content{{/foo}}" & chr( 10 ),
					{ bar: "baz" }
				);

				expect( output ).toBe( "default baz content" & chr( 10 ) );
			} );

			it( "Triple Mustache: Default content renders triple mustache variables", function(){
				var output = variables.stubble.render(
					"{{$foo}}default {{{bar}}} content{{/foo}}" & chr( 10 ),
					{ bar: "<baz>" }
				);

				expect( output ).toBe( "default <baz> content" & chr( 10 ) );
			} );

			it( "Sections: Default content renders sections", function(){
				var output = variables.stubble.render(
					"{{$foo}}default {{##bar}}{{baz}}{{/bar}} content{{/foo}}" & chr( 10 ),
					{ bar: { baz: "qux" } }
				);

				expect( output ).toBe( "default qux content" & chr( 10 ) );
			} );

			it( "Negative Sections: Default content renders negative sections", function(){
				var output = variables.stubble.render(
					"{{$foo}}default {{^bar}}{{baz}}{{/bar}} content{{/foo}}" & chr( 10 ),
					{ baz: "three" }
				);

				expect( output ).toBe( "default three content" & chr( 10 ) );
			} );

			it( "Mustache Injection: Mustache injection in default content", function(){
				var output = variables.stubble.render(
					"{{$foo}}default {{##bar}}{{baz}}{{/bar}} content{{/foo}}" & chr( 10 ),
					{ bar: { baz: "{{qux}}" } }
				);

				expect( output ).toBe( "default {{qux}} content" & chr( 10 ) );
			} );

			it( "Inherit: Default content rendered inside inherited templates", function(){
				var output = variables.stubble.render(
					"{{<include}}{{/include}}" & chr( 10 ),
					{},
					{ include: "{{$foo}}default content{{/foo}}" }
				);

				expect( output ).toBe( "default content" );
			} );

			it( "Overridden content: Overridden content", function(){
				var output = variables.stubble.render(
					"{{<super}}{{$title}}sub template title{{/title}}{{/super}}",
					{},
					{ super: "...{{$title}}Default title{{/title}}..." }
				);

				expect( output ).toBe( "...sub template title..." );
			} );

			it( "Data does not override block: Context does not override argument passed into parent", function(){
				var output = variables.stubble.render(
					"{{<include}}{{$var}}var in template{{/var}}{{/include}}",
					{ var: "var in data" },
					{ include: "{{$var}}var in include{{/var}}" }
				);

				expect( output ).toBe( "var in template" );
			} );

			it( "Data does not override block default: Context does not override default content of block", function(){
				var output = variables.stubble.render(
					"{{<include}}{{/include}}",
					{ var: "var in data" },
					{ include: "{{$var}}var in include{{/var}}" }
				);

				expect( output ).toBe( "var in include" );
			} );

			it( "Overridden parent: Overridden parent", function(){
				var output = variables.stubble.render(
					"test {{<parent}}{{$stuff}}override{{/stuff}}{{/parent}}",
					{},
					{ parent: "{{$stuff}}...{{/stuff}}" }
				);

				expect( output ).toBe( "test override" );
			} );

			it( "Two overridden parents: Two overridden parents with different content", function(){
				var output = variables.stubble.render(
					"test {{<parent}}{{$stuff}}override1{{/stuff}}{{/parent}} {{<parent}}{{$stuff}}override2{{/stuff}}{{/parent}}" & chr( 10 ),
					{},
					{ parent: "|{{$stuff}}...{{/stuff}}{{$default}} default{{/default}}|" }
				);

				expect( output ).toBe( "test |override1 default| |override2 default|" & chr( 10 ) );
			} );

			it( "Override parent with newlines: Override parent with newlines", function(){
				var output = variables.stubble.render(
					"{{<parent}}{{$ballmer}}" & chr( 10 ) & "peaked" & chr( 10 ) & chr( 10 ) & ":(" & chr( 10 ) & "{{/ballmer}}{{/parent}}",
					{},
					{ parent: "{{$ballmer}}peaking{{/ballmer}}" }
				);

				expect( output ).toBe( "peaked" & chr( 10 ) & chr( 10 ) & ":(" & chr( 10 ) );
			} );

			it( "Inherit indentation: Inherit indentation when overriding a parent", function(){
				var output = variables.stubble.render(
					"{{<parent}}{{$nineties}}hammer time{{/nineties}}{{/parent}}",
					{},
					{ parent: "stop:" & chr( 10 ) & "  {{$nineties}}collaborate and listen{{/nineties}}" & chr( 10 ) }
				);

				expect( output ).toBe( "stop:" & chr( 10 ) & "  hammer time" & chr( 10 ) );
			} );

			it( "Only one override: Override one parameter but not the other", function(){
				var output = variables.stubble.render(
					"{{<parent}}{{$stuff2}}override two{{/stuff2}}{{/parent}}",
					{},
					{ parent: "{{$stuff}}new default one{{/stuff}}, {{$stuff2}}new default two{{/stuff2}}" }
				);

				expect( output ).toBe( "new default one, override two" );
			} );

			it( "Parent template: Parent templates behave identically to partials when called with no parameters", function(){
				var output = variables.stubble.render(
					"{{>parent}}|{{<parent}}{{/parent}}",
					{},
					{ parent: "{{$foo}}default content{{/foo}}" }
				);

				expect( output ).toBe( "default content|default content" );
			} );

			it( "Recursion: Recursion in inherited templates", function(){
				var output = variables.stubble.render(
					"{{<parent}}{{$foo}}override{{/foo}}{{/parent}}",
					{},
					{
						parent: "{{$foo}}default content{{/foo}} {{$bar}}{{<parent2}}{{/parent2}}{{/bar}}",
						parent2: "{{$foo}}parent2 default content{{/foo}} {{<parent}}{{$bar}}don't recurse{{/bar}}{{/parent}}"
					}
				);

				expect( output ).toBe( "override override override don't recurse" );
			} );

			it( "Multi-level inheritance: Top-level substitutions take precedence in multi-level inheritance", function(){
				var output = variables.stubble.render(
					"{{<parent}}{{$a}}c{{/a}}{{/parent}}",
					{},
					{
						parent: "{{<older}}{{$a}}p{{/a}}{{/older}}",
						older: "{{<grandParent}}{{$a}}o{{/a}}{{/grandParent}}",
						grandParent: "{{$a}}g{{/a}}"
					}
				);

				expect( output ).toBe( "c" );
			} );

			it( "Multi-level inheritance, no sub child: Top-level substitutions take precedence in multi-level inheritance", function(){
				var output = variables.stubble.render(
					"{{<parent}}{{/parent}}",
					{},
					{
						parent: "{{<older}}{{$a}}p{{/a}}{{/older}}",
						older: "{{<grandParent}}{{$a}}o{{/a}}{{/grandParent}}",
						grandParent: "{{$a}}g{{/a}}"
					}
				);

				expect( output ).toBe( "p" );
			} );

			it( "Text inside parent: Ignores text inside parent templates, but does parse $ tags", function(){
				var output = variables.stubble.render(
					"{{<parent}} asdfasd {{$foo}}hmm{{/foo}} asdfasdfasdf {{/parent}}",
					{},
					{ parent: "{{$foo}}default content{{/foo}}" }
				);

				expect( output ).toBe( "hmm" );
			} );

			it( "Text inside parent: Allows text inside a parent tag, but ignores it", function(){
				var output = variables.stubble.render(
					"{{<parent}} asdfasd asdfasdfasdf {{/parent}}",
					{},
					{ parent: "{{$foo}}default content{{/foo}}" }
				);

				expect( output ).toBe( "default content" );
			} );

			it( "Block scope: Scope of a substituted block is evaluated in the context of the parent template", function(){
				var output = variables.stubble.render(
					"{{<parent}}{{$block}}I say {{fruit}}.{{/block}}{{/parent}}",
					{
						fruit: "apples",
						nested: { fruit: "bananas" }
					},
					{ parent: "{{##nested}}{{$block}}You say {{fruit}}.{{/block}}{{/nested}}" }
				);

				expect( output ).toBe( "I say bananas." );
			} );

			it( "Standalone parent: A parent's opening and closing tags need not be on separate lines in order to be standalone", function(){
				var output = variables.stubble.render(
					"Hi," & chr( 10 ) & "  {{<parent}}{{/parent}}" & chr( 10 ),
					{},
					{ parent: "one" & chr( 10 ) & "two" & chr( 10 ) }
				);

				expect( output ).toBe( "Hi," & chr( 10 ) & "  one" & chr( 10 ) & "  two" & chr( 10 ) );
			} );

			it( "Standalone block: A block's opening and closing tags need not be on separate lines in order to be standalone", function(){
				var output = variables.stubble.render(
					"{{<parent}}{{$block}}" & chr( 10 ) & "one" & chr( 10 ) & "two{{/block}}" & chr( 10 ) & "{{/parent}}" & chr( 10 ),
					{},
					{ parent: "Hi," & chr( 10 ) & "  {{$block}}{{/block}}" & chr( 10 ) }
				);

				expect( output ).toBe( "Hi," & chr( 10 ) & "  one" & chr( 10 ) & "  two" & chr( 10 ) );
			} );

			it( "Block reindentation: Block indentation is removed at the site of definition and added at the site of expansion", function(){
				var output = variables.stubble.render(
					"{{<parent}}{{$block}}" & chr( 10 ) & "    one" & chr( 10 ) & "    two" & chr( 10 ) & "{{/block}}{{/parent}}" & chr( 10 ),
					{},
					{ parent: "Hi," & chr( 10 ) & "  {{$block}}" & chr( 10 ) & "  {{/block}}" & chr( 10 ) }
				);

				expect( output ).toBe( "Hi," & chr( 10 ) & "  one" & chr( 10 ) & "  two" & chr( 10 ) );
			} );

			it( "Intrinsic indentation: When the block opening tag is standalone, indentation is determined by default content", function(){
				var output = variables.stubble.render(
					"{{<parent}}{{$block}}" & chr( 10 ) & "one" & chr( 10 ) & "two" & chr( 10 ) & "{{/block}}{{/parent}}" & chr( 10 ),
					{},
					{ parent: "Hi," & chr( 10 ) & "{{$block}}" & chr( 10 ) & "  default" & chr( 10 ) & "{{/block}}" & chr( 10 ) }
				);

				expect( output ).toBe( "Hi," & chr( 10 ) & "  one" & chr( 10 ) & "  two" & chr( 10 ) );
			} );

			it( "Nested block reindentation: Nested blocks are reindented relative to the surrounding block", function(){
				var output = variables.stubble.render(
					"{{<parent}}{{$nested}}" & chr( 10 ) & "three" & chr( 10 ) & "{{/nested}}{{/parent}}" & chr( 10 ),
					{},
					{
						parent: "{{<grandparent}}{{$block}}" & chr( 10 ) & "  one" & chr( 10 ) & "  {{$nested}}" & chr( 10 ) & "    two" & chr( 10 ) & "  {{/nested}}" & chr( 10 ) & "{{/block}}{{/grandparent}}" & chr( 10 ),
						grandparent: "{{$block}}default{{/block}}"
					}
				);

				expect( output ).toBe( "one" & chr( 10 ) & "  three" & chr( 10 ) );
			} );
		} );
	}
}
