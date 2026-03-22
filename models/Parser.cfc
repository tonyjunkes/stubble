component displayname="Parser" {
	variables.CONTAINER_NODE_TYPES = {
		section_start: "section",
		inverted_start: "inverted",
		block_start: "block",
		parent_start: "parent"
	};

	public array function parse(required array tokens, required string template) {
		var root = { type: "root", children: [] };
		var stack = [root];
		var localTokens = arguments.tokens;

		for (var i = 1; i <= arrayLen(localTokens); i++) {
			var token = localTokens[i];
			var current = stack[arrayLen(stack)];

			switch (token.type) {
				case "text":
					arrayAppend(current.children, { type: "text", value: token.value });
					break;

				case "variable":
				case "unescaped":
					arrayAppend(current.children, {
						type: token.type,
						name: token.name,
						nameParts: buildNameParts(token.name)
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
						node.nameParts = buildNameParts(token.name);
						node.renderOpenDelimiter = token.openDelimiter;
						node.renderCloseDelimiter = token.closeDelimiter;
					}

					arrayAppend(current.children, node);
					arrayAppend(stack, node);
					break;

				case "section_end":
					if (arrayLen(stack) == 1) {
						throw(
							type = "Stubble.ParserSectionException",
							message = "Closing tag without opening tag: #token.name#"
						);
					}

					var openIndex = arrayLen(stack);
					var openName = stack[openIndex].name;
					if (openName != token.name) {
						throw(
							type = "Stubble.ParserSectionException",
							message = "Section mismatch. Opened '#openName#' but closed '#token.name#'."
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
					throw(type = "Stubble.ParserTokenException", message = "Unsupported token type: #token.type#");
			}
		}

		if (arrayLen(stack) != 1) {
			var unclosed = stack[arrayLen(stack)];
			throw(type = "Stubble.ParserSectionException", message = "Unclosed section: #unclosed.name#");
		}

		_finalizeParsedNodes(root.children, arguments.template);

		return root.children;
	}

	public array function buildNameParts(required string name) {
		if (arguments.name == ".") {
			return ["."];
		}

		if (find(".", arguments.name) == 0) {
			return [arguments.name];
		}

		return listToArray(arguments.name, ".");
	}

	private string function _getContainerNodeType(required string tokenType) {
		if (structKeyExists(variables.CONTAINER_NODE_TYPES, arguments.tokenType)) {
			return variables.CONTAINER_NODE_TYPES[arguments.tokenType];
		}

		throw(type = "Stubble.ParserTokenException", message = "Unsupported container token type: #arguments.tokenType#");
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
			var normalizedBlockSource = StringUtil::normalizeBlockSourceText(node.rawText, nodeContext.stripLeadingLineBreak);
			node.definitionIndent = node.type == "block" && StringUtil::containsLineBreak(normalizedBlockSource)
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
		var lineStartPos = StringUtil::getLineStartPos(arguments.template, arguments.node.startPos);
		var leadingWhitespace = mid(arguments.template, lineStartPos, arguments.node.startPos - lineStartPos);
		var hasStandaloneLeading = StringUtil::containsOnlyStandaloneWhitespace(leadingWhitespace);
		var hasInlineContent = !StringUtil::containsLineBreak(arguments.node.rawText) && len(trim(arguments.node.rawText));

		var afterNodePos = arguments.node.endPos + 1;
		var nextLineBreakPos = StringUtil::findNextLineBreakPos(arguments.template, afterNodePos);
		var trailingWhitespace = "";
		var trailingLength = 0;
		var trailingLineBreak = "";
		var hasStandaloneTrailing = false;

		if (nextLineBreakPos == 0) {
			trailingWhitespace = afterNodePos <= len(arguments.template)
				? mid(arguments.template, afterNodePos, len(arguments.template) - afterNodePos + 1)
				: "";
			hasStandaloneTrailing = StringUtil::containsOnlyStandaloneWhitespace(trailingWhitespace);
			trailingLength = len(trailingWhitespace);
		} else {
			trailingWhitespace = nextLineBreakPos > afterNodePos
				? mid(arguments.template, afterNodePos, nextLineBreakPos - afterNodePos)
				: "";
			hasStandaloneTrailing = StringUtil::containsOnlyStandaloneWhitespace(trailingWhitespace);
			trailingLength = len(trailingWhitespace) + StringUtil::getLineBreakLength(arguments.template, nextLineBreakPos);
			trailingLineBreak = mid(
				arguments.template,
				nextLineBreakPos,
				StringUtil::getLineBreakLength(arguments.template, nextLineBreakPos)
			);
		}

		var afterOpenPos = arguments.node.openEndPos + 1;
		var nextOpenLineBreakPos = StringUtil::findNextLineBreakPos(arguments.template, afterOpenPos);
		var openRemainder = "";
		if (nextOpenLineBreakPos > 0) {
			openRemainder = nextOpenLineBreakPos > afterOpenPos
				? mid(arguments.template, afterOpenPos, nextOpenLineBreakPos - afterOpenPos)
				: "";
		} else if (afterOpenPos <= len(arguments.template)) {
			openRemainder = mid(arguments.template, afterOpenPos, len(arguments.template) - afterOpenPos + 1);
		}

		var stripLeadingLineBreak = nextOpenLineBreakPos > 0 && StringUtil::containsOnlyStandaloneWhitespace(openRemainder);
		var isStandaloneNode = hasStandaloneLeading && hasStandaloneTrailing && !hasInlineContent;
		var expansionIndent = isStandaloneNode ? leadingWhitespace : "";
		if (arguments.node.type == "block" && !len(expansionIndent) && stripLeadingLineBreak) {
			expansionIndent = _getCommonLeadingIndentation(StringUtil::normalizeBlockSourceText(arguments.node.rawText, true));
		}

		return {
			trimLeadingLength: isStandaloneNode ? len(leadingWhitespace) : 0,
			trimTrailingLength: isStandaloneNode ? trailingLength : 0,
			expansionIndent: expansionIndent,
			stripLeadingLineBreak: stripLeadingLineBreak,
			trailingLineBreak: isStandaloneNode ? trailingLineBreak : ""
		};
	}

	private string function _getCommonLeadingIndentation(required string templateText) {
		var normalizedText = reReplace(arguments.templateText, chr(13) & chr(10) & "?", chr(10), "all");
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

		for (var i = 1; i <= maxLength; i++) {
			if (mid(arguments.firstIndent, i, 1) != mid(arguments.secondIndent, i, 1)) {
				return i > 1 ? left(arguments.firstIndent, i - 1) : "";
			}
		}

		return maxLength > 0 ? left(arguments.firstIndent, maxLength) : "";
	}
}
