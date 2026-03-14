component extends="models.Stubble" {

	variables._instrumentedParser = new InstrumentedParser();
	variables._parser = variables._instrumentedParser;

	public function init() {
		super.init(parser = variables._instrumentedParser);
		return this;
	}

	public numeric function getParseCallCount() {
		return variables._instrumentedParser.getParseCallCount();
	}
}
