class_name ExpressionInterpreter
extends RefCounted

var core_interpreter

func _init(core):
	core_interpreter = core

func execute_expression(statement):
	# Handle list and dict literals first
	if statement.tokens.size() > 0:
		# Handle list literals
		if statement.tokens[0].type == CoreParser.TokenType.PARENTHESIS_OPEN and statement.tokens[0].value == "[":
			return await evaluate_list_literal(statement.tokens)
		
		# Handle dict literals
		elif statement.tokens[0].type == CoreParser.TokenType.PARENTHESIS_OPEN and statement.tokens[0].value == "{":
			return await evaluate_dict_literal(statement.tokens)
	
	# Handle function calls
	if statement.tokens.size() > 1 and statement.tokens[0].type == CoreParser.TokenType.IDENTIFIER:
		var func_name = statement.tokens[0].value
		if statement.tokens[1].type == CoreParser.TokenType.PARENTHESIS_OPEN:
			if core_interpreter.environment.has_function(func_name):
				var result = await core_interpreter.function_interpreter.execute_function_call(statement)
				return result
			elif not core_interpreter.keywords.has(func_name) and not core_interpreter.stdlib.has_method("std_" + func_name):
				core_interpreter.emit_error("Unknown function '" + func_name + "' at line " + str(statement.line))
				core_interpreter.stop_execution()
				return null
	
	# Continue with regular expression evaluation
	return await evaluate_expression(statement.tokens)

func evaluate_expression(tokens: Array):
	if tokens.size() == 0:
		return null
	
	if tokens[0].type == CoreParser.TokenType.PARENTHESIS_OPEN:
		if tokens[0].value == "[":
			return await evaluate_list_literal(tokens)
		elif tokens[0].value == "{":
			return await evaluate_dict_literal(tokens)
		
	# First check for standalone function calls
	if (tokens.size() > 1 and 
		tokens[0].type == CoreParser.TokenType.IDENTIFIER and 
		tokens[1].type == CoreParser.TokenType.PARENTHESIS_OPEN):
		
		var func_name = tokens[0].value
		if core_interpreter.environment.has_function(func_name) or core_interpreter.stdlib.has_method("std_" + func_name):
			var func_statement = CoreParser.Statement.new(CoreParser.StatementType.EXPRESSION, tokens, tokens[0].line)
			return await core_interpreter.function_interpreter.execute_function_call(func_statement)
	
	# Handle simple values
	if tokens.size() == 1:
		var token = tokens[0]
		match token.type:
			CoreParser.TokenType.NUMBER:
				if "." in token.value or "e" in token.value.to_lower():
					return float(token.value)
				else:
					return int(token.value)
			CoreParser.TokenType.STRING:
				var str_value = token.value
				if (str_value.begins_with("\"") and str_value.ends_with("\"")) or (str_value.begins_with("'") and str_value.ends_with("'")):
					return str_value.substr(1, str_value.length() - 2)
				return str_value
			CoreParser.TokenType.IDENTIFIER:
				if token.value.to_lower() == "true":
					return true
				elif token.value.to_lower() == "false":
					return false
				elif core_interpreter.environment.has_variable(token.value):
					return core_interpreter.environment.get_variable(token.value)
				else:
					core_interpreter.emit_error("Undefined variable: " + token.value)
					return null
	
	# Convert to postfix and evaluate
	var postfix = infix_to_postfix(tokens)
	if postfix.size() == 0:
		return null
	return await evaluate_postfix(postfix)

func find_matching_paren(tokens: Array, open_index: int) -> int:
	var count = 1
	for i in range(open_index + 1, tokens.size()):
		if tokens[i].type == CoreParser.TokenType.PARENTHESIS_OPEN:
			count += 1
		elif tokens[i].type == CoreParser.TokenType.PARENTHESIS_CLOSE:
			count -= 1
			if count == 0:
				return i
	return -1

# This function handles conditions with special handling for 'not' operator
func evaluate_condition(tokens: Array):
	# Debug tokens and detect "not operator comparison" pattern
	if tokens.size() >= 2 and tokens[0].type == CoreParser.TokenType.OPERATOR and tokens[0].value == "not":
		# Handle 'not' followed by an identifier and comparison
		# This specifically handles "not counter >= 5" pattern
		
		# Extract the remaining tokens (everything after "not")
		var remaining_tokens = tokens.slice(1)
		
		# If we have a simple identifier followed by comparison, we need special handling
		if remaining_tokens.size() >= 3 and remaining_tokens[0].type == CoreParser.TokenType.IDENTIFIER:
			var has_comparison = false
			var comparison_index = -1
			
			# Look for any comparison operator in the remaining tokens
			for i in range(1, remaining_tokens.size()):
				if remaining_tokens[i].type == CoreParser.TokenType.OPERATOR and remaining_tokens[i].value in ["==", "!=", "<", ">", "<=", ">="]:
					has_comparison = true
					comparison_index = i
					break
			
			if has_comparison:
				# We have a pattern like "not counter >= 5"
				# First evaluate the comparison without the "not"
				var comparison_result = await evaluate_expression(remaining_tokens)
				# Then negate it
				return !to_boolean(comparison_result)
		
		# Handle the general case of "not" with complex expressions
		var has_comparison = false
		var comparison_index = -1
		for i in range(remaining_tokens.size()):
			if remaining_tokens[i].type == CoreParser.TokenType.OPERATOR and remaining_tokens[i].value in ["==", "!=", "<", ">", "<=", ">="]:
				has_comparison = true
				comparison_index = i
				break
		
		if has_comparison and comparison_index > 0:
			# Split the expression around the comparison operator
			var left_expr = remaining_tokens.slice(0, comparison_index)
			var operator = remaining_tokens[comparison_index]
			var right_expr = remaining_tokens.slice(comparison_index + 1)
			
			# Evaluate both sides of the comparison
			var left_value = await evaluate_expression(left_expr)
			var right_value = await evaluate_expression(right_expr)
			
			# Convert to comparable types if needed
			left_value = convert_to_number(left_value) if left_value is int or left_value is float else left_value
			right_value = convert_to_number(right_value) if right_value is int or right_value is float else right_value
			
			# Apply the comparison operation
			var comparison_result
			match operator.value:
				"==":
					comparison_result = _safe_equality_compare(left_value, right_value)
				"!=":
					comparison_result = !_safe_equality_compare(left_value, right_value)
				"<":
					if _can_compare(left_value, right_value):
						comparison_result = left_value < right_value
					else:
						left_value = convert_to_number(left_value)
						right_value = convert_to_number(right_value)
						comparison_result = left_value < right_value
				">":
					if _can_compare(left_value, right_value):
						comparison_result = left_value > right_value
					else:
						left_value = convert_to_number(left_value)
						right_value = convert_to_number(right_value)
						comparison_result = left_value > right_value
				"<=":
					if _can_compare(left_value, right_value):
						comparison_result = left_value <= right_value
					else:
						left_value = convert_to_number(left_value)
						right_value = convert_to_number(right_value)
						comparison_result = left_value <= right_value
				">=":
					if _can_compare(left_value, right_value):
						comparison_result = left_value >= right_value
					else:
						left_value = convert_to_number(left_value)
						right_value = convert_to_number(right_value)
						comparison_result = left_value >= right_value
			
			# Apply the "not" operator to the result
			return !comparison_result
		
		# If no comparison operator or simpler expression, evaluate the inner condition first
		var inner_result = await evaluate_expression(remaining_tokens)
		# Apply the "not" operator to the result
		return !to_boolean(inner_result)
	
	# Regular variable check for undefined variables
	for token in tokens:
		if token.type == CoreParser.TokenType.IDENTIFIER:
			var var_name = token.value
			if var_name.to_lower() in ["true", "false"]:
				continue
			if not core_interpreter.environment.has_variable(var_name) and token.value != "not":
				core_interpreter.emit_error("Undefined variable '" + var_name + "' in condition")
				core_interpreter.stop_execution()
				return false
	
	if tokens.size() == 1 and tokens[0].type == CoreParser.TokenType.IDENTIFIER:
		match tokens[0].value.to_lower():
			"true":
				return true
			"false":
				return false
			_:
				var value = core_interpreter.environment.get_variable(tokens[0].value)
				return to_boolean(value)
	
	return to_boolean(await evaluate_expression(tokens))

func infix_to_postfix(tokens: Array) -> Array:
	var output_queue = []
	var operator_stack = []
	var precedence = {
		# Logical operators (lowest precedence)
		"||": 1, "or": 1,                # Logical OR
		"&&": 2, "and": 2,               # Logical AND
		
		# Comparison operators
		"==": 3, "!=": 3,                # Equality
		"<": 4, ">": 4, "<=": 4, ">=": 4, # Comparison
		
		# Arithmetic operators
		"+": 5, "-": 5,                  # Addition and subtraction
		"*": 6, "/": 6, "%": 6,          # Multiplication, division, modulo
		"^": 7,                          # Exponentiation
		
		# Unary operators (highest precedence)
		"u-": 8, "u+": 8, "!": 8, "not": 8, "u!": 8, "unot": 8
	}
	var expecting_operand = true
	
	var i = 0
	while i < tokens.size():
		var token = tokens[i]
		match token.type:
			CoreParser.TokenType.NUMBER, CoreParser.TokenType.STRING:
				output_queue.append(token)
				expecting_operand = false
				
			CoreParser.TokenType.IDENTIFIER:
				# Detect function calls (identifier followed by '(')
				if i + 1 < tokens.size() and tokens[i + 1].type == CoreParser.TokenType.PARENTHESIS_OPEN:
					var func_name = token.value
					var func_tokens = []
					var paren_level = 0
					var start_i = i
					
					# Collect all tokens until matching closing parenthesis
					while i < tokens.size():
						func_tokens.append(tokens[i])
						if tokens[i].type == CoreParser.TokenType.PARENTHESIS_OPEN:
							paren_level += 1
						elif tokens[i].type == CoreParser.TokenType.PARENTHESIS_CLOSE:
							paren_level -= 1
							if paren_level == 0:
								i += 1  # Move past closing parenthesis
								break
						i += 1
					
					# Create special function call token
					var func_call_token = CoreParser.Token.new(
						CoreParser.TokenType.IDENTIFIER,
						func_name,
						token.line
					)
					func_call_token.is_function_call = true
					func_call_token.func_tokens = func_tokens
					output_queue.append(func_call_token)
					expecting_operand = false
					continue  # Skip outer loop increment
				else:
					output_queue.append(token)
					expecting_operand = false
					
			CoreParser.TokenType.OPERATOR:
				# Handle unary operators
				if expecting_operand:
					if token.value in ["+", "-"]:
						var unary_op = CoreParser.Token.new(CoreParser.TokenType.OPERATOR, "u" + token.value, token.line)
						operator_stack.append(unary_op)
						i += 1
						continue
					elif token.value in ["!", "not"]:
						var unary_op = CoreParser.Token.new(CoreParser.TokenType.OPERATOR, "u" + token.value, token.line)
						operator_stack.append(unary_op)
						i += 1
						continue
				
				# Handle binary operators
				while operator_stack.size() > 0:
					var top = operator_stack.back()
					if top.type == CoreParser.TokenType.PARENTHESIS_OPEN:
						break
					if precedence.get(top.value, 0) >= precedence.get(token.value, 0):
						output_queue.append(operator_stack.pop_back())
					else:
						break
				operator_stack.append(token)
				expecting_operand = true
				
			CoreParser.TokenType.PARENTHESIS_OPEN:
				operator_stack.append(token)
				expecting_operand = true
				
			CoreParser.TokenType.PARENTHESIS_CLOSE:
				var found = false
				while operator_stack.size() > 0:
					var top = operator_stack.back()
					if top.type == CoreParser.TokenType.PARENTHESIS_OPEN:
						found = true
						operator_stack.pop_back()
						break
					output_queue.append(operator_stack.pop_back())
				if not found:
					core_interpreter.emit_error("Mismatched parentheses")
					return []
				expecting_operand = false
				
		i += 1
	
	# Add remaining operators
	while operator_stack.size() > 0:
		var op = operator_stack.pop_back()
		if op.type == CoreParser.TokenType.PARENTHESIS_OPEN:
			core_interpreter.emit_error("Mismatched parentheses")
			return []
		output_queue.append(op)
	
	return output_queue

# Improved evaluate_postfix function
# In ExpressionInterpreter.gd, modify the evaluate_postfix function:
func evaluate_postfix(tokens: Array):
	print("DEBUG [PostfixEval]: Starting evaluation of tokens: ", tokens)
	var stack = []
	
	var i = 0
	while i < tokens.size():
		var token = tokens[i]
		print("DEBUG [PostfixEval]: Processing token ", token.value, " (type: ", token.type, ")")
		print("DEBUG [PostfixEval]: Current stack: ", stack)
		
		match token.type:
			CoreParser.TokenType.NUMBER:
				var num_value
				if "." in token.value or "e" in token.value.to_lower():
					num_value = float(token.value)
				else:
					num_value = int(token.value)
				stack.append(num_value)
				print("DEBUG [PostfixEval]: Pushed number ", num_value)
				
			CoreParser.TokenType.STRING:
				var str_value = token.value
				if (str_value.begins_with("\"") and str_value.ends_with("\"")) or (str_value.begins_with("'") and str_value.ends_with("'")):
					str_value = str_value.substr(1, str_value.length() - 2)
				stack.append(str_value)
				print("DEBUG [PostfixEval]: Pushed string '", str_value, "'")
				
			CoreParser.TokenType.IDENTIFIER:
				if token.is_function_call:
					# Execute the function call
					var func_statement = CoreParser.Statement.new(
						CoreParser.StatementType.EXPRESSION,
						token.func_tokens,
						token.line
					)
					var result = await core_interpreter.function_interpreter.execute_function_call(func_statement)
					stack.append(result)
					print("DEBUG [PostfixEval]: Pushed function result ", result)
				else:
					if token.value.to_lower() == "true":
						stack.append(true)
						print("DEBUG [PostfixEval]: Pushed boolean true")
					elif token.value.to_lower() == "false":
						stack.append(false)
						print("DEBUG [PostfixEval]: Pushed boolean false")
					elif core_interpreter.environment.has_variable(token.value):
						var var_value = core_interpreter.environment.get_variable(token.value)
						stack.append(var_value)
						print("DEBUG [PostfixEval]: Pushed variable ", token.value, " = ", var_value)
					else:
						core_interpreter.emit_error("Undefined variable or function: " + token.value)
						return null
						
			CoreParser.TokenType.OPERATOR:
				# Handle unary operators
				if token.value in ["u-", "u+", "!", "not", "u!", "unot"]:
					if stack.size() < 1:
						core_interpreter.emit_error("Not enough operands for unary operator: " + token.value)
						return null
					
					var operand = stack.pop_back()
					print("DEBUG [PostfixEval]: Applying unary operator ", token.value, " to ", operand)
					
					match token.value:
						"u-":
							operand = convert_to_number(operand)
							stack.append(-operand)
						"u+":
							operand = convert_to_number(operand)
							stack.append(operand)
						"!", "not", "u!", "unot":
							stack.append(!to_boolean(operand))
				else:
					# Handle binary operators
					if stack.size() < 2:
						core_interpreter.emit_error("Not enough operands for operator: " + token.value)
						return null
					
					var right = stack.pop_back()
					var left = stack.pop_back()
					print("DEBUG [PostfixEval]: Applying operator ", token.value, " to ", left, " and ", right)
					
					var result = null
					match token.value:
						"+":
							if left is String or right is String:
								result = str(left) + str(right)
							else:
								left = convert_to_number(left)
								right = convert_to_number(right)
								result = left + right
						"-":
							left = convert_to_number(left)
							right = convert_to_number(right)
							result = left - right
						"*":
							left = convert_to_number(left)
							right = convert_to_number(right)
							result = left * right
						"/":
							left = convert_to_number(left)
							right = convert_to_number(right)
							if right == 0:
								core_interpreter.emit_error("Division by zero")
								return null
							result = left / right
						"%":
							left = convert_to_number(left)
							right = convert_to_number(right)
							if right == 0:
								core_interpreter.emit_error("Modulo by zero")
								return null
							result = fmod(left, right)
						"^":
							left = convert_to_number(left)
							right = convert_to_number(right)
							result = pow(left, right)
						"==":
							result = _safe_equality_compare(left, right)
						"!=":
							result = !_safe_equality_compare(left, right)
						"<":
							if _can_compare(left, right):
								result = left < right
							else:
								left = convert_to_number(left)
								right = convert_to_number(right)
								result = left < right
						">":
							if _can_compare(left, right):
								result = left > right
							else:
								left = convert_to_number(left)
								right = convert_to_number(right)
								result = left > right
						"<=":
							if _can_compare(left, right):
								result = left <= right
							else:
								left = convert_to_number(left)
								right = convert_to_number(right)
								result = left <= right
						">=":
							if _can_compare(left, right):
								result = left >= right
							else:
								left = convert_to_number(left)
								right = convert_to_number(right)
								result = left >= right
						"and", "&&":
							result = to_boolean(left) and to_boolean(right)
						"or", "||":
							result = to_boolean(left) or to_boolean(right)
						_:
							core_interpreter.emit_error("Unknown operator: " + token.value)
							return null
					
					print("DEBUG [PostfixEval]: Operation result: ", result)
					stack.append(result)
		
		i += 1
	
	print("DEBUG [PostfixEval]: Final stack: ", stack)
	
	if stack.size() != 1:
		core_interpreter.emit_error("Invalid expression: improper operator/operand count (stack size: " + str(stack.size()) + ")")
		return null
	
	return stack[0]

# Helper function to determine if two values can be compared
func _can_compare(left, right):
	# Both are numbers
	if (left is int or left is float) and (right is int or right is float):
		return true
	# Both are strings
	elif left is String and right is String:
		return true
	# Both are booleans
	elif left is bool and right is bool:
		return true
	# Mixed types cannot be compared
	return false

# Helper function for safe equality comparison
func _safe_equality_compare(left, right):
	# If types match exactly, compare directly
	if typeof(left) == typeof(right):
		return left == right
	
	# Convert numbers to the same type for comparison
	if (left is int or left is float) and (right is int or right is float):
		return float(left) == float(right)
	
	# Convert booleans if comparing with numbers (0 = false, non-zero = true)
	if left is bool and (right is int or right is float):
		if left == false:
			return right == 0
		else:
			return right != 0
	
	if right is bool and (left is int or left is float):
		if right == false:
			return left == 0
		else:
			return left != 0
	
	# Try to convert to compatible types
	if (left is int or left is float or left is bool) and (right is int or right is float or right is bool):
		return convert_to_number(left) == convert_to_number(right)
	
	# String comparison with mixed types
	if left is String or right is String:
		return str(left) == str(right)
	
	# Other type mismatches are considered not equal
	return false

func to_boolean(value):
	if value is bool:
		return value
	elif value is int or value is float:
		return value != 0
	elif value is String:
		return not value.is_empty()
	elif value == null:
		return false
	elif value is Array or value is Dictionary:
		return not value.is_empty()
	else:
		return true  # Default case for other types

func convert_to_number(value):
	if value is bool:
		return 1 if value else 0
	elif value is String:
		var str_value = value.strip_edges()
		if str_value.is_valid_float():
			return float(str_value)
		elif str_value.is_valid_int():
			return int(str_value)
		return 0
	elif value == null:
		return 0
	elif value is int or value is float:
		return value
	return 0  # Default case
	
# Replace the evaluate_list_literal and evaluate_dict_literal functions in ExpressionInterpreter.gd

func evaluate_list_literal(tokens: Array):
	var elements = []
	var i = 1  # Skip opening '['
	
	while i < tokens.size():
		if tokens[i].value == "]":
			i += 1  # Skip closing bracket
			break
			
		# Collect tokens for this element until comma or closing bracket
		var element_tokens = []
		var depth = 0
		var found_element = false
		
		while i < tokens.size():
			var token = tokens[i]
			
			# Handle special cases for nested structures
			if token.type == CoreParser.TokenType.PARENTHESIS_OPEN:
				if token.value in ["[", "{"]:
					depth += 1
				element_tokens.append(token)
			elif token.type == CoreParser.TokenType.PARENTHESIS_CLOSE:
				if token.value in ["]", "}"]:
					depth -= 1
				
				element_tokens.append(token)
				
				# Only break on matching closing bracket for the current list
				if token.value == "]" and depth < 0:
					element_tokens.pop_back()  # Remove the closing bracket from element tokens
					found_element = true
					break
			elif token.value == "," and depth == 0:
				found_element = true
				break  # Found element separator
			else:
				element_tokens.append(token)
			
			i += 1
		
		if not element_tokens.is_empty():
			var value = await evaluate_expression(element_tokens)
			elements.append(value)
		
		if found_element and i < tokens.size() and tokens[i].value == ",":
			i += 1  # Skip comma
	
	return core_interpreter.environment.create_list(elements)

func evaluate_dict_literal(tokens: Array):
	var pairs = {}
	var i = 1  # Skip opening '{'
	
	while i < tokens.size():
		if tokens[i].value == "}":
			i += 1  # Skip closing brace
			break
			
		# Parse key
		var key_tokens = []
		var depth = 0
		var found_colon = false
		
		while i < tokens.size():
			var token = tokens[i]
			
			if token.type == CoreParser.TokenType.PARENTHESIS_OPEN:
				depth += 1
				key_tokens.append(token)
			elif token.type == CoreParser.TokenType.PARENTHESIS_CLOSE:
				depth -= 1
				key_tokens.append(token)
			elif token.value == ":" and depth == 0:
				found_colon = true
				i += 1  # Skip the colon
				break
			else:
				key_tokens.append(token)
			
			i += 1
		
		if not found_colon:
			core_interpreter.emit_error("Expected ':' in dictionary literal")
			return null
		
		# Parse value
		var value_tokens = []
		depth = 0
		var found_separator = false
		
		while i < tokens.size():
			var token = tokens[i]
			
			if token.type == CoreParser.TokenType.PARENTHESIS_OPEN:
				if token.value in ["[", "{"]:
					depth += 1
				value_tokens.append(token)
			elif token.type == CoreParser.TokenType.PARENTHESIS_CLOSE:
				if token.value in ["]", "}"]:
					depth -= 1
				
				value_tokens.append(token)
				
				# End of dictionary
				if token.value == "}" and depth < 0:
					value_tokens.pop_back()  # Remove the closing brace from value tokens
					found_separator = true
					break
			elif token.value == "," and depth == 0:
				found_separator = true
				break  # Found pair separator
			else:
				value_tokens.append(token)
			
			i += 1
		
		if not key_tokens.is_empty():
			var key = await evaluate_expression(key_tokens)
			var value = await evaluate_expression(value_tokens)
			
			# Convert key to string if needed
			if key is String or key is int or key is float or key is bool:
				var key_str = str(key)
				pairs[key_str] = value
			else:
				core_interpreter.emit_error("Dictionary keys must be strings, numbers, or booleans")
				return null
		
		if found_separator and i < tokens.size() and tokens[i].value == ",":
			i += 1  # Skip comma
	
	return core_interpreter.environment.create_dict(pairs)

