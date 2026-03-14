component displayname="TemplateCache" {
	variables._templateCache = {};
	variables._cacheLinks = {};
	variables._cacheHeadKey = "";
	variables._cacheTailKey = "";
	variables._cacheMaxEntries = 200;
	variables._cacheEnabled = true;
	variables._cacheLockName = "Stubble.TemplateCache";

	public void function configure(
		boolean enabled = true,
		numeric maxEntries = 200
	) {
		lock name=variables._cacheLockName type="exclusive" timeout="5" {
			variables._cacheEnabled = arguments.enabled;
			variables._cacheMaxEntries = max(1, int(arguments.maxEntries));

			if (!variables._cacheEnabled) {
				_resetState();
			} else {
				_evictIfNeeded();
			}
		}
	}

	public void function clear() {
		lock name=variables._cacheLockName type="exclusive" timeout="5" {
			_resetState();
		}
	}

	public struct function getStats() {
		var stats = {};
		lock name=variables._cacheLockName type="readonly" timeout="5" {
			stats = {
				enabled: variables._cacheEnabled,
				maxEntries: variables._cacheMaxEntries,
				currentEntries: structCount(variables._templateCache)
			};
		}
		return stats;
	}

	public array function getOrSet(
		required string template,
		required string openDelimiter,
		required string closeDelimiter,
		required function parseFn
	) {
		if (!variables._cacheEnabled) {
			return arguments.parseFn(arguments.template, arguments.openDelimiter, arguments.closeDelimiter);
		}

		var cacheKey = _buildKey(arguments.template, arguments.openDelimiter, arguments.closeDelimiter);
		var cachedAst = [];
		var hasCached = false;

		lock name=variables._cacheLockName type="readonly" timeout="5" {
			hasCached = structKeyExists(variables._templateCache, cacheKey);
			if (hasCached) {
				cachedAst = variables._templateCache[cacheKey];
			}
		}

		if (hasCached) {
			lock name=variables._cacheLockName type="exclusive" timeout="5" {
				if (structKeyExists(variables._templateCache, cacheKey)) {
					_touchKey(cacheKey);
				}
			}
			return cachedAst;
		}

		var ast = arguments.parseFn(arguments.template, arguments.openDelimiter, arguments.closeDelimiter);
		lock name=variables._cacheLockName type="exclusive" timeout="5" {
			if (!structKeyExists(variables._templateCache, cacheKey)) {
				variables._templateCache[cacheKey] = ast;
			}

			_touchKey(cacheKey);
			_evictIfNeeded();
		}

		return ast;
	}

	private void function _resetState() {
		variables._templateCache = {};
		variables._cacheLinks = {};
		variables._cacheHeadKey = "";
		variables._cacheTailKey = "";
	}

	private string function _buildKey(
		required string template,
		required string openDelimiter,
		required string closeDelimiter
	) {
		return len(arguments.template) & ":" & hash(
			arguments.openDelimiter & chr(0) & arguments.closeDelimiter & chr(0) & arguments.template,
			"MD5"
		);
	}

	private void function _touchKey(required string cacheKey) {
		if (!structKeyExists(variables._templateCache, arguments.cacheKey)) {
			return;
		}

		if (!structKeyExists(variables._cacheLinks, arguments.cacheKey)) {
			variables._cacheLinks[arguments.cacheKey] = {
				prev: variables._cacheTailKey,
				next: ""
			};

			_linkAtTail(arguments.cacheKey);
			return;
		}

		if (variables._cacheTailKey == arguments.cacheKey) {
			return;
		}

		var prevKey = variables._cacheLinks[arguments.cacheKey].prev;
		var nextKey = variables._cacheLinks[arguments.cacheKey].next;

		if (len(prevKey) && structKeyExists(variables._cacheLinks, prevKey)) {
			variables._cacheLinks[prevKey].next = nextKey;
		} else {
			variables._cacheHeadKey = nextKey;
		}

		if (len(nextKey) && structKeyExists(variables._cacheLinks, nextKey)) {
			variables._cacheLinks[nextKey].prev = prevKey;
		}

		variables._cacheLinks[arguments.cacheKey].prev = variables._cacheTailKey;
		variables._cacheLinks[arguments.cacheKey].next = "";

		_linkAtTail(arguments.cacheKey);
	}

	private void function _linkAtTail(required string cacheKey) {
		if (len(variables._cacheTailKey) && structKeyExists(variables._cacheLinks, variables._cacheTailKey)) {
			variables._cacheLinks[variables._cacheTailKey].next = arguments.cacheKey;
		} else {
			variables._cacheHeadKey = arguments.cacheKey;
		}

		variables._cacheTailKey = arguments.cacheKey;
	}

	private void function _removeKey(required string cacheKey) {
		if (structKeyExists(variables._cacheLinks, arguments.cacheKey)) {
			var cacheLink = variables._cacheLinks[arguments.cacheKey];

			if (len(cacheLink.prev) && structKeyExists(variables._cacheLinks, cacheLink.prev)) {
				variables._cacheLinks[cacheLink.prev].next = cacheLink.next;
			} else {
				variables._cacheHeadKey = cacheLink.next;
			}

			if (len(cacheLink.next) && structKeyExists(variables._cacheLinks, cacheLink.next)) {
				variables._cacheLinks[cacheLink.next].prev = cacheLink.prev;
			} else {
				variables._cacheTailKey = cacheLink.prev;
			}

			structDelete(variables._cacheLinks, arguments.cacheKey);
		}

		if (structKeyExists(variables._templateCache, arguments.cacheKey)) {
			structDelete(variables._templateCache, arguments.cacheKey);
		}

		if (!structCount(variables._templateCache)) {
			variables._cacheLinks = {};
			variables._cacheHeadKey = "";
			variables._cacheTailKey = "";
		}
	}

	private void function _evictIfNeeded() {
		while (structCount(variables._templateCache) > variables._cacheMaxEntries && len(variables._cacheHeadKey)) {
			_removeKey(variables._cacheHeadKey);
		}
	}
}
