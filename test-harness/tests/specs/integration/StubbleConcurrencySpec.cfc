/**
 * Stubble Integration Concurrency Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Stubble Integration", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "handles concurrent renders on a shared instance and respects cache limits", function(){
				var threadNames  = [];
				var totalThreads = 20;
				var iterations   = 5;
				var maxEntries   = 7;

				variables.stubble.clearCache();
				variables.stubble.configureCache( enabled = true, maxEntries = maxEntries );

				for ( var i = 1; i <= totalThreads; i++ ) {
					var threadName = "stubbleRender_" & i & "_" & getTickCount();
					arrayAppend( threadNames, threadName );

					thread
						action      = "run"
						name        = threadName
						stubble     = variables.stubble
						threadIndex = i
						iterations  = iterations
					{
						thread.hadError = false;
						thread.completed = false;
						thread.result   = "";

						try {
							for ( var j = 1; j <= attributes.iterations; j++ ) {
								var template = "T" & attributes.threadIndex & "-" & j & ":{{name}}-{{##arr}}{{.}}{{/arr}}";
								thread.result = attributes.stubble.render(
									template,
									{
										name : "N" & attributes.threadIndex,
										arr  : [ 1, 2, 3 ]
									}
								);
							}
						} catch ( any e ) {
							thread.hadError     = true;
							thread.errorMessage = e.message;
						} finally {
							thread.completed = true;
						}
					};
				}

				thread action = "join" name = arrayToList( threadNames ) timeout = 10000;

				for ( var i = 1; i <= arrayLen( threadNames ); i++ ) {
					var thisThreadName = threadNames[ i ];
					var expected       = "T" & i & "-" & iterations & ":N" & i & "-123";

					expect( structKeyExists( cfthread, thisThreadName ) ).toBeTrue();
					expect( structKeyExists( cfthread[ thisThreadName ], "completed" ) && cfthread[ thisThreadName ].completed )
						.toBeTrue( "Thread did not complete: #thisThreadName#" );
					expect( cfthread[ thisThreadName ].hadError )
						.toBeFalse( structKeyExists( cfthread[ thisThreadName ], "errorMessage" ) ? cfthread[ thisThreadName ].errorMessage : "" );
					expect( cfthread[ thisThreadName ].result ).toBe( expected );
				}

				var stats = variables.stubble.getCacheStats();
				expect( stats.enabled ).toBeTrue();
				expect( stats.maxEntries ).toBe( maxEntries );
				expect( stats.currentEntries ).toBeLTE( maxEntries );
			} );

			it( "remains stable when cache is toggled during concurrent renders", function(){
				var renderThreadNames  = [];
				var toggleThreadNames  = [];
				var renderThreads      = 12;
				var renderIterations   = 12;
				var toggleThreads      = 3;
				var toggleIterations   = 20;

				variables.stubble.clearCache();
				variables.stubble.configureCache( enabled = true, maxEntries = 6 );

				for ( var i = 1; i <= renderThreads; i++ ) {
					var renderThreadName = "stubbleRenderToggle_" & i & "_" & getTickCount();
					arrayAppend( renderThreadNames, renderThreadName );

					thread
						action          = "run"
						name            = renderThreadName
						stubble         = variables.stubble
						threadIndex     = i
						iterations      = renderIterations
					{
						thread.hadError = false;
						thread.completed = false;
						thread.result   = "";

						try {
							for ( var j = 1; j <= attributes.iterations; j++ ) {
								thread.result = attributes.stubble.render(
									"{{##items}}{{name}}:{{.}};{{/items}}",
									{
										name  : "N" & attributes.threadIndex,
										items : [ 1, 2, 3 ]
									}
								);
							}
						} catch ( any e ) {
							thread.hadError     = true;
							thread.errorMessage = e.message;
						} finally {
							thread.completed = true;
						}
					};
				}

				for ( var i = 1; i <= toggleThreads; i++ ) {
					var toggleThreadName = "stubbleCacheToggle_" & i & "_" & getTickCount();
					arrayAppend( toggleThreadNames, toggleThreadName );

					thread
						action        = "run"
						name          = toggleThreadName
						stubble       = variables.stubble
						iterations    = toggleIterations
						threadOrdinal = i
					{
						thread.hadError = false;
						thread.completed = false;
						thread.result   = "";

						try {
							for ( var j = 1; j <= attributes.iterations; j++ ) {
								var enabled = ( j % 2 == 0 );
								var cap     = ( ( j + attributes.threadOrdinal ) % 5 ) + 1;
								attributes.stubble.configureCache( enabled = enabled, maxEntries = cap );
								thread.result = "ok";
							}
						} catch ( any e ) {
							thread.hadError     = true;
							thread.errorMessage = e.message;
						} finally {
							thread.completed = true;
						}
					};
				}

				thread action = "join" name = arrayToList( renderThreadNames ) timeout = 10000;
				thread action = "join" name = arrayToList( toggleThreadNames ) timeout = 10000;

				for ( var i = 1; i <= arrayLen( renderThreadNames ); i++ ) {
					var thisRenderThreadName = renderThreadNames[ i ];
					var expected             = "N" & i & ":1;N" & i & ":2;N" & i & ":3;";

					expect( structKeyExists( cfthread, thisRenderThreadName ) ).toBeTrue();
					expect( structKeyExists( cfthread[ thisRenderThreadName ], "completed" ) && cfthread[ thisRenderThreadName ].completed )
						.toBeTrue( "Thread did not complete: #thisRenderThreadName#" );
					expect( cfthread[ thisRenderThreadName ].hadError )
						.toBeFalse( structKeyExists( cfthread[ thisRenderThreadName ], "errorMessage" ) ? cfthread[ thisRenderThreadName ].errorMessage : "" );
					expect( cfthread[ thisRenderThreadName ].result ).toBe( expected );
				}

				for ( var i = 1; i <= arrayLen( toggleThreadNames ); i++ ) {
					var thisToggleThreadName = toggleThreadNames[ i ];

					expect( structKeyExists( cfthread, thisToggleThreadName ) ).toBeTrue();
					expect( structKeyExists( cfthread[ thisToggleThreadName ], "completed" ) && cfthread[ thisToggleThreadName ].completed )
						.toBeTrue( "Thread did not complete: #thisToggleThreadName#" );
					expect( cfthread[ thisToggleThreadName ].hadError )
						.toBeFalse( structKeyExists( cfthread[ thisToggleThreadName ], "errorMessage" ) ? cfthread[ thisToggleThreadName ].errorMessage : "" );
					expect( cfthread[ thisToggleThreadName ].result ).toBe( "ok" );
				}

				variables.stubble.configureCache( enabled = true, maxEntries = 4 );

				var stats = variables.stubble.getCacheStats();
				expect( stats.enabled ).toBeTrue();
				expect( stats.maxEntries ).toBe( 4 );
				expect( stats.currentEntries ).toBeLTE( stats.maxEntries );
			} );
		} );
	}
}
