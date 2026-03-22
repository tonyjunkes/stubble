component displayname="Tokenizer" {
	public array function tokenize(
		required string template,
		string openDelimiter = "{{",
		string closeDelimiter = "}}"
	) {
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
					arrayAppend(tokens, _textToken(arguments.template, pos, totalLen));
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
					arrayAppend(tokens, _textToken(arguments.template, pos, openPos - 1));
				}

				var tripleClosePos = find("}}}", arguments.template, openPos + 3);
				if (tripleClosePos == 0) {
					throw(type = "Stubble.TokenizerUnclosedTagException", message = "Unclosed triple mustache tag.");
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
				throw(type = "Stubble.TokenizerUnclosedTagException", message = "Unclosed tag.");
			}

			var content = trim(
				mid(arguments.template, openPos + openDelimiterLength, closePos - (openPos + openDelimiterLength))
			);
			var token = {
				type: "variable",
				name: content,
				openDelimiter: currentOpenDelimiter,
				closeDelimiter: currentCloseDelimiter,
				startPos: openPos,
				endPos: closePos + closeDelimiterLength - 1
			};

			if (len(content) > 0) {
				_classifyTag(token, content);
			}

			if (_isStandaloneTokenType(token.type)) {
				var standaloneContext = _getStandaloneTagContext(arguments.template, pos, openPos, token.endPos);
				if (standaloneContext.isStandalone) {
					if (standaloneContext.leadingTextLength > 0) {
						arrayAppend(tokens, _textToken(
							arguments.template,
							pos,
							pos + standaloneContext.leadingTextLength - 1
						));
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
				arrayAppend(tokens, _textToken(arguments.template, pos, openPos - 1));
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

	private struct function _textToken(required string template, required numeric startPos, required numeric endPos) {
		return {
			type: "text",
			value: mid(arguments.template, arguments.startPos, arguments.endPos - arguments.startPos + 1),
			startPos: arguments.startPos,
			endPos: arguments.endPos
		};
	}

	private void function _classifyTag(required struct token, required string content) {
		if (_isSetDelimiterTag(arguments.content)) {
			var delimiterPair = _parseDelimiterPair(arguments.content);
			arguments.token.type = "set_delimiter";
			arguments.token.openDelimiter = delimiterPair.openDelimiter;
			arguments.token.closeDelimiter = delimiterPair.closeDelimiter;
			return;
		}

		var sigil = left(arguments.content, 1);
		var body = trim(mid(arguments.content, 2, len(arguments.content) - 1));

		switch (sigil) {
			case "!":
				arguments.token.type = "comment";
				arguments.token.name = body;
				break;
			case ">":
				arguments.token.type = "partial";
				arguments.token.name = body;
				break;
			case "<":
				arguments.token.type = "parent_start";
				arguments.token.name = body;
				break;
			case "/":
				arguments.token.type = "section_end";
				arguments.token.name = body;
				if (left(arguments.token.name, 1) == chr(35)) {
					arguments.token.name = trim(mid(arguments.token.name, 2, len(arguments.token.name) - 1));
				}
				break;
			case "##":
				arguments.token.type = "section_start";
				arguments.token.name = body;
				break;
			case "$":
				arguments.token.type = "block_start";
				arguments.token.name = body;
				break;
			case "^":
				arguments.token.type = "inverted_start";
				arguments.token.name = body;
				break;
			case "&":
				arguments.token.type = "unescaped";
				arguments.token.name = body;
				break;
			default:
				arguments.token.type = "variable";
				arguments.token.name = arguments.content;
		}
	}

	private boolean function _isStandaloneTokenType(required string tokenType) {
		return arrayFind(
			["comment", "partial", "section_start", "section_end", "inverted_start", "set_delimiter"],
			arguments.tokenType
		);
	}

	private boolean function _isSetDelimiterTag(required string content) {
		return len(arguments.content) >= 2 && left(arguments.content, 1) == "=" && right(arguments.content, 1) == "=";
	}

	private struct function _parseDelimiterPair(required string content) {
		var delimiterDefinition = trim(mid(arguments.content, 2, len(arguments.content) - 2));
		var normalizedDefinition = trim(reReplace(delimiterDefinition, "\s+", " ", "all"));
		var delimiterParts = len(normalizedDefinition) ? listToArray(normalizedDefinition, " ") : [];

		if (arrayLen(delimiterParts) != 2) {
			throw(type = "Stubble.TokenizerDelimiterException", message = "Invalid set delimiter tag.");
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
		var lineStartPos = StringUtil::getLineStartPos(arguments.template, arguments.openPos);
		var leadingWhitespace = mid(arguments.template, lineStartPos, arguments.openPos - lineStartPos);

		if (!StringUtil::containsOnlyStandaloneWhitespace(leadingWhitespace)) {
			return { isStandalone: false };
		}

		var afterTokenPos = arguments.tokenEndPos + 1;
		var nextLineBreakPos = StringUtil::findNextLineBreakPos(arguments.template, afterTokenPos);

		if (nextLineBreakPos == 0) {
			var trailingToEnd = afterTokenPos <= len(arguments.template)
				? mid(arguments.template, afterTokenPos, len(arguments.template) - afterTokenPos + 1)
				: "";

			if (!StringUtil::containsOnlyStandaloneWhitespace(trailingToEnd)) {
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

		if (!StringUtil::containsOnlyStandaloneWhitespace(trailingWhitespace)) {
			return { isStandalone: false };
		}

		return {
			isStandalone: true,
			leadingTextLength: max(0, lineStartPos - arguments.currentPos),
			indentation: leadingWhitespace,
			nextPos: nextLineBreakPos + StringUtil::getLineBreakLength(arguments.template, nextLineBreakPos)
		};
	}
}
