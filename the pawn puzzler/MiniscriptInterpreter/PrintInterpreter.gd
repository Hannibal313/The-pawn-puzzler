class_name PrintInterpreter
extends RefCounted

var core_interpreter

func _init(core):
	core_interpreter = core

func execute_print_statement(statement):
	var tokens = statement.tokens
	
	# Basic validation - must start with print and have matching parentheses
	if tokens.size() < 3 or tokens[0].type != CoreParser.TokenType.KEYWORD or tokens[0].value != "print":
		core_interpreter.emit_error("Invalid print statement at line " + str(statement.line))
		return
	
	# Handle empty print()
	if tokens.size() == 3 and tokens[1].type == CoreParser.TokenType.PARENTHESIS_OPEN and tokens[2].type == CoreParser.TokenType.PARENTHESIS_CLOSE:
		core_interpreter.emit_output("")  # Print empty line
		return
	
	# Validate parentheses structure
	if tokens[1].type != CoreParser.TokenType.PARENTHESIS_OPEN or tokens[-1].type != CoreParser.TokenType.PARENTHESIS_CLOSE:
		core_interpreter.emit_error("Invalid print statement parentheses at line " + str(statement.line))
		return
	
	# Extract all tokens between parentheses
	var expr_tokens = tokens.slice(2, tokens.size() - 1)
	
	# Handle multiple arguments separated by commas
	var output_values = []
	var current_expr = []
	var paren_count = 0
	
	for token in expr_tokens:
		if token.type == CoreParser.TokenType.COMMA and paren_count == 0:
			if current_expr.size() > 0:
				# Clear errors before evaluating each expression
				core_interpreter.clear_errors()
				var value = await core_interpreter.evaluate_expression(current_expr)
				
				# Check if it's a special error object
				if typeof(value) == TYPE_DICTIONARY and value.get("type") == "ERROR":
					output_values.append(value.get("message", "Unknown error"))
				# Check if an error occurred during evaluation
				elif core_interpreter.has_errors():
					output_values.append("Error: " + core_interpreter.get_last_error())
				else:
					output_values.append(format_value(value))
				current_expr = []
		else:
			if token.type == CoreParser.TokenType.PARENTHESIS_OPEN:
				paren_count += 1
			elif token.type == CoreParser.TokenType.PARENTHESIS_CLOSE:
				paren_count -= 1
			current_expr.append(token)
	
	# Add the last expression (ONLY ONCE)
	if current_expr.size() > 0:
		# Clear errors before evaluating the last expression
		core_interpreter.clear_errors()
		var value = await core_interpreter.evaluate_expression(current_expr)
		
		# Check if it's a special error object
		if typeof(value) == TYPE_DICTIONARY and value.get("type") == "ERROR":
			output_values.append(value.get("message", "Unknown error"))
		# Check if an error occurred during evaluation
		elif core_interpreter.has_errors():
			output_values.append("Error: " + core_interpreter.get_last_error())
		else:
			output_values.append(format_value(value))
	
	# Join all values with spaces (like Python's print)
	var output_string = " ".join(output_values)
	core_interpreter.emit_output(output_string)

# Format a value to proper string representation
func format_value(value):
	# Handle special error object or check for interpreter errors
	if value == null:
		if core_interpreter.has_errors():
			return "Error: " + core_interpreter.get_last_error()
		return "null"
	elif typeof(value) == TYPE_DICTIONARY and value.get("type") == "ERROR":
		return value.get("message", "Unknown error")
	elif core_interpreter.is_list(value):
		var elements = []
		for item in core_interpreter.get_list_value(value):
			elements.append(format_value(item))
		return "[" + ", ".join(elements) + "]"
	elif core_interpreter.is_dict(value):
		var pairs = []
		var dict_value = core_interpreter.get_dict_value(value)
		for key in dict_value:
			pairs.append(str(key) + ": " + format_value(dict_value[key]))
		return "{" + ", ".join(pairs) + "}"
	elif value is bool:
		return "true" if value else "false"
	else:
		return str(value)
