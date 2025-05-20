class_name RepeatUntilInterpreter
extends RefCounted

var core_interpreter

func _init(core):
	core_interpreter = core

func execute_repeat_until_loop(statement):
	if not core_interpreter.is_running:
		return
	
	var body_statements = statement.body_statements
	var condition_tokens = statement.condition_tokens
	
	# Save and reset flow control states
	var old_should_break = core_interpreter.should_break
	var old_should_continue = core_interpreter.should_continue
	core_interpreter.should_break = false
	core_interpreter.should_continue = false
	
	var should_continue_loop = true
	var last_yield_time = Time.get_ticks_msec()
	var iteration_count = 0
	
	while should_continue_loop and core_interpreter.is_running:
		iteration_count += 1
		
		# Check iteration limit
		if iteration_count > core_interpreter.MAX_ITERATIONS:
			core_interpreter.emit_error("Repeat-until loop exceeded maximum iterations at line " + str(statement.line))
			core_interpreter.stop_execution()
			break
		
		# Execute body
		for sub_statement in body_statements:
			if not core_interpreter.is_running or core_interpreter.should_return:
				break
			
			await core_interpreter.execute_statement(sub_statement)
			
			# Handle break/continue
			if core_interpreter.should_break:
				core_interpreter.should_break = false
				should_continue_loop = false
				break
			
			if core_interpreter.should_continue:
				core_interpreter.should_continue = false
				break
		
		# Yield periodically
		var current_time = Time.get_ticks_msec()
		if current_time - last_yield_time >= core_interpreter.yield_time * 1000:
			core_interpreter.execution_yielded.emit()
			await Engine.get_main_loop().create_timer(core_interpreter.yield_time).timeout
			last_yield_time = Time.get_ticks_msec()
			if not core_interpreter.is_running:
				break
		
		# Check until condition (inverted for repeat-until)
		if should_continue_loop:
			var condition_result = core_interpreter.evaluate_condition(condition_tokens)
			condition_result = core_interpreter.to_boolean(condition_result)
			should_continue_loop = not condition_result
	
	# Restore flow control states
	core_interpreter.should_break = old_should_break
	core_interpreter.should_continue = old_should_continue
