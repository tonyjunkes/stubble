component displayname="Stubble" singleton {
	variables._tokenizer = new Tokenizer();
	variables._parser = new Parser();
	variables._cache = new TemplateCache();
	variables._contextResolver = new ContextResolver();

	public Stubble function init(
		Tokenizer tokenizer,
		Parser parser,
		ITemplateCache cache
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

	public string function render(required string template, any view = {}, struct partials = {}) {
		var ast = _getParsedTemplate(arguments.template);
		var state = _newRenderState([arguments.view], arguments.partials, {});
		return _renderNodes(ast, state);
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

	private struct function _newRenderState(
		required array contextStack,
		required struct partials,
		required struct blockOverrides
	) {
		return {
			contextStack: arguments.contextStack,
			partials: arguments.partials,
			blockOverrides: arguments.blockOverrides
		};
	}

	private string function _renderNodes(required array nodes, required struct state) {
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
					var lookup = variables._contextResolver.lookup(node.name, arguments.state.contextStack, node.nameParts);
					if (!lookup.found) {
						break;
					}

					var value = lookup.value;
					if (isCustomFunction(value)) {
						value = _invokeVariableLambda(value, arguments.state);
					}

					var renderedValue = _toString(value);
					if (node.type == "variable") {
						arrayAppend(outputChunks, _escapeHtml(renderedValue));
					} else {
						arrayAppend(outputChunks, renderedValue);
					}
					break;

				case "partial":
					var resolvedPartial = _resolveTemplate(node.name, arguments.state);
					if (resolvedPartial.found) {
						var partialTemplate = resolvedPartial.template;
						if (len(node.indent)) {
							partialTemplate = _indentPartialTemplate(partialTemplate, node.indent);
						}

						arrayAppend(outputChunks, _renderTemplate(
							partialTemplate,
							arguments.state,
							arguments.state.blockOverrides,
							"{{",
							"}}"
						));
					}
					break;

				case "parent":
					arrayAppend(outputChunks, _renderParent(node, arguments.state));
					break;

				case "block":
					arrayAppend(outputChunks, _renderBlock(node, arguments.state));
					break;

				case "section":
				case "inverted":
					arrayAppend(outputChunks, _renderSection(node, arguments.state));
					break;

				default:
					throw(type = "Stubble.RendererException", message = "Unsupported node type: #node.type#");
			}
		}

		return arrayToList(outputChunks, "");
	}

	private struct function _resolvePartialName(required string partialName, required struct state) {
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

		var lookup = variables._contextResolver.lookup(dynamicName, arguments.state.contextStack);
		if (!lookup.found || isNull(lookup.value)) {
			return { found: false, name: "" };
		}

		return {
			found: true,
			name: _toString(lookup.value)
		};
	}

	private struct function _resolveTemplate(required string templateName, required struct state) {
		var resolvedName = _resolvePartialName(arguments.templateName, arguments.state);
		if (!resolvedName.found || !structKeyExists(arguments.state.partials, resolvedName.name)) {
			return { found: false, name: "", template: "" };
		}

		var templateValue = arguments.state.partials[resolvedName.name];
		if (isCustomFunction(templateValue)) {
			templateValue = templateValue();
		}

		return {
			found: true,
			name: resolvedName.name,
			template: _toString(templateValue)
		};
	}

	private string function _renderSection(required struct node, required struct state) {
		var lookup = variables._contextResolver.lookup(
			arguments.node.name,
			arguments.state.contextStack,
			arguments.node.nameParts
		);
		var found = lookup.found;
		var value = found ? lookup.value : "";
		var truthy = found && _isTruthy(value);

		if (arguments.node.type == "inverted") {
			return truthy ? "" : _renderNodes(arguments.node.children, arguments.state);
		}

		if (!found) {
			return "";
		}

		if (isCustomFunction(value)) {
			return _invokeSectionLambda(
				value,
				arguments.node.rawText,
				arguments.state,
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
				arrayAppend(arrayOutputChunks, _withContext(arguments.state, value[i], arguments.node));
			}
			return arrayToList(arrayOutputChunks, "");
		}

		if (isStruct(value) || isObject(value)) {
			return _withContext(arguments.state, value, arguments.node);
		}

		if (!truthy) {
			return "";
		}

		return _withContext(arguments.state, value, arguments.node);
	}

	private string function _withContext(required struct state, required any contextValue, required struct node) {
		arrayAppend(arguments.state.contextStack, arguments.contextValue);
		try {
			return _renderNodes(arguments.node.children, arguments.state);
		} finally {
			arrayDeleteAt(arguments.state.contextStack, arrayLen(arguments.state.contextStack));
		}
	}

	private string function _renderParent(required struct node, required struct state) {
		var resolvedParent = _resolveTemplate(arguments.node.name, arguments.state);
		if (!resolvedParent.found) {
			return "";
		}

		var effectiveOverrides = _collectBlockOverrides(arguments.node.children);
		if (structCount(arguments.state.blockOverrides)) {
			structAppend(effectiveOverrides, arguments.state.blockOverrides, true);
		}

		var parentTemplate = resolvedParent.template;
		if (len(arguments.node.expansionIndent)) {
			parentTemplate = _indentPartialTemplate(parentTemplate, arguments.node.expansionIndent);
		}

		return _renderTemplate(
			parentTemplate,
			arguments.state,
			effectiveOverrides,
			"{{",
			"}}"
		);
	}

	private string function _renderBlock(required struct node, required struct state) {
		var sourceNode = structKeyExists(arguments.state.blockOverrides, arguments.node.name)
			? arguments.state.blockOverrides[arguments.node.name]
			: arguments.node;

		if (
			!sourceNode.stripLeadingLineBreak &&
			!len(sourceNode.definitionIndent) &&
			!len(arguments.node.expansionIndent)
		) {
			var renderedChildren = _renderNodes(sourceNode.children, arguments.state);
			if (
				len(arguments.node.trailingLineBreak) &&
				len(renderedChildren) &&
				!StringUtil::endsWithLineBreak(renderedChildren)
			) {
				renderedChildren &= arguments.node.trailingLineBreak;
			}

			return renderedChildren;
		}

		var blockTemplate = StringUtil::normalizeBlockSourceText(sourceNode.rawText, sourceNode.stripLeadingLineBreak);
		if (len(sourceNode.definitionIndent)) {
			blockTemplate = _dedentTemplate(blockTemplate, sourceNode.definitionIndent);
		}

		if (len(arguments.node.expansionIndent)) {
			blockTemplate = _indentPartialTemplate(blockTemplate, arguments.node.expansionIndent);
		}

		var renderedBlock = _renderTemplate(
			blockTemplate,
			arguments.state,
			arguments.state.blockOverrides,
			"{{",
			"}}"
		);
		if (len(arguments.node.trailingLineBreak) && len(renderedBlock) && !StringUtil::endsWithLineBreak(renderedBlock)) {
			renderedBlock &= arguments.node.trailingLineBreak;
		}

		return renderedBlock;
	}

	// --- Lambda Handling ---

	private numeric function _getFunctionArity(required function lambdaFn) {
		var lambdaMetadata = getMetadata(arguments.lambdaFn);
		if (isStruct(lambdaMetadata) && structKeyExists(lambdaMetadata, "parameters") && isArray(lambdaMetadata.parameters)) {
			return arrayLen(lambdaMetadata.parameters);
		}

		return 0;
	}

	private string function _invokeVariableLambda(required function lambdaFn, required struct state) {
		var arity = _getFunctionArity(arguments.lambdaFn);
		var result = arity <= 0
			? arguments.lambdaFn()
			: arguments.lambdaFn(arguments.state.contextStack[arrayLen(arguments.state.contextStack)]);

		return _renderLambdaResult(result, arguments.state, "{{", "}}");
	}

	private string function _invokeSectionLambda(
		required function lambdaFn,
		required string rawText,
		required struct state,
		required string openDelimiter,
		required string closeDelimiter
	) {
		var sectionState = arguments.state;
		var sectionOpenDelimiter = arguments.openDelimiter;
		var sectionCloseDelimiter = arguments.closeDelimiter;

		var renderFn = function(required string templateText) {
			return _renderTemplate(
				templateText,
				sectionState,
				sectionState.blockOverrides,
				sectionOpenDelimiter,
				sectionCloseDelimiter
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

		return _renderLambdaResult(
			result,
			arguments.state,
			arguments.openDelimiter,
			arguments.closeDelimiter
		);
	}

	private string function _renderLambdaResult(
		any result,
		required struct state,
		required string openDelimiter,
		required string closeDelimiter
	) {
		var rendered = _toString(arguments.result);
		if (find(arguments.openDelimiter, rendered) == 0) {
			return rendered;
		}

		return _renderTemplate(
			rendered,
			arguments.state,
			arguments.state.blockOverrides,
			arguments.openDelimiter,
			arguments.closeDelimiter
		);
	}

	// --- Template Processing ---

	private string function _renderTemplate(
		required string template,
		required struct state,
		required struct blockOverrides,
		string openDelimiter = "{{",
		string closeDelimiter = "}}"
	) {
		var nestedAst = _getParsedTemplate(arguments.template, arguments.openDelimiter, arguments.closeDelimiter);
		var nestedState = _newRenderState(
			arguments.state.contextStack,
			arguments.state.partials,
			arguments.blockOverrides
		);
		return _renderNodes(nestedAst, nestedState);
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
