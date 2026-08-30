component displayname="TemplateCache" implements="ITemplateCache" {
	variables._templateCache = {};
	variables._cacheLinks = {};
	variables._cacheHeadKey = "";
	variables._cacheTailKey = "";
	variables._cacheMaxEntries = 200;
	variables._cacheEnabled = true;
	variables._cacheLockName = "Stubble.TemplateCache." & replace(createUUID(), "-", "", "all");

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
		var cacheKey = _buildKey(arguments.template, arguments.openDelimiter, arguments.closeDelimiter);
		var cachedAst = [];
		var hasCached = false;
		var cacheEnabled = false;
		var cacheEntryCount = 0;
		var cacheMaxEntries = 0;

		lock name=variables._cacheLockName type="readonly" timeout="5" {
			cacheEnabled = variables._cacheEnabled;
			cacheMaxEntries = variables._cacheMaxEntries;
			if (cacheEnabled) {
				cacheEntryCount = structCount(variables._templateCache);
				hasCached = structKeyExists(variables._templateCache, cacheKey);
				if (hasCached) {
					cachedAst = variables._templateCache[cacheKey];
				}
			}
		}

		if (!cacheEnabled) {
			return arguments.parseFn(arguments.template, arguments.openDelimiter, arguments.closeDelimiter);
		}

		if (hasCached) {
			if (cacheEntryCount >= cacheMaxEntries) {
				lock name=variables._cacheLockName type="exclusive" timeout="5" {
					if (variables._cacheEnabled && structKeyExists(variables._templateCache, cacheKey)) {
						_touchKey(cacheKey);
					}
				}
			}
			return cachedAst;
		}

		var ast = arguments.parseFn(arguments.template, arguments.openDelimiter, arguments.closeDelimiter);
		lock name=variables._cacheLockName type="exclusive" timeout="5" {
			if (variables._cacheEnabled) {
				if (!structKeyExists(variables._templateCache, cacheKey)) {
					variables._templateCache[cacheKey] = ast;
				}

				_touchKey(cacheKey);
				_evictIfNeeded();
			}
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
		try {
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

			var cacheLink = variables._cacheLinks[arguments.cacheKey];
			var prevKey = structKeyExists(cacheLink, "prev") ? cacheLink.prev : "";
			var nextKey = structKeyExists(cacheLink, "next") ? cacheLink.next : "";

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
		} catch (any e) {
			_rebuildLinksFromCache();
		}
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
		try {
			if (structKeyExists(variables._cacheLinks, arguments.cacheKey)) {
				var cacheLink = variables._cacheLinks[arguments.cacheKey];
				var prevKey = structKeyExists(cacheLink, "prev") ? cacheLink.prev : "";
				var nextKey = structKeyExists(cacheLink, "next") ? cacheLink.next : "";

				if (len(prevKey) && structKeyExists(variables._cacheLinks, prevKey)) {
					variables._cacheLinks[prevKey].next = nextKey;
				} else {
					variables._cacheHeadKey = nextKey;
				}

				if (len(nextKey) && structKeyExists(variables._cacheLinks, nextKey)) {
					variables._cacheLinks[nextKey].prev = prevKey;
				} else {
					variables._cacheTailKey = prevKey;
				}

				structDelete(variables._cacheLinks, arguments.cacheKey);
			}
		} catch (any e) {
			if (structKeyExists(variables._cacheLinks, arguments.cacheKey)) {
				structDelete(variables._cacheLinks, arguments.cacheKey);
			}
			if (structCount(variables._templateCache)) {
				_rebuildLinksFromCache();
			} else {
				variables._cacheLinks = {};
				variables._cacheHeadKey = "";
				variables._cacheTailKey = "";
			}
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

	private void function _rebuildLinksFromCache() {
		variables._cacheLinks = {};
		variables._cacheHeadKey = "";
		variables._cacheTailKey = "";

		var cacheKeys = structKeyArray(variables._templateCache);
		for (var i = 1; i <= arrayLen(cacheKeys); i++) {
			var cacheKey = cacheKeys[i];
			variables._cacheLinks[cacheKey] = {
				prev: variables._cacheTailKey,
				next: ""
			};
			_linkAtTail(cacheKey);
		}
	}

	private void function _evictIfNeeded() {
		while (structCount(variables._templateCache) > variables._cacheMaxEntries) {
			if (
				!len(variables._cacheHeadKey) ||
				!structKeyExists(variables._templateCache, variables._cacheHeadKey) ||
				!structKeyExists(variables._cacheLinks, variables._cacheHeadKey)
			) {
				_rebuildLinksFromCache();
			}

			if (!len(variables._cacheHeadKey)) {
				break;
			}

			var entryCountBeforeRemove = structCount(variables._templateCache);
			_removeKey(variables._cacheHeadKey);

			if (structCount(variables._templateCache) >= entryCountBeforeRemove) {
				_rebuildLinksFromCache();
				if (!len(variables._cacheHeadKey)) {
					break;
				}
				_removeKey(variables._cacheHeadKey);
			}
		}
	}
}
