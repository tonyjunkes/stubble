component displayname="Stubble" singleton {
	variables._templateCache = {};
	variables._cacheLinks = {};
	variables._cacheHeadKey = "";
	variables._cacheTailKey = "";
	variables._cacheMaxEntries = 200;
	variables._cacheEnabled = true;
	variables._cacheLockName = "Stubble.TemplateCache";

	public array function tokenize(required string template, string openDelimiter = "{{", string closeDelimiter = "}}") {
		var tokens = [];
		var pos = 1;
		var totalLen = len(arguments.template);
		var currentOpenDelimiter = arguments.openDelimiter;
		var currentCloseDelimiter = arguments.closeDelimiter;

		while (pos <= totalLen) {
			var openDelimiterLength = len(currentOpenDelimiter);
			var closeDelimiterLength = len(currentCloseDelimiter);
			var openPos = find(currentOpenDelimiter, arguments.template, pos);

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

			if (
				currentOpenDelimiter == "{{"
				&& currentCloseDelimiter == "}}"
				&& (openPos + 2) <= totalLen
				&& mid(arguments.template, openPos, 3) == "{{{"
			) {
				if (openPos > pos) {
					arrayAppend(tokens, {
						type: "text",
						value: mid(arguments.template, pos, openPos - pos),
						startPos: pos,
						endPos: openPos - 1
					});
				}

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

			var closePos = find(currentCloseDelimiter, arguments.template, openPos + openDelimiterLength);
			if (closePos == 0) {
				throw(type = "Stubble.Tokenizer", message = "Unclosed tag.");
			}

			var content = trim(mid(arguments.template, openPos + openDelimiterLength, closePos - (openPos + openDelimiterLength)));
			var token = {
				type: "variable",
				name: content,
				openDelimiter: currentOpenDelimiter,
				closeDelimiter: currentCloseDelimiter,
				startPos: openPos,
				endPos: closePos + closeDelimiterLength - 1
			};

			if (len(content) > 0) {
				if (_isSetDelimiterTag(content)) {
					var delimiterPair = _parseDelimiterPair(content);
					token.type = "set_delimiter";
					token.openDelimiter = delimiterPair.openDelimiter;
					token.closeDelimiter = delimiterPair.closeDelimiter;
				} else {
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
						case "<":
							token.type = "parent_start";
							token.name = body;
							break;
						case "/":
							token.type = "section_end";
							token.name = body;
							if (left(token.name, 1) == chr(35)) {
								token.name = trim(mid(token.name, 2, len(token.name) - 1));
							}
							break;
						case "##":
							token.type = "section_start";
							token.name = body;
							break;
						case "$":
							token.type = "block_start";
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
			}

			if (_isStandaloneTokenType(token.type)) {
				var standaloneContext = _getStandaloneTagContext(arguments.template, pos, openPos, token.endPos);
				if (standaloneContext.isStandalone) {
					if (standaloneContext.leadingTextLength > 0) {
						arrayAppend(tokens, {
							type: "text",
							value: mid(arguments.template, pos, standaloneContext.leadingTextLength),
							startPos: pos,
							endPos: pos + standaloneContext.leadingTextLength - 1
						});
					}

					if (token.type == "partial") {
						token.indent = standaloneContext.indentation;
					}

					arrayAppend(tokens, token);
					if (token.type == "set_delimiter") {
						currentOpenDelimiter = token.openDelimiter;
						currentCloseDelimiter = token.closeDelimiter;
					}
					pos = standaloneContext.nextPos;
					continue;
				}
			}

			if (openPos > pos) {
				arrayAppend(tokens, {
					type: "text",
					value: mid(arguments.template, pos, openPos - pos),
					startPos: pos,
					endPos: openPos - 1
				});
			}

			arrayAppend(tokens, token);
			if (token.type == "set_delimiter") {
				currentOpenDelimiter = token.openDelimiter;
				currentCloseDelimiter = token.closeDelimiter;
			}
			pos = closePos + closeDelimiterLength;
		}

		return tokens;
	}

	private boolean function _isStandaloneTokenType(required string tokenType) {
		return listFindNoCase("comment,partial,section_start,section_end,inverted_start,set_delimiter", arguments.tokenType) > 0;
	}

	private boolean function _isSetDelimiterTag(required string content) {
		return len(arguments.content) >= 2 && left(arguments.content, 1) == "=" && right(arguments.content, 1) == "=";
	}

	private struct function _parseDelimiterPair(required string content) {
		var delimiterDefinition = trim(mid(arguments.content, 2, len(arguments.content) - 2));
		var normalizedDefinition = trim(reReplace(delimiterDefinition, "\s+", " ", "all"));
		var delimiterParts = len(normalizedDefinition) ? listToArray(normalizedDefinition, " ") : [];

		if (arrayLen(delimiterParts) != 2) {
			throw(type = "Stubble.Tokenizer", message = "Invalid set delimiter tag.");
		}

		return {
			openDelimiter: delimiterParts[1],
			closeDelimiter: delimiterParts[2]
		};
	}

	private struct function _getStandaloneTagContext(
		required string template,
		required numeric currentPos,
		required numeric openPos,
		required numeric tokenEndPos
	) {
		var lineStartPos = _getLineStartPos(arguments.template, arguments.openPos);
		var leadingWhitespace = mid(arguments.template, lineStartPos, arguments.openPos - lineStartPos);

		if (!_containsOnlyStandaloneWhitespace(leadingWhitespace)) {
			return { isStandalone: false };
		}

		var afterTokenPos = arguments.tokenEndPos + 1;
		var nextLineBreakPos = _findNextLineBreakPos(arguments.template, afterTokenPos);

		if (nextLineBreakPos == 0) {
			var trailingToEnd = afterTokenPos <= len(arguments.template)
				? mid(arguments.template, afterTokenPos, len(arguments.template) - afterTokenPos + 1)
				: "";

			if (!_containsOnlyStandaloneWhitespace(trailingToEnd)) {
				return { isStandalone: false };
			}

			return {
				isStandalone: true,
				leadingTextLength: max(0, lineStartPos - arguments.currentPos),
				indentation: leadingWhitespace,
				nextPos: len(arguments.template) + 1
			};
		}

		var trailingWhitespace = nextLineBreakPos > afterTokenPos
			? mid(arguments.template, afterTokenPos, nextLineBreakPos - afterTokenPos)
			: "";

		if (!_containsOnlyStandaloneWhitespace(trailingWhitespace)) {
			return { isStandalone: false };
		}

		return {
			isStandalone: true,
			leadingTextLength: max(0, lineStartPos - arguments.currentPos),
			indentation: leadingWhitespace,
			nextPos: nextLineBreakPos + _getLineBreakLength(arguments.template, nextLineBreakPos)
		};
	}

	private numeric function _getLineStartPos(required string template, required numeric position) {
		var prefix = arguments.position > 1 ? left(arguments.template, arguments.position - 1) : "";
		var lastLineFeed = _findLastStringPosition(chr(10), prefix);
		var lastCarriageReturn = _findLastStringPosition(chr(13), prefix);

		return max(lastLineFeed, lastCarriageReturn) + 1;
	}

	private numeric function _findLastStringPosition(required string needle, required string haystack) {
		var pos = arguments.haystack.lastIndexOf(arguments.needle);
		return pos == -1 ? 0 : pos + 1;
	}

	private numeric function _findNextLineBreakPos(required string template, required numeric startPos) {
		if (arguments.startPos > len(arguments.template)) {
			return 0;
		}

		var nextLineFeed = find(chr(10), arguments.template, arguments.startPos);
		var nextCarriageReturn = find(chr(13), arguments.template, arguments.startPos);

		if (nextLineFeed == 0) {
			return nextCarriageReturn;
		}

		if (nextCarriageReturn == 0) {
			return nextLineFeed;
		}

		return min(nextLineFeed, nextCarriageReturn);
	}

	private numeric function _getLineBreakLength(required string template, required numeric lineBreakPos) {
		if (
			mid(arguments.template, arguments.lineBreakPos, 1) == chr(13)
			&& arguments.lineBreakPos < len(arguments.template)
			&& mid(arguments.template, arguments.lineBreakPos + 1, 1) == chr(10)
		) {
			return 2;
		}

		return 1;
	}

	private boolean function _containsOnlyStandaloneWhitespace(required string value) {
		return len(reReplace(arguments.value, "[ \t]", "", "all")) == 0;
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
					arrayAppend(current.children, {
						type: "partial",
						name: token.name,
						indent: structKeyExists(token, "indent") ? token.indent : ""
					});
					break;

				case "set_delimiter":
					break;

				case "comment":
					break;

				case "section_start":
				case "inverted_start":
					case "block_start":
					case "parent_start":
					var node = {
							type: _getContainerNodeType(token.type),
						name: token.name,
						children: [],
							startPos: token.startPos,
							openEndPos: token.endPos,
							endPos: 0,
						rawStartPos: token.endPos + 1,
						rawText: ""
					};

						if (token.type == "section_start" || token.type == "inverted_start") {
							node.nameParts = _buildNameParts(token.name);
							node.renderOpenDelimiter = token.openDelimiter;
							node.renderCloseDelimiter = token.closeDelimiter;
						}

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
					stack[openIndex].endPos = token.endPos;

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

		_finalizeParsedNodes(root.children, arguments.template);

		return root.children;
	}

	public string function render(required string template, any data = {}, struct partials = {}) {
		var ast = _getParsedTemplate(arguments.template);
		var contextStack = [arguments.data];
		return _renderNodes(ast, contextStack, arguments.partials, {});
	}

	public void function configureCache(boolean enabled = true, numeric maxEntries = 200) {
		lock name=variables._cacheLockName type="exclusive" timeout="5" {
			variables._cacheEnabled = arguments.enabled;
			variables._cacheMaxEntries = max(1, int(arguments.maxEntries));

			if (!variables._cacheEnabled) {
				_resetCacheState();
			} else {
				_evictCacheIfNeeded();
			}
		}
	}

	public void function clearCache() {
		lock name=variables._cacheLockName type="exclusive" timeout="5" {
			_resetCacheState();
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

	private void function _resetCacheState() {
		variables._templateCache = {};
		variables._cacheLinks = {};
		variables._cacheHeadKey = "";
		variables._cacheTailKey = "";
	}

	private string function _renderNodes(
		required array nodes,
		required array contextStack,
		required struct partials,
		struct blockOverrides = {}
	) {
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
						value = _invokeVariableLambda(value, arguments.contextStack, arguments.partials, arguments.blockOverrides);
					}

					var renderedValue = _toString(value);
					if (node.type == "variable") {
						arrayAppend(outputChunks, _escapeHtml(renderedValue));
					} else {
						arrayAppend(outputChunks, renderedValue);
					}
					break;

				case "partial":
					var resolvedPartialName = _resolvePartialName(node.name, arguments.contextStack);
					if (resolvedPartialName.found && structKeyExists(arguments.partials, resolvedPartialName.name)) {
						var partialTemplate = arguments.partials[resolvedPartialName.name];
						if (isCustomFunction(partialTemplate)) {
							partialTemplate = partialTemplate();
						}

						var renderedPartialTemplate = _toString(partialTemplate);
						if (len(node.indent)) {
							renderedPartialTemplate = _indentPartialTemplate(renderedPartialTemplate, node.indent);
						}

						arrayAppend(outputChunks, _renderWithStack(renderedPartialTemplate, arguments.contextStack, arguments.partials, "{{", "}}", arguments.blockOverrides));
					}
					break;

				case "parent":
					arrayAppend(outputChunks, _renderParent(node, arguments.contextStack, arguments.partials, arguments.blockOverrides));
					break;

				case "block":
					arrayAppend(outputChunks, _renderBlock(node, arguments.contextStack, arguments.partials, arguments.blockOverrides));
					break;

				case "section":
				case "inverted":
					arrayAppend(outputChunks, _renderSection(node, arguments.contextStack, arguments.partials, arguments.blockOverrides));
					break;

				default:
					throw(type = "Stubble.Renderer", message = "Unsupported node type: " & node.type);
			}
		}

		return arrayToList(outputChunks, "");
	}

	private struct function _resolvePartialName(required string partialName, required array contextStack) {
		var trimmedPartialName = trim(arguments.partialName);
		if (!(len(trimmedPartialName) > 0 && left(trimmedPartialName, 1) == "*")) {
			return {
				found: len(trimmedPartialName) > 0,
				name: trimmedPartialName
			};
		}

		var dynamicName = trim(mid(trimmedPartialName, 2, len(trimmedPartialName) - 1));
		if (!len(dynamicName)) {
			return { found: false, name: "" };
		}

		var lookup = _lookup(dynamicName, arguments.contextStack, _buildNameParts(dynamicName));
		if (!lookup.found || isNull(lookup.value)) {
			return { found: false, name: "" };
		}

		return {
			found: true,
			name: _toString(lookup.value)
		};
	}

	private string function _renderSection(
		required struct node,
		required array contextStack,
		required struct partials,
		struct blockOverrides = {}
	) {
		var lookup = _lookup(arguments.node.name, arguments.contextStack, arguments.node.nameParts);
		var found = lookup.found;
		var value = found ? lookup.value : "";
		var truthy = found && _isTruthy(value);

		if (arguments.node.type == "inverted") {
			return truthy ? "" : _renderNodes(arguments.node.children, arguments.contextStack, arguments.partials, arguments.blockOverrides);
		}

		if (!found) {
			return "";
		}

		if (isCustomFunction(value)) {
			return _invokeSectionLambda(
				value,
				arguments.node.rawText,
				arguments.contextStack,
				arguments.partials,
				arguments.blockOverrides,
				arguments.node.renderOpenDelimiter,
				arguments.node.renderCloseDelimiter
			);
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
					arrayAppend(arrayOutputChunks, _renderNodes(arguments.node.children, arguments.contextStack, arguments.partials, arguments.blockOverrides));
				} finally {
					arrayDeleteAt(arguments.contextStack, arrayLen(arguments.contextStack));
				}
			}
			return arrayToList(arrayOutputChunks, "");
		}

		if (isStruct(value) || isObject(value)) {
			arrayAppend(arguments.contextStack, value);
			try {
				return _renderNodes(arguments.node.children, arguments.contextStack, arguments.partials, arguments.blockOverrides);
			} finally {
				arrayDeleteAt(arguments.contextStack, arrayLen(arguments.contextStack));
			}
		}

		if (!truthy) {
			return "";
		}

		arrayAppend(arguments.contextStack, value);
		try {
			return _renderNodes(arguments.node.children, arguments.contextStack, arguments.partials, arguments.blockOverrides);
		} finally {
			arrayDeleteAt(arguments.contextStack, arrayLen(arguments.contextStack));
		}
	}

	private string function _renderParent(
		required struct node,
		required array contextStack,
		required struct partials,
		struct blockOverrides = {}
	) {
		var resolvedParentName = _resolvePartialName(arguments.node.name, arguments.contextStack);
		if (!resolvedParentName.found || !structKeyExists(arguments.partials, resolvedParentName.name)) {
			return "";
		}

		var parentTemplate = arguments.partials[resolvedParentName.name];
		if (isCustomFunction(parentTemplate)) {
			parentTemplate = parentTemplate();
		}

		var effectiveOverrides = _collectBlockOverrides(arguments.node.children);
		if (structCount(arguments.blockOverrides)) {
			structAppend(effectiveOverrides, arguments.blockOverrides, true);
		}

		parentTemplate = _toString(parentTemplate);
		if (len(arguments.node.expansionIndent)) {
			parentTemplate = _indentPartialTemplate(parentTemplate, arguments.node.expansionIndent);
		}

		return _renderWithStack(parentTemplate, arguments.contextStack, arguments.partials, "{{", "}}", effectiveOverrides);
	}

	private string function _renderBlock(
		required struct node,
		required array contextStack,
		required struct partials,
		struct blockOverrides = {}
	) {
		var sourceNode = structKeyExists(arguments.blockOverrides, arguments.node.name)
			? arguments.blockOverrides[arguments.node.name]
			: arguments.node;

		var blockTemplate = _normalizeBlockSourceText(sourceNode.rawText, sourceNode.stripLeadingLineBreak);
		if (len(sourceNode.definitionIndent)) {
			blockTemplate = _dedentTemplate(blockTemplate, sourceNode.definitionIndent);
		}

		if (len(arguments.node.expansionIndent)) {
			blockTemplate = _indentPartialTemplate(blockTemplate, arguments.node.expansionIndent);
		}

		var renderedBlock = _renderWithStack(blockTemplate, arguments.contextStack, arguments.partials, "{{", "}}", arguments.blockOverrides);
		if (len(arguments.node.trailingLineBreak) && len(renderedBlock) && !_endsWithLineBreak(renderedBlock)) {
			renderedBlock &= arguments.node.trailingLineBreak;
		}

		return renderedBlock;
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

		if (arrayLen(parts) == 1) {
			for (var i = arrayLen(arguments.contextStack); i >= 1; i--) {
				var resolved = _resolvePath(arguments.contextStack[i], parts);
				if (resolved.found) {
					return resolved;
				}
			}

			return { found: false, value: "" };
		}

		var firstPart = [parts[1]];
		var remainingParts = arraySlice(parts, 2, arrayLen(parts) - 1);

		for (var i = arrayLen(arguments.contextStack); i >= 1; i--) {
			var resolved = _resolvePath(arguments.contextStack[i], firstPart);
			if (resolved.found) {
				if (isNull(resolved.value)) {
					return { found: false, value: "" };
				}

				return _resolvePath(resolved.value, remainingParts);
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

		if (
			!structKeyExists(arguments.current, arguments.key) &&
			!_hasDynamicObjectAccessor(arguments.current, arguments.key)
		) {
			return defaultResult;
		}

		return { found: true, value: arguments.current[arguments.key] };

		return defaultResult;
	}

	private boolean function _hasDynamicObjectAccessor(required any current, required string key) {
		var accessorMethodNames = _buildAccessorMethodNames(arguments.key);
		var metadata = getMetadata(arguments.current);

		if (isStruct(metadata)) {
			if (structKeyExists(metadata, "functions") && isArray(metadata.functions)) {
				for (var fn in metadata.functions) {
					if (
						isStruct(fn) &&
						structKeyExists(fn, "name") &&
						(
							compareNoCase(fn.name, accessorMethodNames[1]) == 0 ||
							compareNoCase(fn.name, accessorMethodNames[2]) == 0
						)
					) {
						var parameters = structKeyExists(fn, "parameters") && isArray(fn.parameters) ? fn.parameters : [];
						if (arrayLen(parameters) == 0) {
							return true;
						}
					}
				}
			}
		}

		try {
			var methods = arguments.current.getClass().getMethods();
			for (var method in methods) {
				var methodName = method.getName();
				if (
					(
						compareNoCase(methodName, accessorMethodNames[1]) == 0 ||
						compareNoCase(methodName, accessorMethodNames[2]) == 0
					) &&
					method.getParameterCount() == 0
				) {
					return true;
				}
			}

			arguments.current.getClass().getField(arguments.key);
			return true;
		} catch (any e) {
			return false;
		}

		return false;
	}

	private array function _buildAccessorMethodNames(required string key) {
		var normalizedKey = trim(arguments.key);
		if (!len(normalizedKey)) {
			return ["", ""];
		}

		var accessorSuffix = uCase(left(normalizedKey, 1)) & mid(normalizedKey, 2, len(normalizedKey) - 1);
		return ["get" & accessorSuffix, "is" & accessorSuffix];
	}

	private numeric function _getFunctionArity(required function lambdaFn) {
		var lambdaMetadata = getMetadata(arguments.lambdaFn);
		if (isStruct(lambdaMetadata) && structKeyExists(lambdaMetadata, "parameters") && isArray(lambdaMetadata.parameters)) {
			return arrayLen(lambdaMetadata.parameters);
		}

		return 0;
	}

	private string function _invokeVariableLambda(
		required function lambdaFn,
		required array contextStack,
		required struct partials,
		struct blockOverrides = {}
	) {
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

		return _renderWithStack(rendered, arguments.contextStack, arguments.partials, "{{", "}}", arguments.blockOverrides);
	}

	private string function _invokeSectionLambda(
		required function lambdaFn,
		required string rawText,
		required array contextStack,
		required struct partials,
		struct blockOverrides = {},
		required string openDelimiter,
		required string closeDelimiter
	) {
		var sectionContextStack = arguments.contextStack;
		var sectionPartials = arguments.partials;
		var sectionBlockOverrides = arguments.blockOverrides;
		var sectionOpenDelimiter = arguments.openDelimiter;
		var sectionCloseDelimiter = arguments.closeDelimiter;

		var renderFn = function(required string templateText) {
			return _renderWithStack(
				templateText,
				sectionContextStack,
				sectionPartials,
				sectionOpenDelimiter,
				sectionCloseDelimiter,
				sectionBlockOverrides
			);
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

		return _renderWithStack(
			rendered,
			arguments.contextStack,
			arguments.partials,
			arguments.openDelimiter,
			arguments.closeDelimiter,
			arguments.blockOverrides
		);
	}

	private string function _renderWithStack(
		required string template,
		required array contextStack,
		required struct partials,
		string openDelimiter = "{{",
		string closeDelimiter = "}}",
		struct blockOverrides = {}
	) {
		var nestedAst = _getParsedTemplate(arguments.template, arguments.openDelimiter, arguments.closeDelimiter);
		return _renderNodes(nestedAst, arguments.contextStack, arguments.partials, arguments.blockOverrides);
	}

	private string function _getContainerNodeType(required string tokenType) {
		switch (arguments.tokenType) {
			case "section_start":
				return "section";
			case "inverted_start":
				return "inverted";
			case "block_start":
				return "block";
			case "parent_start":
				return "parent";
		}

		throw(type = "Stubble.Parser", message = "Unsupported container token type: " & arguments.tokenType);
	}

	private struct function _collectBlockOverrides(required array nodes) {
		var overrides = {};

		for (var i = 1; i <= arrayLen(arguments.nodes); i++) {
			var node = arguments.nodes[i];
			if (node.type == "block") {
				overrides[node.name] = node;
			}
		}

		return overrides;
	}

	private void function _finalizeParsedNodes(required array nodes, required string template) {
		for (var i = 1; i <= arrayLen(arguments.nodes); i++) {
			var node = arguments.nodes[i];

			if (structKeyExists(node, "children") && isArray(node.children) && arrayLen(node.children)) {
				_finalizeParsedNodes(node.children, arguments.template);
			}

			if (!listFindNoCase("block,parent", node.type)) {
				continue;
			}

			var nodeContext = _getInheritanceNodeContext(arguments.template, node);
			node.expansionIndent = nodeContext.expansionIndent;
			node.stripLeadingLineBreak = node.type == "block" ? nodeContext.stripLeadingLineBreak : false;
			node.trailingLineBreak = node.type == "block" ? nodeContext.trailingLineBreak : "";
			var normalizedBlockSource = _normalizeBlockSourceText(node.rawText, nodeContext.stripLeadingLineBreak);
			node.definitionIndent = node.type == "block" && _containsLineBreak(normalizedBlockSource)
				? _getCommonLeadingIndentation(normalizedBlockSource)
				: "";

			if (nodeContext.trimLeadingLength > 0 && i > 1 && arguments.nodes[i - 1].type == "text") {
				var previousValue = arguments.nodes[i - 1].value;
				arguments.nodes[i - 1].value = nodeContext.trimLeadingLength >= len(previousValue)
					? ""
					: left(previousValue, len(previousValue) - nodeContext.trimLeadingLength);
			}

			if (nodeContext.trimTrailingLength > 0 && i < arrayLen(arguments.nodes) && arguments.nodes[i + 1].type == "text") {
				var nextValue = arguments.nodes[i + 1].value;
				arguments.nodes[i + 1].value = nodeContext.trimTrailingLength >= len(nextValue)
					? ""
					: mid(nextValue, nodeContext.trimTrailingLength + 1, len(nextValue) - nodeContext.trimTrailingLength);
			}
		}
	}

	private struct function _getInheritanceNodeContext(required string template, required struct node) {
		var lineStartPos = _getLineStartPos(arguments.template, arguments.node.startPos);
		var leadingWhitespace = mid(arguments.template, lineStartPos, arguments.node.startPos - lineStartPos);
		var hasStandaloneLeading = _containsOnlyStandaloneWhitespace(leadingWhitespace);
		var hasInlineContent = !_containsLineBreak(arguments.node.rawText) && len(trim(arguments.node.rawText));

		var afterNodePos = arguments.node.endPos + 1;
		var nextLineBreakPos = _findNextLineBreakPos(arguments.template, afterNodePos);
		var trailingWhitespace = "";
		var trailingLength = 0;
		var trailingLineBreak = "";
		var hasStandaloneTrailing = false;

		if (nextLineBreakPos == 0) {
			trailingWhitespace = afterNodePos <= len(arguments.template)
				? mid(arguments.template, afterNodePos, len(arguments.template) - afterNodePos + 1)
				: "";
			hasStandaloneTrailing = _containsOnlyStandaloneWhitespace(trailingWhitespace);
			trailingLength = len(trailingWhitespace);
		} else {
			trailingWhitespace = nextLineBreakPos > afterNodePos
				? mid(arguments.template, afterNodePos, nextLineBreakPos - afterNodePos)
				: "";
			hasStandaloneTrailing = _containsOnlyStandaloneWhitespace(trailingWhitespace);
			trailingLength = len(trailingWhitespace) + _getLineBreakLength(arguments.template, nextLineBreakPos);
			trailingLineBreak = mid(arguments.template, nextLineBreakPos, _getLineBreakLength(arguments.template, nextLineBreakPos));
		}

		var afterOpenPos = arguments.node.openEndPos + 1;
		var nextOpenLineBreakPos = _findNextLineBreakPos(arguments.template, afterOpenPos);
		var openRemainder = "";
		if (nextOpenLineBreakPos > 0) {
			openRemainder = nextOpenLineBreakPos > afterOpenPos
				? mid(arguments.template, afterOpenPos, nextOpenLineBreakPos - afterOpenPos)
				: "";
		} else if (afterOpenPos <= len(arguments.template)) {
			openRemainder = mid(arguments.template, afterOpenPos, len(arguments.template) - afterOpenPos + 1);
		}

		var stripLeadingLineBreak = nextOpenLineBreakPos > 0 && _containsOnlyStandaloneWhitespace(openRemainder);
		var isStandaloneNode = hasStandaloneLeading && hasStandaloneTrailing && !hasInlineContent;
		var expansionIndent = isStandaloneNode ? leadingWhitespace : "";
		if (arguments.node.type == "block" && !len(expansionIndent) && stripLeadingLineBreak) {
			expansionIndent = _getCommonLeadingIndentation(_normalizeBlockSourceText(arguments.node.rawText, true));
		}

		return {
			trimLeadingLength: isStandaloneNode ? len(leadingWhitespace) : 0,
			trimTrailingLength: isStandaloneNode ? trailingLength : 0,
			expansionIndent: expansionIndent,
			stripLeadingLineBreak: stripLeadingLineBreak,
			trailingLineBreak: isStandaloneNode ? trailingLineBreak : ""
		};
	}

	private boolean function _containsLineBreak(required string value) {
		return find(chr(10), arguments.value) > 0 || find(chr(13), arguments.value) > 0;
	}

	private boolean function _endsWithLineBreak(required string value) {
		if (!len(arguments.value)) {
			return false;
		}

		return right(arguments.value, 1) == chr(10)
			|| right(arguments.value, 1) == chr(13)
			|| right(arguments.value, 2) == chr(13) & chr(10);
	}

	private string function _normalizeBlockSourceText(required string templateText, boolean stripLeadingLineBreak = false) {
		var normalizedText = arguments.templateText;
		if (!arguments.stripLeadingLineBreak || !len(normalizedText)) {
			return normalizedText;
		}

		if (left(normalizedText, 2) == chr(13) & chr(10)) {
			return mid(normalizedText, 3, len(normalizedText) - 2);
		}

		if (left(normalizedText, 1) == chr(13) || left(normalizedText, 1) == chr(10)) {
			return mid(normalizedText, 2, len(normalizedText) - 1);
		}

		return normalizedText;
	}

	private string function _getCommonLeadingIndentation(required string templateText) {
		var normalizedText = replace(arguments.templateText, chr(13) & chr(10), chr(10), "all");
		normalizedText = replace(normalizedText, chr(13), chr(10), "all");
		var lines = listToArray(normalizedText, chr(10), true);
		var commonIndent = "";
		var hasContent = false;

		for (var i = 1; i <= arrayLen(lines); i++) {
			var line = lines[i];
			if (!len(trim(line))) {
				continue;
			}

			var lineIndentMatch = reFind("^[ \t]*", line, 1, true);
			var lineIndent = lineIndentMatch.len[1] > 0 ? left(line, lineIndentMatch.len[1]) : "";

			if (!hasContent) {
				commonIndent = lineIndent;
				hasContent = true;
				continue;
			}

			commonIndent = _getCommonWhitespacePrefix(commonIndent, lineIndent);
			if (!len(commonIndent)) {
				break;
			}
		}

		return hasContent ? commonIndent : "";
	}

	private string function _getCommonWhitespacePrefix(required string firstIndent, required string secondIndent) {
		var maxLength = min(len(arguments.firstIndent), len(arguments.secondIndent));
		var prefix = "";

		for (var i = 1; i <= maxLength; i++) {
			if (mid(arguments.firstIndent, i, 1) != mid(arguments.secondIndent, i, 1)) {
				break;
			}

			prefix &= mid(arguments.firstIndent, i, 1);
		}

		return prefix;
	}

	private string function _dedentTemplate(required string templateText, required string indentation) {
		if (!len(arguments.templateText) || !len(arguments.indentation)) {
			return arguments.templateText;
		}

		var output = "";
		var pos = 1;
		var totalLen = len(arguments.templateText);

		while (pos <= totalLen) {
			var nextLineBreakPos = _findNextLineBreakPos(arguments.templateText, pos);
			var lineText = nextLineBreakPos == 0
				? mid(arguments.templateText, pos, totalLen - pos + 1)
				: mid(arguments.templateText, pos, nextLineBreakPos - pos);
			var lineBreak = "";

			if (nextLineBreakPos > 0) {
				lineBreak = mid(arguments.templateText, nextLineBreakPos, _getLineBreakLength(arguments.templateText, nextLineBreakPos));
			}

			if (len(trim(lineText)) && left(lineText, len(arguments.indentation)) == arguments.indentation) {
				lineText = mid(lineText, len(arguments.indentation) + 1, len(lineText) - len(arguments.indentation));
			}

			output &= lineText & lineBreak;
			pos = nextLineBreakPos == 0 ? totalLen + 1 : nextLineBreakPos + len(lineBreak);
		}

		return output;
	}

	private string function _indentPartialTemplate(required string template, required string indentation) {
		if (!len(arguments.template) || !len(arguments.indentation)) {
			return arguments.template;
		}

		var output = arguments.indentation;
		var pos = 1;
		var totalLen = len(arguments.template);

		while (pos <= totalLen) {
			var currentChar = mid(arguments.template, pos, 1);
			output &= currentChar;

			if (currentChar == chr(13)) {
				if (pos < totalLen && mid(arguments.template, pos + 1, 1) == chr(10)) {
					pos++;
					output &= chr(10);
				}

				if (pos < totalLen) {
					output &= arguments.indentation;
				}
			} else if (currentChar == chr(10) && pos < totalLen) {
				output &= arguments.indentation;
			}

			pos++;
		}

		return output;
	}

	private array function _getParsedTemplate(required string template, string openDelimiter = "{{", string closeDelimiter = "}}") {
		if (!variables._cacheEnabled) {
			return parse(
				tokenize(arguments.template, arguments.openDelimiter, arguments.closeDelimiter),
				arguments.template
			);
		}

		var cacheKey = _buildCacheKey(arguments.template, arguments.openDelimiter, arguments.closeDelimiter);
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

		var ast = parse(
			tokenize(arguments.template, arguments.openDelimiter, arguments.closeDelimiter),
			arguments.template
		);
		lock name=variables._cacheLockName type="exclusive" timeout="5" {
			if (!structKeyExists(variables._templateCache, cacheKey)) {
				variables._templateCache[cacheKey] = ast;
			}

			_touchCacheKey(cacheKey);
			_evictCacheIfNeeded();
		}

		return ast;
	}

	private string function _buildCacheKey(
		required string template,
		string openDelimiter = "{{",
		string closeDelimiter = "}}"
	) {
		return len(arguments.template) & ":" & hash(
			arguments.openDelimiter & chr( 0 ) & arguments.closeDelimiter & chr( 0 ) & arguments.template,
			"MD5"
		);
	}

	private void function _touchCacheKey(required string cacheKey) {
		if (!structKeyExists(variables._templateCache, arguments.cacheKey)) {
			return;
		}

		if (!structKeyExists(variables._cacheLinks, arguments.cacheKey)) {
			variables._cacheLinks[arguments.cacheKey] = {
				prev: variables._cacheTailKey,
				next: ""
			};

			if (len(variables._cacheTailKey) && structKeyExists(variables._cacheLinks, variables._cacheTailKey)) {
				variables._cacheLinks[variables._cacheTailKey].next = arguments.cacheKey;
			} else {
				variables._cacheHeadKey = arguments.cacheKey;
			}

			variables._cacheTailKey = arguments.cacheKey;
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

		if (len(variables._cacheTailKey) && structKeyExists(variables._cacheLinks, variables._cacheTailKey)) {
			variables._cacheLinks[variables._cacheTailKey].next = arguments.cacheKey;
		} else {
			variables._cacheHeadKey = arguments.cacheKey;
		}

		variables._cacheTailKey = arguments.cacheKey;
	}

	private void function _removeCacheKey(required string cacheKey) {
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

	private void function _evictCacheIfNeeded() {
		while (structCount(variables._templateCache) > variables._cacheMaxEntries && len(variables._cacheHeadKey)) {
			_removeCacheKey(variables._cacheHeadKey);
		}
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

	private string function _escapeHtml(required string value) {
		var escaped = replace(arguments.value, "&", "&amp;", "all");
		escaped = replace(escaped, "<", "&lt;", "all");
		escaped = replace(escaped, ">", "&gt;", "all");
		escaped = replace(escaped, chr(34), "&quot;", "all");
		escaped = replace(escaped, chr(39), "&##x27;", "all");
		escaped = replace(escaped, "/", "&##x2f;", "all");

		return escaped;
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
