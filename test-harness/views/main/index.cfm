<cfoutput>
<main>
	<h1>Module Tester</h1>
	<p class="controller-rendered">#prc.controllerRendered#</p>
	<p class="helper-rendered">#renderMustache( template = prc.viewTemplate, data = prc.viewData )#</p>
</main>
</cfoutput>