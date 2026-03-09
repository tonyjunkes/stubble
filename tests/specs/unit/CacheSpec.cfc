/**
 * Stubble cache BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Stubble cache controls", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

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

			it( "retains recently reused templates when evicting entries", function(){
				var instrumentedStubble = createObject( "component", "tests.resources.InstrumentedStubble" );
				instrumentedStubble.clearCache();
				instrumentedStubble.configureCache( enabled = true, maxEntries = 2 );

				instrumentedStubble.render( "One {{name}}", { name: "Ada" } );
				instrumentedStubble.render( "Two {{name}}", { name: "Ada" } );
				instrumentedStubble.render( "One {{name}}", { name: "Ada" } );
				instrumentedStubble.render( "Three {{name}}", { name: "Ada" } );

				expect( instrumentedStubble.getParseCallCount() ).toBe( 3 );

				instrumentedStubble.render( "One {{name}}", { name: "Ada" } );
				instrumentedStubble.render( "Two {{name}}", { name: "Ada" } );

				expect( instrumentedStubble.getParseCallCount() ).toBe( 4 );
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
	}
}
