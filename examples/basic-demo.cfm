<cfscript>
stubble = new models.Stubble();

function printCase(required string title, required string template, required any view, struct partials = {}) {
	var output = stubble.render(arguments.template, arguments.view, arguments.partials);
	writeOutput("<h3>" & arguments.title & "</h3>");
	writeOutput("<b>Template</b><pre>" & arguments.template & "</pre>");
	writeOutput("<b>Output</b><pre>" & output & "</pre>");
}

writeOutput("<h1>Stubble Demo: Basic Features</h1>");
writeOutput('<p><a href="index.cfm">Back to demo index</a></p>');

printCase(
	title = "Variables + Escaping",
	template = "Hello {{name}}. Raw: {{{html}}} Escaped: {{html}}",
	view = {
		name: "Anthony",
		html: "<strong>CFML</strong>"
	}
);

printCase(
	title = "Mustache Sections + Dot Lookup",
	template = "{{##people}}- {{name}} ({{.role}})#chr(10)##chr(10)#{{/people}}",
	view = {
		people: [
			{ name: "Moe", role: "Lead" },
			{ name: "Larry", role: "Engineer" },
			{ name: "Curly", role: "QA" }
		]
	}
);

printCase(
	title = "Inverted + Comments",
	template = "{{^repos}}No repos found.{{/repos}}{{! this is ignored }}",
	view = { repos: [] }
);

printCase(
	title = "Partials",
	template = "Users:#chr(10)##chr(10)#{{##users}}{{> userRow}}{{/users}}",
	view = {
		users: [
			{ name: "Ada", email: "ada@example.com" },
			{ name: "Linus", email: "linus@example.com" }
		]
	},
	partials = {
		userRow: "- {{name}} <{{email}}>#chr(10)##chr(10)#"
	}
);

printCase(
	title = "Lambda Variable",
	template = "Computed: {{calc}}",
	view = {
		calc: function() {
			return 2 + 4;
		}
	}
);

printCase(
	title = "Real Lambda Variable",
	template = "Computed: {{calc}}",
	view = {
		calc: () => { return 2 * 4; }
	}
);

printCase(
	title = "Lambda Section",
	template = "{{##wrap}}Hello {{name}}{{/wrap}}",
	view = {
		name: "Stubble",
		wrap: function(text, renderer) {
			return "[" & renderer(text) & "]";
		}
	}
);

printCase(
	title = "Real Lambda Section",
	template = "{{##wrap}}Hello {{name}}{{/wrap}}",
	view = {
		name: "Stubble",
		wrap: (text, renderer) => {
			return "[" & renderer(text) & "]";
		}
	}
);

stats = stubble.getCacheStats();
writeOutput("<h3>Cache Stats</h3>");
writeOutput("<pre>" & serializeJSON(stats) & "</pre>");
</cfscript>
