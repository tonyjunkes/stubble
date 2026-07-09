<cfscript>
	param name="url.iterations" default=5000;

	iterations = max( 1, val( url.iterations ) );
	stubble = createObject( "component", "models.Stubble" );
	stubble.configureCache( enabled = true, maxEntries = 200 );

	cases = [
		{
			name: "hot-cache interpolation",
			template: "Hello {{name}}, {{count}}!",
			view: { name: "Stubble", count: 42 },
			partials: {}
		},
		{
			name: "dotted lookup",
			template: "{{user.profile.name}} works on {{project.name}}.",
			view: {
				user: { profile: { name: "Ada" } },
				project: { name: "Stubble" }
			},
			partials: {}
		},
		{
			name: "nested sections",
			template: "{{##teams}}{{name}}:{{##people}}{{name}}={{role}};{{/people}}{{/teams}}",
			view: {
				teams: [
					{
						name: "Core",
						people: [
							{ name: "Ada", role: "Design" },
							{ name: "Grace", role: "Compiler" }
						]
					},
					{
						name: "Runtime",
						people: [
							{ name: "Linus", role: "Kernel" },
							{ name: "Margaret", role: "Systems" }
						]
					}
				]
			},
			partials: {}
		},
		{
			name: "partials",
			template: "{{##items}}{{> row}}{{/items}}",
			view: {
				items: [
					{ name: "One", value: 1 },
					{ name: "Two", value: 2 },
					{ name: "Three", value: 3 }
				]
			},
			partials: { row: "{{name}}={{value}};" }
		},
		{
			name: "inheritance",
			template: "{{<layout}}{{$title}}{{name}}{{/title}}{{$body}}{{##items}}{{.}};{{/items}}{{/body}}{{/layout}}",
			view: { name: "Report", items: [ "a", "b", "c" ] },
			partials: {
				layout: "<h1>{{$title}}Untitled{{/title}}</h1><main>{{$body}}{{/body}}</main>"
			}
		},
		{
			name: "lambdas",
			template: "{{##wrap}}Hello {{name}}{{/wrap}} {{templateValue}}",
			view: {
				name: "Ada",
				wrap: function( text, render ){
					return "[" & arguments.render( arguments.text ) & "]";
				},
				templateValue: function(){
					return "{{name}}";
				}
			},
			partials: {}
		}
	];

	results = [];
	totalStarted = getTickCount();

	for ( caseDef in cases ) {
		stubble.render( caseDef.template, caseDef.view, caseDef.partials );

		started = getTickCount();
		for ( i = 1; i <= iterations; i++ ) {
			stubble.render( caseDef.template, caseDef.view, caseDef.partials );
		}
		elapsedMs = max( 1, getTickCount() - started );

		arrayAppend( results, {
			name: caseDef.name,
			iterations: iterations,
			elapsedMs: elapsedMs,
			rendersPerSecond: int( ( iterations * 1000 ) / elapsedMs )
		} );
	}

	payload = {
		engine: server.coldfusion.productName & " " & server.coldfusion.productVersion,
		iterationsPerCase: iterations,
		totalElapsedMs: getTickCount() - totalStarted,
		results: results,
		cache: stubble.getCacheStats()
	};
</cfscript>
<cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON( payload )#</cfoutput>
