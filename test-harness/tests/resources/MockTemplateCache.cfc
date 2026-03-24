component displayname="MockTemplateCache" implements="models.ITemplateCache" {

	variables._callCount = 0;

	public void function configure(boolean enabled, numeric maxEntries) {}

	public void function clear() {
		variables._callCount = 0;
	}

	public struct function getStats() {
		return { enabled: false, maxEntries: 0, currentEntries: 0 };
	}

	public array function getOrSet(
		required string template,
		required string openDelimiter,
		required string closeDelimiter,
		required function parseFn
	) {
		variables._callCount++;
		return arguments.parseFn( arguments.template, arguments.openDelimiter, arguments.closeDelimiter );
	}

	public numeric function getCallCount() {
		return variables._callCount;
	}
}
