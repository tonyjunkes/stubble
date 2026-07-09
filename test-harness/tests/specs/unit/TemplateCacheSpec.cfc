/**
 * TemplateCache BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "TemplateCache", function(){
			beforeEach( function(){
				variables.cache = createObject( "component", "models.TemplateCache" );
			} );

			describe( "getStats()", function(){
				it( "reports defaults on fresh instance", function(){
					var stats = variables.cache.getStats();

					expect( stats.enabled ).toBeTrue();
					expect( stats.maxEntries ).toBe( 200 );
					expect( stats.currentEntries ).toBe( 0 );
				} );
			} );

			describe( "configure()", function(){
				it( "changes maxEntries", function(){
					variables.cache.configure( enabled = true, maxEntries = 50 );
					var stats = variables.cache.getStats();

					expect( stats.maxEntries ).toBe( 50 );
				} );

				it( "enforces minimum maxEntries of 1", function(){
					variables.cache.configure( enabled = true, maxEntries = 0 );
					var stats = variables.cache.getStats();

					expect( stats.maxEntries ).toBe( 1 );
				} );

				it( "enforces minimum for negative values", function(){
					variables.cache.configure( enabled = true, maxEntries = -10 );
					var stats = variables.cache.getStats();

					expect( stats.maxEntries ).toBe( 1 );
				} );

				it( "disables cache and clears entries", function(){
					// Prime the cache
					variables.cache.getOrSet( "hello", "{{", "}}", function( t, o, c ){ return []; } );
					expect( variables.cache.getStats().currentEntries ).toBe( 1 );

					variables.cache.configure( enabled = false );
					var stats = variables.cache.getStats();

					expect( stats.enabled ).toBeFalse();
					expect( stats.currentEntries ).toBe( 0 );
				} );

				it( "re-enables cache after disabling", function(){
					variables.cache.configure( enabled = false );
					variables.cache.configure( enabled = true );

					expect( variables.cache.getStats().enabled ).toBeTrue();
				} );
			} );

			describe( "clear()", function(){
				it( "removes all cached entries", function(){
					variables.cache.getOrSet( "a", "{{", "}}", function( t, o, c ){ return [ 1 ]; } );
					variables.cache.getOrSet( "b", "{{", "}}", function( t, o, c ){ return [ 2 ]; } );
					expect( variables.cache.getStats().currentEntries ).toBe( 2 );

					variables.cache.clear();
					expect( variables.cache.getStats().currentEntries ).toBe( 0 );
				} );
			} );

			describe( "getOrSet()", function(){
				it( "calls parseFn and caches the result", function(){
					var callCount = 0;
					var parseFn = function( t, o, c ){
						callCount++;
						return [ { type: "text", value: t } ];
					};

					var result1 = variables.cache.getOrSet( "hello", "{{", "}}", parseFn );
					var result2 = variables.cache.getOrSet( "hello", "{{", "}}", parseFn );

					expect( callCount ).toBe( 1 );
					expect( result1 ).toBe( result2 );
					expect( variables.cache.getStats().currentEntries ).toBe( 1 );
				} );

				it( "calls parseFn every time when cache is disabled", function(){
					variables.cache.configure( enabled = false );
					var callCount = 0;
					var parseFn = function( t, o, c ){
						callCount++;
						return [];
					};

					variables.cache.getOrSet( "hello", "{{", "}}", parseFn );
					variables.cache.getOrSet( "hello", "{{", "}}", parseFn );

					expect( callCount ).toBe( 2 );
				} );

					it( "does not repopulate the cache when disabled during an in-flight parse", function(){
						var gateLockName = "TemplateCacheSpec.parseGate." & replace( createUUID(), "-", "", "all" );
						var threadName = "templateCacheDisableRace_" & getTickCount();

						lock name=gateLockName type="exclusive" timeout="5" {
							thread
								action       = "run"
								name         = threadName
								cache        = variables.cache
								gateLockName = gateLockName
							{
								thread.hadError = false;
								thread.parseStarted = false;
								thread.completed = false;
								thread.result = [];

								try {
									thread.result = attributes.cache.getOrSet(
										"hello",
										"{{",
										"}}",
										function( t, o, c ){
											thread.parseStarted = true;
											lock name=attributes.gateLockName type="exclusive" timeout="5" {
												return [ { type: "text", value: t } ];
											}
										}
									);
								} catch ( any e ) {
									thread.hadError = true;
									thread.errorMessage = e.message;
								} finally {
									thread.completed = true;
								}
							};

							var deadline = getTickCount() + 5000;
							var parseStarted = false;

							while ( getTickCount() < deadline ) {
								if (
									structKeyExists( cfthread, threadName ) &&
									structKeyExists( cfthread[ threadName ], "parseStarted" ) &&
									cfthread[ threadName ].parseStarted
								) {
									parseStarted = true;
									break;
								}

								sleep( 25 );
							}

							expect( parseStarted ).toBeTrue();
							variables.cache.configure( enabled = false );
						}

						thread action = "join" name = threadName timeout = 10000;

						expect( structKeyExists( cfthread[ threadName ], "completed" ) && cfthread[ threadName ].completed )
							.toBeTrue( "Thread did not complete: #threadName#" );
						expect( cfthread[ threadName ].hadError ).toBeFalse();
						expect( arrayLen( cfthread[ threadName ].result ) ).toBe( 1 );
						expect( cfthread[ threadName ].result[ 1 ].type ).toBe( "text" );
						expect( cfthread[ threadName ].result[ 1 ].value ).toBe( "hello" );

						var stats = variables.cache.getStats();
						expect( stats.enabled ).toBeFalse();
						expect( stats.currentEntries ).toBe( 0 );

						variables.cache.configure( enabled = true );

						var replayParseCount = 0;
						var replayedResult = variables.cache.getOrSet( "hello", "{{", "}}", function( t, o, c ){
							replayParseCount++;
							return [ { type: "text", value: t } ];
						} );

						variables.cache.getOrSet( "hello", "{{", "}}", function( t, o, c ){
							replayParseCount++;
							return [ { type: "text", value: t } ];
						} );

						expect( arrayLen( replayedResult ) ).toBe( 1 );
						expect( replayedResult[ 1 ].value ).toBe( "hello" );
						expect( replayParseCount ).toBe( 1 );
						expect( variables.cache.getStats().currentEntries ).toBe( 1 );
					} );

				it( "differentiates entries by template content", function(){
					var parseFn = function( t, o, c ){ return [ t ]; };

					variables.cache.getOrSet( "aaa", "{{", "}}", parseFn );
					variables.cache.getOrSet( "bbb", "{{", "}}", parseFn );

					expect( variables.cache.getStats().currentEntries ).toBe( 2 );
				} );

				it( "differentiates entries by delimiters", function(){
					var parseFn = function( t, o, c ){ return [ t ]; };

					variables.cache.getOrSet( "hello", "{{", "}}", parseFn );
					variables.cache.getOrSet( "hello", "<%", "%>", parseFn );

					expect( variables.cache.getStats().currentEntries ).toBe( 2 );
				} );

				it( "returns the parseFn result", function(){
					var expected = [ { type: "text", value: "hi" } ];
					var result = variables.cache.getOrSet( "hi", "{{", "}}", function( t, o, c ){
						return expected;
					} );

					expect( result ).toBe( expected );
				} );
			} );

			describe( "LRU eviction", function(){
				it( "evicts the least recently used entry when maxEntries is exceeded", function(){
					variables.cache.configure( enabled = true, maxEntries = 2 );
					var parseFn = function( t, o, c ){ return [ t ]; };

					variables.cache.getOrSet( "first", "{{", "}}", parseFn );
					variables.cache.getOrSet( "second", "{{", "}}", parseFn );
					variables.cache.getOrSet( "third", "{{", "}}", parseFn );

					expect( variables.cache.getStats().currentEntries ).toBe( 2 );
				} );

				it( "evicts in correct order with access pattern", function(){
					variables.cache.configure( enabled = true, maxEntries = 2 );
					var callCount = 0;
					var parseFn = function( t, o, c ){
						callCount++;
						return [ t ];
					};

					// Insert first and second
					variables.cache.getOrSet( "first", "{{", "}}", parseFn );
					variables.cache.getOrSet( "second", "{{", "}}", parseFn );
					expect( callCount ).toBe( 2 );

					// Touch first (makes it most recently used)
					variables.cache.getOrSet( "first", "{{", "}}", parseFn );
					expect( callCount ).toBe( 2 ); // still cached

					// Insert third — should evict second (LRU), not first
					variables.cache.getOrSet( "third", "{{", "}}", parseFn );
					expect( callCount ).toBe( 3 );
					expect( variables.cache.getStats().currentEntries ).toBe( 2 );

					// First should still be cached
					variables.cache.getOrSet( "first", "{{", "}}", parseFn );
					expect( callCount ).toBe( 3 );

					// Second should have been evicted and needs re-parsing
					variables.cache.getOrSet( "second", "{{", "}}", parseFn );
					expect( callCount ).toBe( 4 );
				} );

				it( "evicts down to maxEntries when reconfigured smaller", function(){
					variables.cache.configure( enabled = true, maxEntries = 5 );
					var parseFn = function( t, o, c ){ return [ t ]; };

					for ( var i = 1; i <= 5; i++ ) {
						variables.cache.getOrSet( "template#i#", "{{", "}}", parseFn );
					}
					expect( variables.cache.getStats().currentEntries ).toBe( 5 );

					variables.cache.configure( enabled = true, maxEntries = 2 );
					expect( variables.cache.getStats().currentEntries ).toBe( 2 );
				} );
			} );
		} );
	}
}
