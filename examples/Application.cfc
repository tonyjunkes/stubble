component {
	this.name = "A TestBox Runner Suite";
	this.sessionManagement = true;

	this.mappings[ "/tests" ] = expandPath( "../tests" );
	this.mappings[ "/models" ] = expandPath( "../models" );

	public boolean function onRequestStart( string targetPage ){
		return true;
	}
}
