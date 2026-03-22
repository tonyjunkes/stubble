<cfscript>
	string function renderMustache(required string template, any view = {}, struct partials = {}) {
		return wirebox.getInstance("Stubble@stubble").render(
			template = arguments.template,
			view = arguments.view,
			partials = arguments.partials
		);
	}
</cfscript>
