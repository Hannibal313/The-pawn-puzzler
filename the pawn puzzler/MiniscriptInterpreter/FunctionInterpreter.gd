class_name FunctionInterpreter
extends RefCounted

var core_interpreter

func _init(core):
	core_interpreter = core

func execute_function_declaration(statement):
	if statement.tokens.size() < 4 or statement.tokens[0].value != "function":
		core_interpreter.emit_error("Invalid function declaration at line " + str(statement.line))
		return
	
	var func_name_token = statement.tokens[1]
	if func_name_token.type != CoreParser.TokenType.IDENTIFIER:
		core_interpreter.emit_error("Invalid function name at line " + str(statement.line))
		return
	
	var func_name = func_name_token.value
	var params = []
	var i = 2
	
	if i < statement.tokens.size() and statement.tokens[i].type == CoreParser.TokenType.PARENTHESIS_OPEN:
		i += 1
		while i < statement.tokens.size() and statement.tokens[i].type != CoreParser.TokenType.PARENTHESIS_CLOSE:
			if statement.tokens[i].type == CoreParser.TokenType.IDENTIFIER:
				params.append(statement.tokens[i].value)
			elif statement.tokens[i].type != CoreParser.TokenType.COMMA:
				core_interpreter.emit_error("Invalid parameter in function declaration at line " + str(statement.line))
				return
			i += 1
		i += 1
	
	if i >= statement.tokens.size() or statement.tokens[i].type != CoreParser.TokenType.COLON:
		core_interpreter.emit_error("Expected ':' after function declaration at line " + str(statement.line))
		return
	
	core_interpreter.environment.set_function(func_name, params, statement.body_statements)

# In FunctionInterpreter.gd, update execute_function_call()
func execute_function_call(statement):
	if statement.tokens.size() < 1 or statement.tokens[0].type != CoreParser.TokenType.IDENTIFIER:
		core_interpreter.emit_error("Invalid function call at line " + str(statement.line))
		return null

	var func_name = statement.tokens[0].value
	var args = []
	var i = 1

	# Improved argument parsing with nested parenthesis support
	if i < statement.tokens.size() and statement.tokens[i].type == CoreParser.TokenType.PARENTHESIS_OPEN:
		i += 1  # Skip opening '('
		
		# Handle empty argument list
		if i < statement.tokens.size() and statement.tokens[i].type == CoreParser.TokenType.PARENTHESIS_CLOSE:
			print("DEBUG [FunctionCall]: Calling ", func_name, " with empty args")
			# Just continue with empty args list
		else:
			var current_arg = []
			var paren_level = 1
			var in_string = false
			
			while i < statement.tokens.size():
				var token = statement.tokens[i]
				
				# Skip the token in the next iteration
				i += 1
				
				# Track string literals to avoid splitting commas inside strings
				if token.type == CoreParser.TokenType.STRING:
					var str_value = token.value
					# Toggle in_string only at matching quotes
					if (str_value.begins_with("\"") and str_value.ends_with("\"")) or (str_value.begins_with("'") and str_value.ends_with("'")):
						in_string = !in_string
				
				if not in_string:
					# Handle nested parentheses
					if token.type == CoreParser.TokenType.PARENTHESIS_OPEN:
						paren_level += 1
						current_arg.append(token)
					elif token.type == CoreParser.TokenType.PARENTHESIS_CLOSE:
						paren_level -= 1
						if paren_level == 0:
							# End of function arguments
							if not current_arg.is_empty():
								args.append(await core_interpreter.evaluate_expression(current_arg))
							break
						current_arg.append(token)
					# Split arguments at top-level commas
					elif token.type == CoreParser.TokenType.COMMA and paren_level == 1:
						if not current_arg.is_empty():
							args.append(await core_interpreter.evaluate_expression(current_arg))
						current_arg = []
					else:
						current_arg.append(token)
				else:
					current_arg.append(token)
	
	print("DEBUG [FunctionCall]: Calling ", func_name, " with args ", args)

	# User-defined functions
	if core_interpreter.environment.has_function(func_name):
		return await execute_user_defined_function(func_name, args)
	
	# Standard library
	if core_interpreter.stdlib and core_interpreter.stdlib.has_method("std_" + func_name):
		return await core_interpreter.stdlib.callv("std_" + func_name, [args])
	
	core_interpreter.emit_error("Undefined function '" + func_name + "'")
	return null

func execute_user_defined_function(func_name: String, args: Array):
	var func_data = core_interpreter.environment.get_function_data(func_name)
	if func_data == null:
		core_interpreter.emit_error("Function '" + func_name + "' not found")
		return null

	# Create new scope with parent variables
	var parent_vars = core_interpreter.environment.variables.duplicate(true)
	var new_scope = parent_vars.duplicate(true)  # Proper deep copy
	core_interpreter.environment.variables = new_scope

	# Recursion check
	var recursion_depth = 0
	for call in core_interpreter.call_stack:
		if call.name == func_name:
			recursion_depth += 1
			if recursion_depth > 100:
				core_interpreter.emit_error("Max recursion depth (100) exceeded in '" + func_name + "'")
				core_interpreter.environment.variables = parent_vars
				return null

	# Store control state
	var previous_control = {
		"should_return": core_interpreter.should_return,
		"return_value": core_interpreter.return_value,
		"should_break": core_interpreter.should_break,
		"should_continue": core_interpreter.should_continue
	}

	# Reset control flags
	core_interpreter.should_return = false
	core_interpreter.return_value = null

	# Set parameters with type conversion
	var params = func_data.get("params", [])
	for i in range(params.size()):
		var param_name = params[i]
		var param_value = args[i] if i < args.size() else null
		
		# Convert number strings to actual numbers
		if param_value is String:
			if param_value.is_valid_int():
				param_value = int(param_value)
			elif param_value.is_valid_float():
				param_value = float(param_value)
		
		# Handle nested function calls
		if param_value is Dictionary && param_value.get("type") == "FUNCTION":
			param_value = param_value.value  # Unwrap function objects
		
		core_interpreter.environment.set_variable(param_name, param_value)
		print("DEBUG [Function] Set param ", param_name, " = ", param_value)

	# Add to call stack
	core_interpreter.call_stack.push_back({
		"name": func_name,
		"depth": recursion_depth + 1,
		"scope": new_scope
	})

	# Execute function body
	var return_value = null
	for statement in func_data.get("body", []):
		if !core_interpreter.is_running || core_interpreter.should_return:
			break
		await core_interpreter.execute_statement(statement)
		print("DEBUG [Function] After statement execution - return: ", 
			  core_interpreter.return_value)

	# Get return value before cleanup
	return_value = core_interpreter.return_value
	
	# Cleanup
	core_interpreter.call_stack.pop_back()
	core_interpreter.environment.variables = parent_vars  # Restore parent scope
	
	# Restore control flags
	core_interpreter.should_return = previous_control.should_return
	core_interpreter.return_value = previous_control.return_value
	core_interpreter.should_break = previous_control.should_break
	core_interpreter.should_continue = previous_control.should_continue

	print("DEBUG [Function] Returning from ", func_name, " with ", return_value)
	return return_value

# Enhanced debugging for user-defined function execution
#func execute_user_defined_function(func_name: String, args: Array):
	#var func_data = core_interpreter.environment.functions[func_name]
	#
	#print("DEBUG [UserFunction]: Executing function '", func_name, "' with data: ", func_data)
	#
	## Create a new scope for function execution
	#var previous_variables = core_interpreter.environment.variables.duplicate()
	#
	## Set function parameters
	#var params = func_data.get("params", [])
	#print("DEBUG [UserFunction]: Setting parameters - params:", params, ", args:", args)
	#for i in range(min(params.size(), args.size())):
		#core_interpreter.environment.set_variable(params[i], args[i])
		#print("DEBUG [UserFunction]: Set parameter", params[i], "=", args[i])
	#
	## Add the function call to the call stack
	#core_interpreter.call_stack.push_back({
		#"name": func_name,
		#"type": "function"
	#})
	#
	## Save previous control flow state
	#var previous_should_return = core_interpreter.should_return
	#var previous_return_value = core_interpreter.return_value
	#
	## Reset control flow flags
	#core_interpreter.should_return = false
	#core_interpreter.return_value = null
	#
	## Execute the function body
	#var body_statements = func_data.get("body", [])
	#print("DEBUG [UserFunction]: Executing", body_statements.size(), "statements in function body")
	#
	#for i in range(body_statements.size()):
		#var statement = body_statements[i]
		#print("DEBUG [UserFunction]: Executing statement", i, "- type:", statement.type)
		#
		## Execute each statement
		#core_interpreter.execute_statement(statement)
		#
		## Check if we should exit the function
		#if core_interpreter.should_return:
			#print("DEBUG [UserFunction]: Return statement encountered, exiting function")
			#break
	#
	## Get return value before restoring state
	#var result = core_interpreter.return_value
	#print("DEBUG [UserFunction]: Function '", func_name, "' execution completed, returned: ", result)
	#
	## Pop the function call from the stack
	#if not core_interpreter.call_stack.is_empty():
		#core_interpreter.call_stack.pop_back()
	#
	## Restore previous state
	#core_interpreter.environment.variables = previous_variables
	#core_interpreter.should_return = previous_should_return
	#core_interpreter.return_value = previous_return_value
	#
	#return result

func execute_return_statement(statement):
	if core_interpreter.call_stack.is_empty():
		core_interpreter.emit_error("'return' outside of function at line " + str(statement.line))
		return
	
	if statement.tokens.size() > 1:
		var expr_tokens = statement.tokens.slice(1)
		core_interpreter.return_value = core_interpreter.evaluate_expression(expr_tokens)
	else:
		core_interpreter.return_value = null
	
	core_interpreter.should_return = true

func execute_pass_statement(_statement):
	pass

func execute_break_statement(statement):
	if not (core_interpreter.call_stack.size() > 0 and 
		   (get_current_loop_type() == "while" or get_current_loop_type() == "for")):
		core_interpreter.emit_error("'break' outside of loop at line " + str(statement.line))
		return
	core_interpreter.should_break = true

func execute_continue_statement(statement):
	if not (core_interpreter.call_stack.size() > 0 and 
		   (get_current_loop_type() == "while" or get_current_loop_type() == "for")):
		core_interpreter.emit_error("'continue' outside of loop at line " + str(statement.line))
		return
	core_interpreter.should_continue = true

func get_current_loop_type() -> String:
	return "while"  # Simplified - implement proper tracking
