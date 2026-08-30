/**
 * ContextResolver BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "ContextResolver", function(){
			beforeEach( function(){
				variables.resolver = createObject( "component", "models.ContextResolver" );
			} );

			describe( "lookup()", function(){
				it( "returns the current context for dot lookups", function(){
					var result = variables.resolver.lookup( ".", [ "root", "current" ] );

					expect( result.found ).toBeTrue();
					expect( result.value ).toBe( "current" );
				} );

				it( "falls back through parent contexts for simple names", function(){
					var result = variables.resolver.lookup(
						"title",
						[
							{ title: "Team" },
							{ name: "Ada" }
						]
					);

					expect( result.found ).toBeTrue();
					expect( result.value ).toBe( "Team" );
				} );

				it( "resolves dotted names from the nearest context with the first part", function(){
					var result = variables.resolver.lookup(
						"user.profile.name",
						[
							{ user: { profile: { name: "Ada" } } },
							{ other: "value" }
						]
					);

					expect( result.found ).toBeTrue();
					expect( result.value ).toBe( "Ada" );
				} );

				it( "resolves numeric array indexes in dotted paths", function(){
					var result = variables.resolver.lookup(
						"users.2.name",
						[
							{
								users: [
									{ name: "Ada" },
									{ name: "Grace" }
								]
							}
						]
					);

					expect( result.found ).toBeTrue();
					expect( result.value ).toBe( "Grace" );
				} );

				it( "returns missing for broken dotted chains", function(){
					var result = variables.resolver.lookup(
						"a.b.c",
						[ { a: {} } ]
					);

					expect( result.found ).toBeFalse();
					expect( result.value ).toBe( "" );
				} );

				it( "does not fall back when a dotted chain breaks after the first part resolves", function(){
					var result = variables.resolver.lookup(
						"user.profile.name",
						[
							{ user: { profile: { name: "Ada" } } },
							{ user: "wrong" }
						]
					);

					expect( result.found ).toBeFalse();
					expect( result.value ).toBe( "" );
				} );

				it( "resolves CFC public fields", function(){
					var publicFixture = createObject( "component", "tests.resources.DynamicLookupFixture" )
						.init( "Ada", "Architect" );

					var publicResult = variables.resolver.lookup( "person.role", [ { person: publicFixture } ] );

					expect( publicResult.found ).toBeTrue();
					expect( publicResult.value ).toBe( "Architect" );
				} );

				it( "resolves CFC generated accessors", function(){
					var accessorFixture = createObject( "component", "tests.resources.AccessorLookupFixture" )
						.init( "Grace" );

					var getterResult = variables.resolver.lookup( "person.name", [ { person: accessorFixture } ] );
					var booleanResult = variables.resolver.lookup( "person.active", [ { person: accessorFixture } ] );

					expect( getterResult.found ).toBeTrue();
					expect( getterResult.value ).toBe( "Grace" );
					expect( booleanResult.found ).toBeTrue();
					expect( booleanResult.value ).toBeTrue();
				} );

				it( "returns missing for absent CFC accessors", function(){
					var fixture = createObject( "component", "tests.resources.AccessorLookupFixture" )
						.init( "Grace" );
					var result = variables.resolver.lookup( "person.missing", [ { person: fixture } ] );

					expect( result.found ).toBeFalse();
					expect( result.value ).toBe( "" );
				} );

				it( "rethrows errors from resolved function values when rendered as lambdas", function(){
					var stubble = createObject( "component", "models.Stubble" );

					expect( function(){
						stubble.render(
							"{{action.getCoolThing}}",
							{
								action: {
									getCoolThing: function(){
										throw( type = "Stubble.MockError", message = "Mock Error!" );
									}
								}
							}
						);
					} ).toThrow( type = "Stubble.MockError", message = "Mock Error!" );
				} );
			} );
		} );
	}
}
