<cfoutput>
<main>
	<h2>Module Tester Content</h2>
	<p class="controller-rendered">#prc.controllerRendered#</p>
	<p class="helper-rendered">#renderMustache( template = prc.viewTemplate, data = prc.viewData )#</p>
</main>
</cfoutput>