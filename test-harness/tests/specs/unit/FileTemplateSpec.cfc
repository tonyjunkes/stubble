/**
 * Stubble file template BDD Test
 */
component extends="testbox.system.BaseSpec" {
	function run( testResults, testBox ){
		describe( "Stubble file templates", function(){
			beforeEach( function(){
				variables.stubble = createObject( "component", "models.Stubble" );
			} );

			it( "tokenizes and parses syntax from mustache files", function(){
				var template = trim( readTemplateFixture( "SyntaxValid.mustache" ) );
				var tokens   = variables.stubble.tokenize( template );
				var ast      = variables.stubble.parse( tokens, template );

				expect( tokens ).toHaveLength( 11 );
				expect( tokens[ 4 ].type ).toBe( "section_start" );
				expect( tokens[ 4 ].name ).toBe( "items" );
				expect( tokens[ 7 ].type ).toBe( "inverted_start" );
				expect( tokens[ 11 ].type ).toBe( "partial" );
				expect( tokens[ 11 ].name ).toBe( "itemPartial" );

				expect( ast ).toHaveLength( 7 );
				expect( ast[ 4 ].type ).toBe( "section" );
				expect( ast[ 4 ].children[ 1 ].name ).toBe( "." );
				expect( ast[ 5 ].type ).toBe( "inverted" );
				expect( ast[ 7 ].type ).toBe( "partial" );
			} );

			it( "throws tokenizer errors for invalid mustache template files", function(){
				var template = trim( readTemplateFixture( "SyntaxInvalid.mustache" ) );

				expect( function(){
					variables.stubble.render( template, {} );
				} ).toThrow( type = "Stubble.Tokenizer" );
			} );

			it( "renders nested partial inclusions from mustache files", function(){
				var template = trim( readTemplateFixture( "FileTemplateMain.mustache" ) );
				var output   = variables.stubble.render(
					template,
					{ name: "Ada", role: "Engineer" },
					{
						body: trim( readTemplateFixture( "FileTemplateBody.mustache" ) ),
						badge: trim( readTemplateFixture( "FileTemplateBadge.mustache" ) )
					}
				);

				expect( output ).toBe( "Header|Name: Ada [Engineer]|Footer" );
			} );
		} );
	}

	private string function readTemplateFixture(required string fileName){
		return fileRead( expandPath( "/tests/resources/templates/#arguments.fileName#" ) );
	}
}
