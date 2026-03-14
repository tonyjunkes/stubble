<cfscript>
	string function renderMustache(required string template, any data = {}, struct partials = {}) {
		return wirebox.getInstance("Stubble@stubble").render(
			template = arguments.template,
			data = arguments.data,
			partials = arguments.partials
		);
	}
</cfscript>
