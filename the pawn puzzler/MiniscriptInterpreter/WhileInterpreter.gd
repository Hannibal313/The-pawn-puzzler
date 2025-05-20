class_name WhileInterpreter
extends RefCounted

var core_interpreter

func _init(core):
	core_interpreter = core

func execute_while_loop(statement):
	# Evaluate condition with type checking (deepseek)
	var condition = core_interpreter.evaluate_expression(statement.condition_tokens)
	if not (condition is bool):
		core_interpreter.emit_error(
			"While condition must evaluate to boolean (got %s)" % str(typeof(condition)),
			statement.line
		)
		core_interpreter.stop_execution()
		return
	if not core_interpreter.is_running:
		return
	
	var condition_tokens = statement.condition_tokens
	var body_statements = statement.body_statements
	var last_yield_time = Time.get_ticks_msec()
	var iteration_count = 0
	
	while core_interpreter.is_running:
		iteration_count += 1
		
		# Check iteration limit
		if iteration_count > core_interpreter.MAX_ITERATIONS:
			core_interpreter.emit_error("While loop exceeded maximum iterations at line " + str(statement.line))
			core_interpreter.stop_execution()
			return
		
		# Evaluate condition
		var condition_result = core_interpreter.evaluate_expression(condition_tokens)
		condition_result = core_interpreter.to_boolean(condition_result)
		
		if not condition_result:
			break
		
		# Yield periodically
		var current_time = Time.get_ticks_msec()
		if current_time - last_yield_time >= core_interpreter.yield_time * 1000:
			core_interpreter.execution_yielded.emit()
			await Engine.get_main_loop().create_timer(core_interpreter.yield_time).timeout
			last_yield_time = Time.get_ticks_msec()
			if not core_interpreter.is_running:
				break
		
		# Execute body
		for body_statement in body_statements:
			if not core_interpreter.is_running or core_interpreter.should_return:
				return
			if core_interpreter.should_break or core_interpreter.should_continue:
				break
			await core_interpreter.execute_statement(body_statement)
		
		# Handle flow control
		if core_interpreter.should_break:
			core_interpreter.should_break = false
			break
		
		if core_interpreter.should_continue:
			core_interpreter.should_continue = false
			continue
