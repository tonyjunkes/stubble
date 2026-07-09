component displayname="ContextResolver" {
	public struct function lookup(
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
			parts = _buildNameParts(arguments.name);
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

		if (
			isSimpleValue(arguments.current) ||
			isArray(arguments.current) ||
			(isStruct(arguments.current) && !isObject(arguments.current))
		) {
			return defaultResult;
		}

		if (!isObject(arguments.current)) {
			return defaultResult;
		}

		if (structKeyExists(arguments.current, arguments.key)) {
			return { found: true, value: arguments.current[arguments.key] };
		}

		return _resolveObjectAccessor(arguments.current, arguments.key);
	}

	private struct function _resolveObjectAccessor(required any current, required string key) {
		var defaultResult = { found: false, value: "" };
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
							return {
								found: true,
								value: _invokeObjectMethod(arguments.current, fn.name)
							};
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
					return {
						found: true,
						value: method.invoke(arguments.current, [])
					};
				}
			}

			var field = arguments.current.getClass().getField(arguments.key);
			return {
				found: true,
				value: field.get(arguments.current)
			};
		} catch (any e) {
			return defaultResult;
		}
	}

	private any function _invokeObjectMethod(required any current, required string methodName) {
		return invoke(arguments.current, arguments.methodName, {});
	}

	private array function _buildAccessorMethodNames(required string key) {
		var normalizedKey = trim(arguments.key);
		if (!len(normalizedKey)) {
			return ["", ""];
		}

		var accessorSuffix = uCase(left(normalizedKey, 1)) & mid(normalizedKey, 2, len(normalizedKey) - 1);
		return ["get" & accessorSuffix, "is" & accessorSuffix];
	}
}
