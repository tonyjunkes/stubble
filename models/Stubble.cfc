component displayname="Stubble" singleton {
	variables._tokenizer = new Tokenizer();
	variables._parser = new Parser();
	variables._cache = new TemplateCache();

	public Stubble function init(
		Tokenizer tokenizer,
		Parser parser,
		TemplateCache cache
	) {
		if (!isNull(arguments.tokenizer)) {
			variables._tokenizer = arguments.tokenizer;
		}

		if (!isNull(arguments.parser)) {
			variables._parser = arguments.parser;
		}

		if (!isNull(arguments.cache)) {
			variables._cache = arguments.cache;
		}

		return this;
	}

	public array function tokenize(
		required string template,
		string openDelimiter = "{{",
		string closeDelimiter = "}}"
	) {
		return variables._tokenizer.tokenize(argumentCollection = arguments);
	}

	public array function parse(required array tokens, required string template) {
		return variables._parser.parse(argumentCollection = arguments);
	}

	public string function render(required string template, any data = {}, struct partials = {}) {
		var ast = _getParsedTemplate(arguments.template);
		var contextStack = [arguments.data];
		return _renderNodes(ast, contextStack, arguments.partials, {});
	}

	public void function configureCache(boolean enabled = true, numeric maxEntries = 200) {
		variables._cache.configure(argumentCollection = arguments);
	}

	public void function clearCache() {
		variables._cache.clear();
	}

	public struct function getCacheStats() {
		return variables._cache.getStats();
	}

	// --- Rendering ---

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
						value = _invokeVariableLambda(
							value,
							arguments.contextStack,
							arguments.partials,
							arguments.blockOverrides
						);
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

						arrayAppend(outputChunks, _renderWithStack(
							renderedPartialTemplate,
							arguments.contextStack,
							arguments.partials,
							"{{",
							"}}",
							arguments.blockOverrides
						));
					}
					break;

				case "parent":
					arrayAppend(
						outputChunks,
						_renderParent(
							node,
							arguments.contextStack,
							arguments.partials,
							arguments.blockOverrides
						)
					);
					break;

				case "block":
					arrayAppend(
						outputChunks,
						_renderBlock(
							node,
							arguments.contextStack,
							arguments.partials,
							arguments.blockOverrides
						)
					);
					break;

				case "section":
				case "inverted":
					arrayAppend(
						outputChunks,
						_renderSection(
							node,
							arguments.contextStack,
							arguments.partials,
							arguments.blockOverrides
						)
					);
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

		var lookup = _lookup(
			dynamicName,
			arguments.contextStack,
			variables._parser.buildNameParts(dynamicName)
		);
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
			return truthy ? "" : _renderNodes(
				arguments.node.children,
				arguments.contextStack,
				arguments.partials,
				arguments.blockOverrides
			);
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
				arrayAppend(
					arrayOutputChunks,
					_withContext(
						arguments.contextStack,
						value[i],
						arguments.node,
						arguments.partials,
						arguments.blockOverrides
					)
				);
			}
			return arrayToList(arrayOutputChunks, "");
		}

		if (isStruct(value) || isObject(value)) {
			return _withContext(
				arguments.contextStack,
				value,
				arguments.node,
				arguments.partials,
				arguments.blockOverrides
			);
		}

		if (!truthy) {
			return "";
		}

		return _withContext(
			arguments.contextStack,
			value,
			arguments.node,
			arguments.partials,
			arguments.blockOverrides
		);
	}

	private string function _withContext(
		required array contextStack,
		required any contextValue,
		required struct node,
		required struct partials,
		required struct blockOverrides
	) {
		arrayAppend(arguments.contextStack, arguments.contextValue);
		try {
			return _renderNodes(
				arguments.node.children,
				arguments.contextStack,
				arguments.partials,
				arguments.blockOverrides
			);
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

		return _renderWithStack(
			parentTemplate,
			arguments.contextStack,
			arguments.partials,
			"{{",
			"}}",
			effectiveOverrides
		);
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

		var blockTemplate = StringUtil::normalizeBlockSourceText(sourceNode.rawText, sourceNode.stripLeadingLineBreak);
		if (len(sourceNode.definitionIndent)) {
			blockTemplate = _dedentTemplate(blockTemplate, sourceNode.definitionIndent);
		}

		if (len(arguments.node.expansionIndent)) {
			blockTemplate = _indentPartialTemplate(blockTemplate, arguments.node.expansionIndent);
		}

		var renderedBlock = _renderWithStack(
			blockTemplate,
			arguments.contextStack,
			arguments.partials,
			"{{",
			"}}",
			arguments.blockOverrides
		);
		if (len(arguments.node.trailingLineBreak) && len(renderedBlock) && !StringUtil::endsWithLineBreak(renderedBlock)) {
			renderedBlock &= arguments.node.trailingLineBreak;
		}

		return renderedBlock;
	}

	// --- Context Lookup ---

	private struct function _lookup(
		required string name,
		required array contextStack,
		array nameParts = []
	) {
		var stack = arguments.contextStack;
		var stackCount = arrayLen(stack);

		if (arguments.name == ".") {
			return {
				found: stackCount > 0,
				value: stackCount > 0 ? stack[stackCount] : ""
			};
		}

		var parts = arguments.nameParts;
		if (arrayLen(parts) == 0) {
			parts = variables._parser.buildNameParts(arguments.name);
		}

		if (arrayLen(parts) == 1) {
			for (var i = stackCount; i >= 1; i--) {
				var resolved = _resolvePath(stack[i], parts);
				if (resolved.found) {
					return resolved;
				}
			}

			return { found: false, value: "" };
		}

		var firstPart = [parts[1]];
		var remainingParts = arraySlice(parts, 2, arrayLen(parts) - 1);

		for (var i = stackCount; i >= 1; i--) {
			var resolved = _resolvePath(stack[i], firstPart);
			if (resolved.found) {
				if (isNull(resolved.value)) {
					return { found: false, value: "" };
				}

				return _resolvePath(resolved.value, remainingParts);
			}
		}

		return { found: false, value: "" };
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

	// --- Lambda Handling ---

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

		return _renderWithStack(
			rendered,
			arguments.contextStack,
			arguments.partials,
			"{{",
			"}}",
			arguments.blockOverrides
		);
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

	// --- Template Processing ---

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

	private array function _getParsedTemplate(
		required string template,
		string openDelimiter = "{{",
		string closeDelimiter = "}}"
	) {
		var tokenizer = variables._tokenizer;
		var parser = variables._parser;

		return variables._cache.getOrSet(
			arguments.template,
			arguments.openDelimiter,
			arguments.closeDelimiter,
			function(required string template, required string openDelimiter, required string closeDelimiter) {
				return parser.parse(
					tokenizer.tokenize(template, openDelimiter, closeDelimiter),
					template
				);
			}
		);
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

	// --- Text Formatting ---

	private string function _dedentTemplate(
		required string templateText,
		required string indentation
	) {
		if (!len(arguments.templateText) || !len(arguments.indentation)) {
			return arguments.templateText;
		}

		var chunks = [];
		var pos = 1;
		var totalLen = len(arguments.templateText);

		while (pos <= totalLen) {
			var nextLineBreakPos = StringUtil::findNextLineBreakPos(arguments.templateText, pos);
			var lineText = nextLineBreakPos == 0
				? mid(arguments.templateText, pos, totalLen - pos + 1)
				: mid(arguments.templateText, pos, nextLineBreakPos - pos);
			var lineBreak = "";

			if (nextLineBreakPos > 0) {
				lineBreak = mid(
					arguments.templateText,
					nextLineBreakPos,
					StringUtil::getLineBreakLength(arguments.templateText, nextLineBreakPos)
				);
			}

			if (len(trim(lineText)) && left(lineText, len(arguments.indentation)) == arguments.indentation) {
				lineText = mid(lineText, len(arguments.indentation) + 1, len(lineText) - len(arguments.indentation));
			}

			arrayAppend(chunks, lineText & lineBreak);
			pos = nextLineBreakPos == 0 ? totalLen + 1 : nextLineBreakPos + len(lineBreak);
		}

		return arrayToList(chunks, "");
	}

	private string function _indentPartialTemplate(required string template, required string indentation) {
		if (!len(arguments.template) || !len(arguments.indentation)) {
			return arguments.template;
		}

		var chunks = [arguments.indentation];
		var pos = 1;
		var totalLen = len(arguments.template);

		while (pos <= totalLen) {
			var nextLineBreakPos = StringUtil::findNextLineBreakPos(arguments.template, pos);

			if (nextLineBreakPos == 0) {
				arrayAppend(chunks, mid(arguments.template, pos, totalLen - pos + 1));
				break;
			}

			var lineBreakLen = StringUtil::getLineBreakLength(arguments.template, nextLineBreakPos);
			arrayAppend(chunks, mid(arguments.template, pos, nextLineBreakPos - pos + lineBreakLen));
			pos = nextLineBreakPos + lineBreakLen;

			if (pos <= totalLen) {
				arrayAppend(chunks, arguments.indentation);
			}
		}

		return arrayToList(chunks, "");
	}

	// --- Utility ---

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
