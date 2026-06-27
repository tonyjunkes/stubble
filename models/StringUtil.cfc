component displayname="StringUtil" {
	public static numeric function getLineStartPos(required string template, required numeric position) {
		var searchFromIndex = arguments.position - 2;
		var lastLineFeed = arguments.template.lastIndexOf(chr(10), searchFromIndex) + 1;
		var lastCarriageReturn = arguments.template.lastIndexOf(chr(13), searchFromIndex) + 1;

		return max(lastLineFeed, lastCarriageReturn) + 1;
	}

	public static numeric function findLastPosition(required string needle, required string haystack) {
		var pos = arguments.haystack.lastIndexOf(arguments.needle);
		return pos == -1 ? 0 : pos + 1;
	}

	public static numeric function findNextLineBreakPos(required string template, required numeric startPos) {
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

	public static numeric function getLineBreakLength(required string template, required numeric lineBreakPos) {
		if (
			mid(arguments.template, arguments.lineBreakPos, 1) == chr(13)
			&& arguments.lineBreakPos < len(arguments.template)
			&& mid(arguments.template, arguments.lineBreakPos + 1, 1) == chr(10)
		) {
			return 2;
		}

		return 1;
	}

	public static boolean function containsOnlyStandaloneWhitespace(required string value) {
		return reFind("[^ \t]", arguments.value) == 0;
	}

	public static boolean function containsLineBreak(required string value) {
		return find(chr(10), arguments.value) > 0 || find(chr(13), arguments.value) > 0;
	}

	public static string function normalizeBlockSourceText(
		required string templateText,
		boolean stripLeadingLineBreak = false
	) {
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

	public static boolean function endsWithLineBreak(required string value) {
		if (!len(arguments.value)) {
			return false;
		}

		return right(arguments.value, 1) == chr(10)
			|| right(arguments.value, 1) == chr(13)
			|| right(arguments.value, 2) == chr(13) & chr(10);
	}
}
