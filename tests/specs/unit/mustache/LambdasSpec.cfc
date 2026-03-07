/**
 * Mustache lambdas compliance BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Mustache lambdas spec", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "Interpolation: A lambda's return value should be interpolated.", function(){
				var output = variables.stubble.render(
					"Hello, {{lambda}}!",
					{
						lambda: () => {
							return "world";
						}
					}
				);

				expect( output ).toBe( "Hello, world!" );
			} );

			it( "Interpolation - Expansion: A lambda's return value should be parsed.", function(){
				var output = variables.stubble.render(
					"Hello, {{lambda}}!",
					{
						planet: "world",
						lambda: function(){
							return "{{planet}}";
						}
					}
				);

				expect( output ).toBe( "Hello, world!" );
			} );

			it( "Interpolation - Alternate Delimiters: A lambda's return value should parse with the default delimiters.", function(){
				var template = "{{= | | =}}" & chr( 10 ) & "Hello, (|&lambda|)!";
				var output = variables.stubble.render(
					template,
					{
						planet: "world",
						lambda: () => {
							return "|planet| => {{planet}}";
						}
					}
				);

				expect( output ).toBe( "Hello, (|planet| => world)!" );
			} );

			it( "Interpolation - Multiple Calls: Interpolated lambdas should not be cached.", function(){
				var callCount = 0;
				var output = variables.stubble.render(
					"{{lambda}} == {{{lambda}}} == {{lambda}}",
					{
						lambda: function(){
							callCount++;
							return callCount;
						}
					}
				);

				expect( output ).toBe( "1 == 2 == 3" );
			} );

			it( "Escaping: Lambda results should be appropriately escaped.", function(){
				var output = variables.stubble.render(
					"<{{lambda}}{{{lambda}}}",
					{
						lambda: () => {
							return ">";
						}
					}
				);

				expect( output ).toBe( "<&gt;>" );
			} );

			it( "Section: Lambdas used for sections should receive the raw section string.", function(){
				var output = variables.stubble.render(
					"<{{##lambda}}{{x}}{{/lambda}}>",
					{
						x: "Error!",
						lambda: function( text ){
							return arguments.text == "{{x}}" ? "yes" : "no";
						}
					}
				);

				expect( output ).toBe( "<yes>" );
			} );

			it( "Section - Expansion: Lambdas used for sections should have their results parsed.", function(){
				var output = variables.stubble.render(
					"<{{##lambda}}-{{/lambda}}>",
					{
						planet: "Earth",
						lambda: ( text ) => {
							return text & "{{planet}}" & text;
						}
					}
				);

				expect( output ).toBe( "<-Earth->" );
			} );

			it( "Section - Alternate Delimiters: Lambdas used for sections should parse with the current delimiters.", function(){
				var output = variables.stubble.render(
					"{{= | | =}}<|##lambda|-|/lambda|>",
					{
						planet: "Earth",
						lambda: function( text ){
							return arguments.text & "{{planet}} => |planet|" & arguments.text;
						}
					}
				);

				expect( output ).toBe( "<-{{planet}} => Earth->" );
			} );

			it( "Section - Multiple Calls: Lambdas used for sections should not be cached.", function(){
				var output = variables.stubble.render(
					"{{##lambda}}FILE{{/lambda}} != {{##lambda}}LINE{{/lambda}}",
					{
						lambda: ( text ) => {
							return "__" & text & "__";
						}
					}
				);

				expect( output ).toBe( "__FILE__ != __LINE__" );
			} );

			it( "Inverted Section: Lambdas used for inverted sections should be considered truthy.", function(){
				var output = variables.stubble.render(
					"<{{^lambda}}{{static}}{{/lambda}}>",
					{
						static: "static",
						lambda: () => {
							return false;
						}
					}
				);

				expect( output ).toBe( "<>" );
			} );
		} );
	}
}
