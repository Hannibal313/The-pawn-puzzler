class_name CoreInterpreter
extends RefCounted



signal standard_output(text)
signal error_output(text)
signal execution_yielded()
signal function_called(name)
signal function_returned(value)

var value_types = {
	"NUMBER": "NUMBER",
	"STRING": "STRING",
	"BOOLEAN": "BOOLEAN",
	"LIST": "LIST",
	"DICT": "DICT",
	"FUNCTION": "FUNCTION",
	"NULL": "NULL"
}

var _has_errors = false
var _last_error = ""
var parser = CoreParser.new()
var environment = MiniscriptEnvironment.new()
var stdlib = MiniscriptStdLib.new(environment)
var keywords = ["var", "print", "if", "else", "while", "for", "function", "return", "pass", "break", "continue", "not", "repeat", "until"]
var max_operations_before_yield = 300
var yield_time = 0.005
var operation_counter = 0
var is_running = false
var iteration_count = 0
var last_performance_check = 0
var MAX_ITERATIONS = 1000000
const OPERATOR_PRECEDENCE = {
	"*": 5, "/": 5, "%": 5,       # Highest precedence
	"+": 4, "-": 4,
	"<": 3, ">": 3, "<=": 3, ">=": 3, "==": 3, "!=": 3,
	"and": 2, "&&": 2,            # Logical AND
	"or": 1, "||": 1              # Logical OR (lowest precedence)
}

var return_value = null
var should_return = false
var should_break = false
var should_continue = false
var call_stack = []

# Child interpreters
var if_interpreter: IfInterpreter
var while_interpreter: WhileInterpreter
var for_interpreter: ForInterpreter
var function_interpreter: FunctionInterpreter
var expression_interpreter: ExpressionInterpreter
var variable_interpreter: VariableInterpreter
var print_interpreter: PrintInterpreter
var repeat_interpreter: RepeatUntilInterpreter

func _init():
	environment = MiniscriptEnvironment.new()  # Pass self as core_interpreter
	stdlib = MiniscriptStdLib.new(environment)
	if_interpreter = IfInterpreter.new(self)
	while_interpreter = WhileInterpreter.new(self)
	for_interpreter = ForInterpreter.new(self)
	function_interpreter = FunctionInterpreter.new(self)
	expression_interpreter = ExpressionInterpreter.new(self)
	variable_interpreter = VariableInterpreter.new(self)
	print_interpreter = PrintInterpreter.new(self)
	repeat_interpreter = RepeatUntilInterpreter.new(self)

func reset():
	environment.clear()
	operation_counter = 0
	is_running = false
	iteration_count = 0
	last_performance_check = 0
	return_value = null
	should_return = false
	should_break = false
	should_continue = false
	call_stack = []

func execute(code: String):
	reset()
	clear_errors()
	is_running = true
	operation_counter = 0
	
	var statements = parser.parse(code)
	
	if statements.size() > 0 and statements[0].type == CoreParser.StatementType.UNKNOWN:
		emit_error(statements[0].tokens[0].value)
		stop_execution()
		return null
	
	for statement in statements:
		if statement.type == CoreParser.StatementType.UNKNOWN:
			emit_error("Syntax error detected - execution aborted")
			stop_execution()
			return null
	
	if !has_errors():
		for statement in statements:
			if not is_running:
				break
			await execute_statement(statement)
	
	is_running = false
	return null

func execute_statement(statement):
	if not is_running:
		return
	
	if should_return or should_break or should_continue:
		return
	
	print("DEBUG [ExecuteStatement]: Executing statement of type ", statement.type, " at line ", statement.line)
	
	operation_counter += 1
	iteration_count += 1
	
	if iteration_count > MAX_ITERATIONS:
		emit_error("Script exceeded maximum execution limit (infinite loop?)")
		stop_execution()
		return
	
	if operation_counter >= max_operations_before_yield:
		operation_counter = 0
		execution_yielded.emit()
		await Engine.get_main_loop().create_timer(yield_time).timeout
	
	if statement.type == CoreParser.StatementType.UNKNOWN:
		emit_error("Unknown statement or syntax error at line " + str(statement.line))
		stop_execution()
		return
	
	match statement.type:
		CoreParser.StatementType.EXPRESSION:
			print("DEBUG [ExecuteStatement]: Processing expression statement")
			# Check if this is a function call
			if statement.tokens.size() > 1 and statement.tokens[0].type == CoreParser.TokenType.IDENTIFIER:
				var func_name = statement.tokens[0].value
				if statement.tokens.size() > 1 and statement.tokens[1].type == CoreParser.TokenType.PARENTHESIS_OPEN:
					# This looks like a function call
					print("DEBUG [ExecuteStatement]: Detected function call to ", func_name)
					function_called.emit(func_name)
					var result = await function_interpreter.execute_function_call(statement)
					if result != null:
						function_returned.emit(result)
					return result
				
			else:
				# Regular expression
				print("DEBUG [ExecuteStatement]: Evaluating regular expression")
				await expression_interpreter.execute_expression(statement)
		CoreParser.StatementType.VARIABLE_DECLARATION:
			await variable_interpreter.execute_variable_declaration(statement)
		CoreParser.StatementType.VARIABLE_ASSIGNMENT:
			await variable_interpreter.execute_variable_assignment(statement)
		CoreParser.StatementType.PRINT_STATEMENT:
			await print_interpreter.execute_print_statement(statement)
		CoreParser.StatementType.WHILE_LOOP:
			await while_interpreter.execute_while_loop(statement)
		CoreParser.StatementType.IF_STATEMENT:
			await if_interpreter.execute_if_statement(statement)
		CoreParser.StatementType.FOR_LOOP:
			await for_interpreter.execute_for_loop(statement)
		CoreParser.StatementType.FUNCTION_DECLARATION:
			await function_interpreter.execute_function_declaration(statement)
		CoreParser.StatementType.RETURN_STATEMENT:
			await function_interpreter.execute_return_statement(statement)
		CoreParser.StatementType.PASS_STATEMENT:
			await function_interpreter.execute_pass_statement(statement)
		CoreParser.StatementType.BREAK_STATEMENT:
			await function_interpreter.execute_break_statement(statement)
		CoreParser.StatementType.CONTINUE_STATEMENT:
			await function_interpreter.execute_continue_statement(statement)
		CoreParser.StatementType.REPEAT_UNTIL_LOOP:
			await repeat_interpreter.execute_repeat_until_loop(statement)
		_:
			emit_error("Unsupported statement type at line " + str(statement.line))
			stop_execution()

func evaluate_condition(tokens: Array):
	return await expression_interpreter.evaluate_condition(tokens)

func infix_to_postfix(tokens: Array) -> Array:
	return expression_interpreter.infix_to_postfix(tokens)

func evaluate_postfix(tokens: Array):
	return await expression_interpreter.evaluate_postfix(tokens)

func to_boolean(value):
	return expression_interpreter.to_boolean(value)

func convert_to_number(value):
	return expression_interpreter.convert_to_number(value)

func emit_output(text: String):
	standard_output.emit(text)

func debug_variables() -> String:
	return environment.debug_variables()

func has_errors() -> bool:
	return _has_errors

func get_last_error() -> String:
	return _last_error

func clear_errors() -> void:
	_has_errors = false
	_last_error = ""

func emit_error(text: String):
	_has_errors = true
	_last_error = text
	error_output.emit("Error: " + text)

func stop_execution():
	is_running = false

func create_list(elements: Array) -> Dictionary:
	return {"type": value_types.LIST, "value": elements}

func create_dict(pairs: Dictionary) -> Dictionary:
	return {"type": value_types.DICT, "value": pairs}


func parse_function_arguments(tokens: Array) -> Array:
	var args = []
	var current_arg_tokens = []
	var paren_level = 0
	
	for token in tokens:
		if token.type == CoreParser.TokenType.PARENTHESIS_OPEN:
			paren_level += 1
			current_arg_tokens.append(token)
		elif token.type == CoreParser.TokenType.PARENTHESIS_CLOSE:
			if paren_level > 0:
				paren_level -= 1
				current_arg_tokens.append(token)
			else:
				break
		elif token.type == CoreParser.TokenType.COMMA and paren_level == 0:
			if not current_arg_tokens.is_empty():
				args.append(await evaluate_expression(current_arg_tokens))
				current_arg_tokens = []
		else:
			current_arg_tokens.append(token)
	
	if not current_arg_tokens.is_empty():
		args.append(await evaluate_expression(current_arg_tokens))
	
	return args
# Add these methods to CoreInterpreter.gd
func is_list(value) -> bool:
	return typeof(value) == TYPE_DICTIONARY and value.get("type") == value_types.LIST

func is_dict(value) -> bool:
	return typeof(value) == TYPE_DICTIONARY and value.get("type") == value_types.DICT

func get_list_value(list_obj) -> Array:
	if is_list(list_obj):
		return list_obj.value
	return []

func get_dict_value(dict_obj) -> Dictionary:
	if is_dict(dict_obj):
		return dict_obj.value
	return {}
func evaluate_expression(tokens: Array):
	return await expression_interpreter.evaluate_expression(tokens)
