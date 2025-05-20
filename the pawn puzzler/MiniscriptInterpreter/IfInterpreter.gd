class_name IfInterpreter
extends RefCounted

var core_interpreter

func _init(core):
	core_interpreter = core

func execute_if_statement(statement):
	# Check if this is a blank else statement (part of an else branch)
	if statement.tokens.size() == 0:
		# This is an else block, just execute the body statements
		for body_statement in statement.if_body_statements:
			await core_interpreter.execute_statement(body_statement)
			
			# Check for control flow interruptions
			if core_interpreter.should_return or core_interpreter.should_break or core_interpreter.should_continue:
				break
		return
	
	# Main if statement or elif statement
	var condition_result = await core_interpreter.evaluate_condition(statement.condition_tokens)
	
	if condition_result:
		# Execute if/elif body
		for body_statement in statement.if_body_statements:
			await core_interpreter.execute_statement(body_statement)
			
			# Check for control flow interruptions
			if core_interpreter.should_return or core_interpreter.should_break or core_interpreter.should_continue:
				break
	else:
		# Try each elif/else branch
		for else_statement in statement.else_body_statements:
			if else_statement.tokens.size() == 0:
				# This is an else block (no condition)
				for body_statement in else_statement.if_body_statements:
					await core_interpreter.execute_statement(body_statement)
					
					# Check for control flow interruptions
					if core_interpreter.should_return or core_interpreter.should_break or core_interpreter.should_continue:
						break
				break  # After executing the else block, we're done
			else:
				# This is an elif block
				var elif_condition = await core_interpreter.evaluate_condition(else_statement.condition_tokens)
				if elif_condition:
					for body_statement in else_statement.if_body_statements:
						await core_interpreter.execute_statement(body_statement)
						
						# Check for control flow interruptions
						if core_interpreter.should_return or core_interpreter.should_break or core_interpreter.should_continue:
							break
					break  # We found a matching elif, so we're done
