class_name CodeRunner
extends RefCounted

signal standard_output(text)
signal error_output(text)
signal execution_completed
signal execution_stopped

var interpreter = CoreInterpreter.new()
var is_running = false

func _init():
	# Connect interpreter signals
	interpreter.standard_output.connect(_on_interpreter_output)
	interpreter.error_output.connect(_on_interpreter_error)

func _on_interpreter_output(text: String):
	standard_output.emit(text)

func _on_interpreter_error(text: String):
	error_output.emit(text)

func reset():
	interpreter.reset()

func execute(code: String):
	is_running = true
	interpreter.clear_errors()
	await interpreter.execute(code)
	
	if interpreter.has_errors():
		error_output.emit("Execution error: " + interpreter.get_last_error())
	else:
		standard_output.emit("Execution completed.")
	
	is_running = false
	execution_completed.emit()

func stop_execution():
	if is_running:
		interpreter.stop_execution()
		is_running = false
		execution_stopped.emit()

func has_errors() -> bool:
	return interpreter.has_errors()

func get_last_error() -> String:
	return interpreter.get_last_error()
