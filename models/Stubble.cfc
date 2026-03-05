component displayname="Stubble" singleton {
	variables._templateCache = {};
	variables._cacheOrder = [];
	variables._cacheMaxEntries = 200;
	variables._cacheEnabled = true;
	variables._cacheLockName = "Stubble.TemplateCache";

	public array function tokenize(required string template) {
		var tokens = [];
		var pos = 1;
		var totalLen = len(arguments.template);

		while (pos <= totalLen) {
			var openPos = find("{{", arguments.template, pos);

			if (openPos == 0) {
				if (pos <= totalLen) {
					arrayAppend(tokens, {
						type: "text",
						value: mid(arguments.template, pos, totalLen - pos + 1),
						startPos: pos,
						endPos: totalLen
					});
				}
				break;
			}

			if (openPos > pos) {
				arrayAppend(tokens, {
					type: "text",
					value: mid(arguments.template, pos, openPos - pos),
					startPos: pos,
					endPos: openPos - 1
				});
			}

			if ((openPos + 2) <= totalLen && mid(arguments.template, openPos, 3) == "{{{") {
				var tripleClosePos = find("}}}", arguments.template, openPos + 3);
				if (tripleClosePos == 0) {
					throw(type = "Stubble.Tokenizer", message = "Unclosed triple mustache tag.");
				}

				var tripleName = trim(mid(arguments.template, openPos + 3, tripleClosePos - (openPos + 3)));
				arrayAppend(tokens, {
					type: "unescaped",
					name: tripleName,
					startPos: openPos,
					endPos: tripleClosePos + 2
				});

				pos = tripleClosePos + 3;
				continue;
			}

			var closePos = find("}}", arguments.template, openPos + 2);
			if (closePos == 0) {
				throw(type = "Stubble.Tokenizer", message = "Unclosed tag.");
			}

			var content = trim(mid(arguments.template, openPos + 2, closePos - (openPos + 2)));
			var token = {
				type: "variable",
				name: content,
				startPos: openPos,
				endPos: closePos + 1
			};

			if (len(content) > 0) {
				var sigil = left(content, 1);
				var body = trim(mid(content, 2, len(content) - 1));

				switch (sigil) {
					case "!":
						token.type = "comment";
						token.name = body;
						break;
					case ">":
						token.type = "partial";
						token.name = body;
						break;
					case "/":
						token.type = "section_end";
						token.name = body;
						if (left(token.name, 1) == "$") {
							token.name = trim(mid(token.name, 2, len(token.name) - 1));
						}
						break;
					case "$":
						token.type = "section_start";
						token.name = body;
						break;
					case "^":
						token.type = "inverted_start";
						token.name = body;
						break;
					case "&":
						token.type = "unescaped";
						token.name = body;
						break;
					default:
						token.type = "variable";
						token.name = content;
				}
			}

			arrayAppend(tokens, token);
			pos = closePos + 2;
		}

		return tokens;
	}

	public array function parse(required array tokens, required string template) {
		var root = { type: "root", children: [] };
		var stack = [root];

		for (var i = 1; i <= arrayLen(arguments.tokens); i++) {
			var token = arguments.tokens[i];
			var current = stack[arrayLen(stack)];

			switch (token.type) {
				case "text":
					arrayAppend(current.children, { type: "text", value: token.value });
					break;

				case "variable":
					arrayAppend(current.children, {
						type: "variable",
						name: token.name,
						nameParts: _buildNameParts(token.name)
					});
					break;

				case "unescaped":
					arrayAppend(current.children, {
						type: "unescaped",
						name: token.name,
						nameParts: _buildNameParts(token.name)
					});
					break;

				case "partial":
					arrayAppend(current.children, { type: "partial", name: token.name });
					break;

				case "comment":
					break;

				case "section_start":
				case "inverted_start":
					var node = {
						type: (token.type == "section_start" ? "section" : "inverted"),
						name: token.name,
						nameParts: _buildNameParts(token.name),
						children: [],
						rawStartPos: token.endPos + 1,
						rawText: ""
					};
					arrayAppend(current.children, node);
					arrayAppend(stack, node);
					break;

				case "section_end":
					if (arrayLen(stack) == 1) {
						throw(
							type = "Stubble.Parser",
							message = "Closing tag without opening tag: " & token.name
						);
					}

					var openIndex = arrayLen(stack);
					var openName = stack[openIndex].name;
					if (openName != token.name) {
						throw(
							type = "Stubble.Parser",
							message = "Section mismatch. Opened '" & openName & "' but closed '" & token.name & "'."
						);
					}

					var rawEndPos = token.startPos - 1;
					var rawStartPos = stack[openIndex].rawStartPos;
					if (rawEndPos >= rawStartPos) {
						stack[openIndex].rawText = mid(arguments.template, rawStartPos, rawEndPos - rawStartPos + 1);
					}

					arrayDeleteAt(stack, openIndex);
					break;

				default:
					throw(type = "Stubble.Parser", message = "Unsupported token type: " & token.type);
			}
		}

		if (arrayLen(stack) != 1) {
			var unclosed = stack[arrayLen(stack)];
			throw(type = "Stubble.Parser", message = "Unclosed section: " & unclosed.name);
		}

		return root.children;
	}

	public string function render(required string template, any data = {}, struct partials = {}) {
		var ast = _getParsedTemplate(arguments.template);
		var contextStack = [arguments.data];
		return _renderNodes(ast, contextStack, arguments.partials);
	}

	public void function configureCache(boolean enabled = true, numeric maxEntries = 200) {
		lock name=variables._cacheLockName type="exclusive" timeout="5" {
			variables._cacheEnabled = arguments.enabled;
			variables._cacheMaxEntries = max(1, int(arguments.maxEntries));

			if (!variables._cacheEnabled) {
				variables._templateCache = {};
				variables._cacheOrder = [];
			} else {
				_evictCacheIfNeeded();
			}
		}
	}

	public void function clearCache() {
		lock name=variables._cacheLockName type="exclusive" timeout="5" {
			variables._templateCache = {};
			variables._cacheOrder = [];
		}
	}

	public struct function getCacheStats() {
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

	private string function _renderNodes(required array nodes, required array contextStack, required struct partials) {
		var outputChunks = [];
		var nodeCount = arrayLen(arguments.nodes);

		for (var i = 1; i <= nodeCount; i++) {
			var node = arguments.nodes[i];

			switch (node.type) {
				case "text":
					arrayAppend(outputChunks, node.value);
					break;

				case "variable":
				case "unescaped":
					var lookup = _lookup(node.name, arguments.contextStack, node.nameParts);
					if (!lookup.found) {
						break;
					}

					var value = lookup.value;
					if (isCustomFunction(value)) {
						value = _invokeVariableLambda(value, arguments.contextStack, arguments.partials);
					}

					var renderedValue = _toString(value);
					if (node.type == "variable") {
						arrayAppend(outputChunks, encodeForHTML(renderedValue));
					} else {
						arrayAppend(outputChunks, renderedValue);
					}
					break;

				case "partial":
					if (structKeyExists(arguments.partials, node.name)) {
						var partialTemplate = arguments.partials[node.name];
						if (isCustomFunction(partialTemplate)) {
							partialTemplate = partialTemplate();
						}
						arrayAppend(outputChunks, _renderWithStack(_toString(partialTemplate), arguments.contextStack, arguments.partials));
					}
					break;

				case "section":
				case "inverted":
					arrayAppend(outputChunks, _renderSection(node, arguments.contextStack, arguments.partials));
					break;

				default:
					throw(type = "Stubble.Renderer", message = "Unsupported node type: " & node.type);
			}
		}

		return arrayToList(outputChunks, "");
	}

	private string function _renderSection(required struct node, required array contextStack, required struct partials) {
		var lookup = _lookup(arguments.node.name, arguments.contextStack, arguments.node.nameParts);
		var found = lookup.found;
		var value = found ? lookup.value : "";
		var truthy = found && _isTruthy(value);

		if (arguments.node.type == "inverted") {
			return truthy ? "" : _renderNodes(arguments.node.children, arguments.contextStack, arguments.partials);
		}

		if (!found) {
			return "";
		}

		if (isCustomFunction(value)) {
			return _invokeSectionLambda(value, arguments.node.rawText, arguments.contextStack, arguments.partials);
		}

		if (isArray(value)) {
			var valueCount = arrayLen(value);
			if (valueCount == 0) {
				return "";
			}

			var arrayOutputChunks = [];
			for (var i = 1; i <= valueCount; i++) {
				arrayAppend(arguments.contextStack, value[i]);
				try {
					arrayAppend(arrayOutputChunks, _renderNodes(arguments.node.children, arguments.contextStack, arguments.partials));
				} finally {
					arrayDeleteAt(arguments.contextStack, arrayLen(arguments.contextStack));
				}
			}
			return arrayToList(arrayOutputChunks, "");
		}

		if (isStruct(value) || isObject(value)) {
			arrayAppend(arguments.contextStack, value);
			try {
				return _renderNodes(arguments.node.children, arguments.contextStack, arguments.partials);
			} finally {
				arrayDeleteAt(arguments.contextStack, arrayLen(arguments.contextStack));
			}
		}

		return truthy ? _renderNodes(arguments.node.children, arguments.contextStack, arguments.partials) : "";
	}

	private struct function _lookup(required string name, required array contextStack, array nameParts = []) {
		if (arguments.name == ".") {
			return {
				found: arrayLen(arguments.contextStack) > 0,
				value: arrayLen(arguments.contextStack) > 0 ? arguments.contextStack[arrayLen(arguments.contextStack)] : ""
			};
		}

		var parts = arguments.nameParts;
		if (arrayLen(parts) == 0) {
			parts = _buildNameParts(arguments.name);
		}

		for (var i = arrayLen(arguments.contextStack); i >= 1; i--) {
			var resolved = _resolvePath(arguments.contextStack[i], parts);
			if (resolved.found) {
				return resolved;
			}
		}

		return { found: false, value: "" };
	}

	private array function _buildNameParts(required string name) {
		if (arguments.name == ".") {
			return ["."];
		}

		if (find(".", arguments.name) == 0) {
			return [arguments.name];
		}

		return listToArray(arguments.name, ".");
	}

	private struct function _resolvePath(required any context, required array parts) {
		var current = arguments.context;

		for (var i = 1; i <= arrayLen(arguments.parts); i++) {
			var key = arguments.parts[i];

			if (isStruct(current) && structKeyExists(current, key)) {
				current = current[key];
				continue;
			}

			if (isArray(current) && isNumeric(key)) {
				var index = val(key);
				if (index >= 1 && index <= arrayLen(current)) {
					current = current[index];
					continue;
				}
			}

			var dynamicStep = _resolveDynamicPathStep(current, key);
			if (dynamicStep.found) {
				current = dynamicStep.value;
				continue;
			}

			return { found: false, value: "" };
		}

		return { found: true, value: current };
	}

	private struct function _resolveDynamicPathStep(required any current, required string key) {
		var defaultResult = { found: false, value: "" };

		if (isSimpleValue(arguments.current) || isArray(arguments.current) || isStruct(arguments.current)) {
			return defaultResult;
		}

		if (!isObject(arguments.current)) {
			return defaultResult;
		}

		try {
			if (structKeyExists(arguments.current, arguments.key)) {
				return { found: true, value: arguments.current[arguments.key] };
			}
		} catch (any e) {
			return defaultResult;
		}

		return defaultResult;
	}

	private numeric function _getFunctionArity(required function lambdaFn) {
		var lambdaMetadata = getMetadata(arguments.lambdaFn);
		if (isStruct(lambdaMetadata) && structKeyExists(lambdaMetadata, "parameters") && isArray(lambdaMetadata.parameters)) {
			return arrayLen(lambdaMetadata.parameters);
		}

		return 0;
	}

	private string function _invokeVariableLambda(required function lambdaFn, required array contextStack, required struct partials) {
		var result = "";
		var currentContext = arguments.contextStack[arrayLen(arguments.contextStack)];
		var arity = _getFunctionArity(arguments.lambdaFn);

		if (arity <= 0) {
			result = arguments.lambdaFn();
		} else {
			result = arguments.lambdaFn(currentContext);
		}

		var rendered = _toString(result);
		if (find("{{", rendered) == 0) {
			return rendered;
		}

		return _renderWithStack(rendered, arguments.contextStack, arguments.partials);
	}

	private string function _invokeSectionLambda(
		required function lambdaFn,
		required string rawText,
		required array contextStack,
		required struct partials
	) {
		var sectionContextStack = arguments.contextStack;
		var sectionPartials = arguments.partials;

		var renderFn = function(required string templateText) {
			return _renderWithStack(templateText, sectionContextStack, sectionPartials);
		};

		var result = "";
		var arity = _getFunctionArity(arguments.lambdaFn);

		if (arity <= 0) {
			result = arguments.lambdaFn();
		} else if (arity == 1) {
			result = arguments.lambdaFn(arguments.rawText);
		} else {
			result = arguments.lambdaFn(arguments.rawText, renderFn);
		}

		var rendered = _toString(result);
		if (find("{{", rendered) == 0) {
			return rendered;
		}

		return _renderWithStack(rendered, arguments.contextStack, arguments.partials);
	}

	private string function _renderWithStack(required string template, required array contextStack, required struct partials) {
		var nestedAst = _getParsedTemplate(arguments.template);
		return _renderNodes(nestedAst, arguments.contextStack, arguments.partials);
	}

	private array function _getParsedTemplate(required string template) {
		if (!variables._cacheEnabled) {
			return parse(tokenize(arguments.template), arguments.template);
		}

		var cacheKey = _buildCacheKey(arguments.template);
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
					_touchCacheKey(cacheKey);
				}
			}
			return cachedAst;
		}

		var ast = parse(tokenize(arguments.template), arguments.template);
		lock name=variables._cacheLockName type="exclusive" timeout="5" {
			if (!structKeyExists(variables._templateCache, cacheKey)) {
				variables._templateCache[cacheKey] = ast;
			}

			_touchCacheKey(cacheKey);
			_evictCacheIfNeeded();
		}

		return ast;
	}

	private string function _buildCacheKey(required string template) {
		return len(arguments.template) & ":" & hash(arguments.template, "MD5");
	}

	private void function _touchCacheKey(required string cacheKey) {
		var keyIndex = arrayFind(variables._cacheOrder, arguments.cacheKey);
		var orderLen = arrayLen(variables._cacheOrder);

		if (keyIndex == orderLen && keyIndex > 0) {
			return;
		}

		if (keyIndex > 0) {
			arrayDeleteAt(variables._cacheOrder, keyIndex);
		}

		arrayAppend(variables._cacheOrder, arguments.cacheKey);
	}

	private void function _evictCacheIfNeeded() {
		var orderLen = arrayLen(variables._cacheOrder);
		var overflow = orderLen - variables._cacheMaxEntries;

		if (overflow <= 0) {
			return;
		}

		for (var i = 1; i <= overflow; i++) {
			var oldestKey = variables._cacheOrder[i];
			if (structKeyExists(variables._templateCache, oldestKey)) {
				structDelete(variables._templateCache, oldestKey);
			}
		}

		if (overflow >= orderLen) {
			variables._cacheOrder = [];
			return;
		}

		variables._cacheOrder = arraySlice(variables._cacheOrder, overflow + 1, orderLen - overflow);
	}

	private boolean function _isTruthy(any value = false) {
		if (isBoolean(arguments.value)) {
			return arguments.value;
		}

		if (isArray(arguments.value)) {
			return arrayLen(arguments.value) > 0;
		}

		if (isSimpleValue(arguments.value)) {
			if (isNumeric(arguments.value)) {
				return arguments.value != 0;
			}

			return len(arguments.value & "") > 0;
		}

		return true;
	}

	private string function _toString(any value) {
		try {
			if (isNull(arguments.value)) {
				return "";
			}

			return arguments.value & "";
		} catch (any e) {
			return serializeJSON(arguments.value);
		}
	}
}
