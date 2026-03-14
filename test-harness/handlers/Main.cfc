/**
* My Event Handler Hint
*/
component{

	property name="stubble" inject="Stubble@stubble";

	// Index
	any function index( event,rc, prc ){
		prc.controllerRendered = variables.stubble.render(
			template = "Controller rendered for {{name}}.",
			data = { name : "ColdBox" }
		);
		prc.viewTemplate = "View helper rendered for {{name}}.";
		prc.viewData = { name : "ColdBox" };
		event.setView( "main/index" );
	}

}