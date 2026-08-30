component {
	variables.personName = "";

	public AccessorLookupFixture function init(required string name) {
		variables.personName = arguments.name;
		return this;
	}

	public string function getName() {
		return variables.personName;
	}

	public boolean function isActive() {
		return true;
	}

	public void function getBroken() {
		throw(type = "Stubble.MockError", message = "Mock Error!");
	}
}
