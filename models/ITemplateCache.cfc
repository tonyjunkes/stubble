interface displayname="ITemplateCache" {
	public void function configure(boolean enabled, numeric maxEntries);
	public void function clear();
	public struct function getStats();
	public array function getOrSet(
		required string template,
		required string openDelimiter,
		required string closeDelimiter,
		required function parseFn
	);
}
