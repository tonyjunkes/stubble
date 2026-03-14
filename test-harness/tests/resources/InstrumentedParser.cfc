component extends="models.Parser" {
	variables.parseCallCount = 0;

	public array function parse(required array tokens, required string template) {
		variables.parseCallCount++;
		return super.parse(argumentCollection = arguments);
	}

	public numeric function getParseCallCount() {
		return variables.parseCallCount;
	}
}
