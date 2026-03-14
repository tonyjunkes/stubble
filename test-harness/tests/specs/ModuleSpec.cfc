component extends="coldbox.system.testing.BaseTestCase" appMapping="root" {

	/*********************************** LIFE CYCLE Methods ***********************************/

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	/*********************************** BDD SUITES ***********************************/

	function run(){
		describe( "Stubble ColdBox Module", function(){
			beforeEach( function( currentSpec ){
				setup();
			} );

			it( "renders controller and helper output through the harness app", function(){
				var event = execute( event = "main.index", renderResults = true );

				expect( event.getRenderedContent() )
					.toInclude( "Controller rendered for ColdBox." )
					.toInclude( "View helper rendered for ColdBox." );
			} );

			it( "registers the Stubble module in WireBox", function(){
				var stubble = getInstance( "Stubble@stubble" );

				expect( stubble ).toBeComponent();
			} );
		} );
	}

}
