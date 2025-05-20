class_name VariableInterpreter
extends RefCounted

var core_interpreter

func _init(core):
	core_interpreter = core

func execute_variable_declaration(statement):
	var tokens = statement.tokens
	if tokens.size() < 4 or tokens[0].value != "var" or tokens[1].type != CoreParser.TokenType.IDENTIFIER or tokens[2].type != CoreParser.TokenType.EQUALS:
		core_interpreter.emit_error("Invalid variable declaration at line " + str(statement.line))
		return
	
	var variable_name = tokens[1].value
	var value = core_interpreter.evaluate_expression(tokens.slice(3))
	core_interpreter.environment.set_variable(variable_name, value)

func execute_variable_assignment(statement):
	var tokens = statement.tokens
	if tokens.size() < 3 or tokens[0].type != CoreParser.TokenType.IDENTIFIER:
		core_interpreter.emit_error("Invalid variable assignment at line " + str(statement.line))
		return
	
	var variable_name = tokens[0].value
	var operator_token = tokens[1]
	
	if not core_interpreter.environment.has_variable(variable_name):
		core_interpreter.emit_error("Undefined variable: " + variable_name + " at line " + str(statement.line))
		return
	
	var current_value = core_interpreter.environment.get_variable(variable_name)
	
	if tokens.size() > 3 and tokens[2].type == CoreParser.TokenType.PARENTHESIS_OPEN:
		if tokens[2].value == "[" and core_interpreter.is_list(current_value):
			return await execute_list_item_assignment(statement, current_value)
		elif tokens[2].value == "{" and core_interpreter.is_dict(current_value):
			return await execute_dict_item_assignment(statement, current_value)
	
	if operator_token.type == CoreParser.TokenType.OPERATOR and operator_token.value in ["+=", "-=", "*=", "/=", "%="]:
		var right_value = core_interpreter.evaluate_expression(tokens.slice(2))
		var result
		
		match operator_token.value:
			"+=":
				if (current_value is int or current_value is float) and (right_value is int or right_value is float):
					result = current_value + right_value
				elif current_value is String or right_value is String:
					result = str(current_value) + str(right_value)
				else:
					core_interpreter.emit_error("Invalid operands for addition at line " + str(statement.line))
					return
			"-=":
				if not (current_value is int or current_value is float) or not (right_value is int or right_value is float):
					core_interpreter.emit_error("Subtraction requires numeric operands at line " + str(statement.line))
					return
				result = current_value - right_value
			"*=":
				if not (current_value is int or current_value is float) or not (right_value is int or right_value is float):
					core_interpreter.emit_error("Multiplication requires numeric operands at line " + str(statement.line))
					return
				result = current_value * right_value
			"/=":
				if not (current_value is int or current_value is float) or not (right_value is int or right_value is float):
					core_interpreter.emit_error("Division requires numeric operands at line " + str(statement.line))
					return
				if right_value == 0:
					core_interpreter.emit_error("Division by zero at line " + str(statement.line))
					return
				result = float(current_value) / float(right_value)
			"%=":
				if not (current_value is int or current_value is float) or not (right_value is int or right_value is float):
					core_interpreter.emit_error("Modulo requires numeric operands at line " + str(statement.line))
					return
				if right_value == 0:
					core_interpreter.emit_error("Modulo by zero at line " + str(statement.line))
					return
				result = fmod(current_value, right_value)
		
		core_interpreter.environment.set_variable(variable_name, result)
		return
	
	if operator_token.type == CoreParser.TokenType.EQUALS:
		var value = core_interpreter.evaluate_expression(tokens.slice(2))
		core_interpreter.environment.set_variable(variable_name, value)
	else:
		core_interpreter.emit_error("Expected assignment operator at line " + str(statement.line))

func execute_list_item_assignment(statement, list_value):
	var tokens = statement.tokens
	var variable_name = tokens[0].value
	
	# Parse index expression
	var index_tokens = []
	var i = 3  # Skip variable name, operator, and opening '['
	while i < tokens.size() and tokens[i].value != "]":
		index_tokens.append(tokens[i])
		i += 1
	
	if index_tokens.is_empty():
		core_interpreter.emit_error("Missing index in list access at line " + str(statement.line))
		return
	
	var index = await core_interpreter.evaluate_expression(index_tokens)
	if not (index is int or index is float):
		core_interpreter.emit_error("List index must be a number at line " + str(statement.line))
		return
	
	index = int(index)
	if index < 0 or index >= list_value.value.size():
		core_interpreter.emit_error("List index out of bounds at line " + str(statement.line))
		return
	
	# Get the value to assign
	var value_tokens = tokens.slice(i + 1)  # Everything after closing ']'
	var value = await core_interpreter.evaluate_expression(value_tokens)
	
	# Update the list
	list_value.value[index] = value
	core_interpreter.environment.set_variable(variable_name, list_value)

func execute_dict_item_assignment(statement, dict_value):
	var tokens = statement.tokens
	var variable_name = tokens[0].value
	
	# Parse key expression
	var key_tokens = []
	var i = 3  # Skip variable name, operator, and opening '{'
	while i < tokens.size() and tokens[i].value != "}":
		key_tokens.append(tokens[i])
		i += 1
	
	if key_tokens.is_empty():
		core_interpreter.emit_error("Missing key in dictionary access at line " + str(statement.line))
		return
	
	var key = await core_interpreter.evaluate_expression(key_tokens)
	if not (key is String or key is int or key is float):
		core_interpreter.emit_error("Dictionary key must be a string or number at line " + str(statement.line))
		return
	
	# Get the value to assign
	var value_tokens = tokens.slice(i + 1)  # Everything after closing '}'
	var value = await core_interpreter.evaluate_expression(value_tokens)
	
	# Update the dictionary
	dict_value.value[key] = value
	core_interpreter.environment.set_variable(variable_name, dict_value)
