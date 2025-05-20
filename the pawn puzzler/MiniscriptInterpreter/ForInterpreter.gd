class_name ForInterpreter
extends RefCounted

var core_interpreter

func _init(core):
	core_interpreter = core

func execute_for_loop(statement):
	if not core_interpreter.is_running:
		return
	
	# Get loop parameters
	var variable = statement.for_variable
	var start = core_interpreter.evaluate_expression(statement.for_start_tokens)
	var end = core_interpreter.evaluate_expression(statement.for_end_tokens)
	var step = core_interpreter.evaluate_expression(statement.for_step_tokens)
	
	# Validate numbers
	if not (start is int or start is float) or not (end is int or end is float) or not (step is int or step is float):
		core_interpreter.emit_error("For loop values must be numbers at line " + str(statement.line))
		core_interpreter.stop_execution()
		return
	
	if step == 0:
		core_interpreter.emit_error("Step cannot be zero at line " + str(statement.line))
		core_interpreter.stop_execution()
		return
	
	# Initialize loop
	core_interpreter.environment.set_variable(variable, start)
	var current = start
	var ascending = step > 0
	
	while core_interpreter.is_running:
		# Check exit condition
		if (ascending and current >= end) or (not ascending and current <= end):
			break
		
		# Execute body
		for body_stmt in statement.body_statements:
			if not core_interpreter.is_running or core_interpreter.should_return:
				return
			if core_interpreter.should_break or core_interpreter.should_continue:
				break
			await core_interpreter.execute_statement(body_stmt)
		
		# Handle flow control
		if core_interpreter.should_break:
			core_interpreter.should_break = false
			break
		if core_interpreter.should_continue:
			core_interpreter.should_continue = false
			continue
		
		# Update loop variable
		current += step
		core_interpreter.environment.set_variable(variable, current)
		
		# Yield to prevent freezing
		await Engine.get_main_loop().process_frame
