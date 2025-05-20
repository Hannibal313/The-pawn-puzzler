class_name MiniscriptEnvironment
extends RefCounted

const PI = 3.141592653589793
const TAU = 6.283185307179586
const E = 2.718281828459045

var core_interpreter = null
var variables = {}
var functions = {}
var value_types = {
	"NUMBER": "NUMBER",
	"STRING": "STRING",
	"BOOLEAN": "BOOLEAN",
	"LIST": "LIST",
	"DICT": "DICT",
	"FUNCTION": "FUNCTION",
	"NULL": "NULL"
}


func _init(core_interp = null):
	core_interpreter = core_interp
	# Add math constants to global variables
	variables["PI"] = PI
	variables["TAU"] = TAU
	variables["E"] = E
	
func clear():
	variables.clear()
	# Keep built-in functions
	var built_in_funcs = functions.duplicate()
	functions.clear()
	functions = built_in_funcs

func get_variable(name: String):
	if variables.has(name):
		return variables[name]
	return null

func set_variable(name: String, value):
	variables[name] = value

func has_variable(name: String) -> bool:
	return variables.has(name)

func register_function(name: String, callable: Callable):
	functions[name] = callable

func has_function(name: String) -> bool:
	return functions.has(name)

#func call_function(name: String, args: Array = []):
	#print("DEBUG: call_function:", name, "with args:", args)
	#if has_function(name):
		#return functions[name].call(args)
	#return null

func debug_variables() -> String:
	var debug = ""
	for var_name in variables:
		debug += var_name + " = " + str(variables[var_name]) + "\n"
	return debug

# Helper methods for type checking and creation
func is_list(value) -> bool:
	if typeof(value) == TYPE_DICTIONARY and value.get("type") == value_types.LIST:
		return true
	return false

func is_dict(value) -> bool:
	if typeof(value) == TYPE_DICTIONARY and value.get("type") == value_types.DICT:
		return true
	return false

func create_list(elements: Array) -> Dictionary:
	print("DEBUG: Creating list with elements: ", elements)
	return {"type": value_types.LIST, "value": elements}

func create_dict(pairs: Dictionary) -> Dictionary:
	# Improved debug print that shows complete dictionary content
	var debug_pairs = {}
	for key in pairs:
		debug_pairs[key] = pairs[key]
	print("DEBUG: Creating dict with pairs: ", debug_pairs)
	return {"type": value_types.DICT, "value": pairs}

# Function to convert our internal types to string representations
func format_value_as_string(value) -> String:
	if value == null:
		return "null"
	elif is_list(value):
		var elements = []
		for item in value.value:
			elements.append(format_value_as_string(item))
		return "[" + ", ".join(elements) + "]"
	elif is_dict(value):
		var pairs = []
		for key in value.value:
			pairs.append(str(key) + ": " + format_value_as_string(value.value[key]))
		return "{" + ", ".join(pairs) + "}"
	elif value is bool:
		return "true" if value else "false"
	else:
		return str(value)
		

func set_function(name: String, params: Array, body_statements: Array):
	# Store the function as a dictionary containing the parameters and body
	functions[name] = {
		"params": params,
		"body": body_statements
	}

func call_function(name: String, args: Array = []):
	print("DEBUG: call_function:", name, "with args:", args)
	if has_function(name):
		var func_data = functions[name]
		# Check if the function is a callable (built-in function)
		if func_data is Callable:
			return func_data.call(args)
		# It's a user-defined function, return its data for the FunctionInterpreter to handle
		return func_data
	return null

func get_function_data(name: String):
	if has_function(name):
		return functions[name]
	return null



func call_user_function(name: String, args: Array = []):
	var func_data = functions.get(name)
	if func_data == null or typeof(func_data) != TYPE_DICTIONARY:
		return null
	
	# This is just a data accessor - actual execution happens in FunctionInterpreter
	return func_data

#func call_user_function(name: String, args: Array = []):
	#var func_data = functions.get(name)
	#if func_data == null:
		#return null
	
	# This should be handled by the FunctionInterpreter
	return func_data
func debug_type(value) -> String:
	if value == null:
		return "null"
	elif is_list(value):
		return "LIST"
	elif is_dict(value):
		return "DICT"
	else:
		return str(typeof(value))

