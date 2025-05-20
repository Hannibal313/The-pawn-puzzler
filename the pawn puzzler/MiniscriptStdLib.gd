class_name MiniscriptStdLib
extends RefCounted

var environment: MiniscriptEnvironment
var core_interpreter: CoreInterpreter

func _init(env: MiniscriptEnvironment):
	environment = env
	core_interpreter = env.core_interpreter
	register_builtin_functions()
	#print("DEBUG: Registered stdlib functions: ", env.functions.keys())

func _math_error(function_name: String, message: String):
	var error_msg = "Math Error in %s(): %s" % [function_name, message]
	# Set the error state in the core interpreter
	if core_interpreter:
		core_interpreter._has_errors = true
		core_interpreter._last_error = error_msg
		# Also emit to the error output signal
		core_interpreter.error_output.emit(error_msg)
	else:
		push_error("MATH ERROR: " + error_msg)
	# Return a special error object instead of null
	return {"type": "ERROR", "message": error_msg}

func register_builtin_functions() -> void:
	# List functions
	environment.register_function("list_append", Callable(self, "_list_append"))
	environment.register_function("list_get", Callable(self, "_list_get"))
	environment.register_function("list_set", Callable(self, "_list_set"))
	environment.register_function("list_length", Callable(self, "_list_length"))
	environment.register_function("list_remove", Callable(self, "_list_remove"))
	
	# Dict functions
	environment.register_function("dict_get", Callable(self, "_dict_get"))
	environment.register_function("dict_set", Callable(self, "_dict_set"))
	environment.register_function("dict_keys", Callable(self, "_dict_keys"))
	environment.register_function("dict_values", Callable(self, "_dict_values"))
	environment.register_function("dict_has", Callable(self, "_dict_has"))
	environment.register_function("dict_remove", Callable(self, "_dict_remove"))

	# Core Math
	environment.register_function("abs", Callable(self, "_abs"))
	environment.register_function("sqrt", Callable(self, "_sqrt"))
	environment.register_function("pow", Callable(self, "_pow"))
	environment.register_function("round", Callable(self, "_round"))
	environment.register_function("floor", Callable(self, "_floor"))
	environment.register_function("ceil", Callable(self, "_ceil"))
	environment.register_function("fmod", Callable(self, "_fmod"))
	environment.register_function("sign", Callable(self, "_sign"))

	# Advanced Math
	environment.register_function("min", Callable(self, "_min"))
	environment.register_function("max", Callable(self, "_max"))
	environment.register_function("clamp", Callable(self, "_clamp"))
	environment.register_function("lerp", Callable(self, "_lerp"))
	environment.register_function("inverse_lerp", Callable(self, "_inverse_lerp"))
	environment.register_function("smoothstep", Callable(self, "_smoothstep"))

	# Trigonometry
	environment.register_function("sin", Callable(self, "_sin"))
	environment.register_function("cos", Callable(self, "_cos"))
	environment.register_function("tan", Callable(self, "_tan"))
	environment.register_function("asin", Callable(self, "_asin"))
	environment.register_function("acos", Callable(self, "_acos"))
	environment.register_function("atan", Callable(self, "_atan"))
	environment.register_function("atan2", Callable(self, "_atan2"))
	environment.register_function("deg_to_rad", Callable(self, "_deg_to_rad"))
	environment.register_function("rad_to_deg", Callable(self, "_rad_to_deg"))

	# Exponential/Logarithmic
	environment.register_function("exp", Callable(self, "_exp"))
	environment.register_function("log", Callable(self, "_log"))
	environment.register_function("log10", Callable(self, "_log10"))

	# Random
	environment.register_function("random", Callable(self, "_random"))
	environment.register_function("randi", Callable(self, "_randi"))
	environment.register_function("randf", Callable(self, "_randf"))

	# String/Type functions (existing)
	environment.register_function("length", Callable(self, "_length"))
	environment.register_function("substring", Callable(self, "_substring"))
	environment.register_function("uppercase", Callable(self, "_uppercase"))
	environment.register_function("lowercase", Callable(self, "_lowercase"))
	environment.register_function("str", Callable(self, "_str"))
	environment.register_function("num", Callable(self, "_num"))
	environment.register_function("int", Callable(self, "_int"))
	environment.register_function("float", Callable(self, "_float"))

# === MATH FUNCTIONS WITH ERROR HANDLING ===

func _abs(args: Array):
	if args.size() == 0: return _math_error("abs", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("abs", "Argument must be a number")
	return abs(args[0])

func _sqrt(args: Array):
	if args.size() == 0: return _math_error("sqrt", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("sqrt", "Argument must be a number")
	if args[0] < 0: return _math_error("sqrt", "Cannot take square root of negative number")
	return sqrt(args[0])

func _pow(args: Array):
	if args.size() < 2: return _math_error("pow", "Requires 2 arguments")
	if not ((args[0] is int or args[0] is float) and (args[1] is int or args[1] is float)):
		return _math_error("pow", "Arguments must be numbers")
	if args[0] == 0 and args[1] < 0: return _math_error("pow", "Zero cannot be raised to negative power")
	return pow(args[0], args[1])

func _round(args: Array):
	if args.size() == 0: return _math_error("round", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("round", "Argument must be a number")
	return round(args[0])

func _floor(args: Array):
	if args.size() == 0: return _math_error("floor", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("floor", "Argument must be a number")
	return floor(args[0])

func _ceil(args: Array):
	if args.size() == 0: return _math_error("ceil", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("ceil", "Argument must be a number")
	return ceil(args[0])

func _fmod(args: Array):
	if args.size() < 2: return _math_error("fmod", "Requires 2 arguments")
	if not ((args[0] is int or args[0] is float) and (args[1] is int or args[1] is float)):
		return _math_error("fmod", "Arguments must be numbers")
	if args[1] == 0: return _math_error("fmod", "Cannot divide by zero")
	return fmod(args[0], args[1])

func _sign(args: Array):
	if args.size() == 0: return _math_error("sign", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("sign", "Argument must be a number")
	return sign(args[0])

# === ADVANCED MATH ===

func _min(args: Array):
	if args.size() == 0: return _math_error("min", "Requires at least 1 argument")
	
	# Handle list input
	if args.size() == 1 and (args[0] is Array or environment.is_list(args[0])):
		var list = args[0].value if environment.is_list(args[0]) else args[0]
		if list.is_empty(): return _math_error("min", "List cannot be empty")
		if not list.all(func(x): return x is int or x is float): 
			return _math_error("min", "List must contain only numbers")
		return list.reduce(func(a, b): return min(a, b))
	
	# Handle multiple arguments
	if not args.all(func(x): return x is int or x is float):
		return _math_error("min", "All arguments must be numbers")
	return args.reduce(func(a, b): return min(a, b))

func _max(args: Array):
	if args.size() == 0: return _math_error("max", "Requires at least 1 argument")
	
	if args.size() == 1 and (args[0] is Array or environment.is_list(args[0])):
		var list = args[0].value if environment.is_list(args[0]) else args[0]
		if list.is_empty(): return _math_error("max", "List cannot be empty")
		if not list.all(func(x): return x is int or x is float):
			return _math_error("max", "List must contain only numbers")
		return list.reduce(func(a, b): return max(a, b))
	
	if not args.all(func(x): return x is int or x is float):
		return _math_error("max", "All arguments must be numbers")
	return args.reduce(func(a, b): return max(a, b))

func _clamp(args: Array):
	if args.size() < 3: return _math_error("clamp", "Requires 3 arguments")
	if not ((args[0] is int or args[0] is float) and (args[1] is int or args[1] is float) and (args[2] is int or args[2] is float)):
		return _math_error("clamp", "All arguments must be numbers")
	if args[1] > args[2]: return _math_error("clamp", "Min cannot be greater than max")
	return clamp(args[0], args[1], args[2])

func _lerp(args: Array):
	if args.size() < 3: return _math_error("lerp", "Requires 3 arguments")
	if not ((args[0] is int or args[0] is float) and (args[1] is int or args[1] is float) and (args[2] is int or args[2] is float)):
		return _math_error("lerp", "All arguments must be numbers")
	return lerp(args[0], args[1], args[2])

func _inverse_lerp(args: Array):
	if args.size() < 3: return _math_error("inverse_lerp", "Requires 3 arguments")
	if not ((args[0] is int or args[0] is float) and (args[1] is int or args[1] is float) and (args[2] is int or args[2] is float)):
		return _math_error("inverse_lerp", "All arguments must be numbers")
	if args[0] == args[1]: return _math_error("inverse_lerp", "First and second arguments cannot be equal")
	return inverse_lerp(args[0], args[1], args[2])

func _smoothstep(args: Array):
	if args.size() < 3: return _math_error("smoothstep", "Requires 3 arguments")
	if not ((args[0] is int or args[0] is float) and (args[1] is int or args[1] is float) and (args[2] is int or args[2] is float)):
		return _math_error("smoothstep", "All arguments must be numbers")
	if args[0] == args[1]: return _math_error("smoothstep", "First and second arguments cannot be equal")
	return smoothstep(args[0], args[1], args[2])

# === TRIGONOMETRY ===

func _sin(args: Array):
	if args.size() == 0: return _math_error("sin", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("sin", "Argument must be a number")
	return sin(args[0])

func _cos(args: Array):
	if args.size() == 0: return _math_error("cos", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("cos", "Argument must be a number")
	return cos(args[0])

func _tan(args: Array):
	if args.size() == 0: return _math_error("tan", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("tan", "Argument must be a number")
	return tan(args[0])

func _asin(args: Array):
	if args.size() == 0: return _math_error("asin", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("asin", "Argument must be a number")
	if args[0] < -1 or args[0] > 1: return _math_error("asin", "Argument must be between -1 and 1")
	return asin(args[0])

func _acos(args: Array):
	if args.size() == 0: return _math_error("acos", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("acos", "Argument must be a number")
	if args[0] < -1 or args[0] > 1: return _math_error("acos", "Argument must be between -1 and 1")
	return acos(args[0])

func _atan(args: Array):
	if args.size() == 0: return _math_error("atan", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("atan", "Argument must be a number")
	return atan(args[0])

func _atan2(args: Array):
	if args.size() < 2: return _math_error("atan2", "Requires 2 arguments")
	if not ((args[0] is int or args[0] is float) and (args[1] is int or args[1] is float)):
		return _math_error("atan2", "Arguments must be numbers")
	return atan2(args[0], args[1])

func _deg_to_rad(args: Array):
	if args.size() == 0: return _math_error("deg_to_rad", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("deg_to_rad", "Argument must be a number")
	return deg_to_rad(args[0])

func _rad_to_deg(args: Array):
	if args.size() == 0: return _math_error("rad_to_deg", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("rad_to_deg", "Argument must be a number")
	return rad_to_deg(args[0])

# === EXPONENTIAL/LOGARITHMIC ===

func _exp(args: Array):
	if args.size() == 0: return _math_error("exp", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("exp", "Argument must be a number")
	return exp(args[0])

func _log(args: Array):
	if args.size() == 0: return _math_error("log", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("log", "Argument must be a number")
	if args[0] <= 0: return _math_error("log", "Argument must be positive")
	return log(args[0])

func _log10(args: Array):
	if args.size() == 0: return _math_error("log10", "Missing argument")
	if not (args[0] is int or args[0] is float): return _math_error("log10", "Argument must be a number")
	if args[0] <= 0: return _math_error("log10", "Argument must be positive")
	# Use change of base formula: log10(x) = log(x) / log(10)
	return log(args[0]) / log(10.0)

# === RANDOM ===

func _random(args: Array):
	match args.size():
		0: return randf()
		2: 
			if not ((args[0] is int or args[0] is float) and (args[1] is int or args[1] is float)):
				return _math_error("random", "Arguments must be numbers")
			return randf_range(float(args[0]), float(args[1]))
		_: return _math_error("random", "Requires 0 or 2 arguments")

func _randi(args: Array):
	match args.size():
		0: return randi()
		2: 
			if not (args[0] is int and args[1] is int):
				return _math_error("randi", "Arguments must be integers")
			return randi_range(args[0], args[1])
		_: return _math_error("randi", "Requires 0 or 2 arguments")

func _randf(args: Array):
	return _random(args)  # Alias

# List functions
func _list_append(args: Array):
	if args.size() >= 2 and environment.is_list(args[0]):
		var list_value = args[0].value
		list_value.append(args[1])
		return args[0]
	return null

func _list_get(args: Array):
	if args.size() >= 2:
		print("DEBUG: list_get type check: ", environment.is_list(args[0]))
		print("DEBUG: list_get args: ", args)
		if environment.is_list(args[0]) and (args[1] is int or args[1] is float):
			var index = int(args[1])
			if index >= 0 and index < args[0].value.size():
				return args[0].value[index]
	return null

func _list_set(args: Array):
	if args.size() >= 3 and environment.is_list(args[0]) and (args[1] is int or args[1] is float):
		var index = int(args[1])
		if index >= 0 and index < args[0].value.size():
			args[0].value[index] = args[2]
			return args[0]
	return null

func _list_length(args: Array):
	if args.size() >= 1 and environment.is_list(args[0]):
		return args[0].value.size()
	return 0

func _list_remove(args: Array):
	if args.size() >= 2 and environment.is_list(args[0]) and (args[1] is int or args[1] is float):
		var index = int(args[1])
		if index >= 0 and index < args[0].value.size():
			args[0].value.remove_at(index)
			return args[0]
	return null

# Dict functions
func _dict_get(args: Array):
	print("DEBUG: _dict_get args: ", args)
	if args.size() >= 2:
		print("DEBUG: dict_get type check: ", environment.is_dict(args[0]))
		if environment.is_dict(args[0]):
			var key = str(args[1]) if args[1] is int or args[1] is float or args[1] is bool else args[1]
			var value = args[0].value.get(key, null)
			print("DEBUG: dict_get key: ", key, ", value: ", value)
			return value
	return null

func _dict_set(args: Array):
	if args.size() >= 3:
		print("DEBUG: _dict_set args: ", args)
		print("DEBUG: dict_set type check: ", environment.is_dict(args[0]))
		if environment.is_dict(args[0]):
			var key = str(args[1]) if args[1] is int or args[1] is float or args[1] is bool else args[1]
			args[0].value[key] = args[2]
			print("DEBUG: dict after set: ", args[0].value)
			return args[0]
	return null

func _dict_keys(args: Array):
	if args.size() >= 1 and environment.is_dict(args[0]):
		return environment.create_list(args[0].value.keys())
	return environment.create_list([])

func _dict_values(args: Array):
	if args.size() >= 1 and environment.is_dict(args[0]):
		return environment.create_list(args[0].value.values())
	return environment.create_list([])

func _dict_has(args: Array):
	if args.size() >= 2 and environment.is_dict(args[0]):
		var key = str(args[1]) if args[1] is int or args[1] is float or args[1] is bool else args[1]
		return args[0].value.has(key)
	return false

func _dict_remove(args: Array):
	if args.size() >= 2 and environment.is_dict(args[0]):
		var key = str(args[1]) if args[1] is int or args[1] is float or args[1] is bool else args[1]
		args[0].value.erase(key)
		return args[0]
	return null

# String functions
func _length(args: Array):
	if args.size() > 0:
		return str(args[0]).length()
	return 0

func _substring(args: Array):
	if args.size() >= 3 and args[0] is String:
		return args[0].substr(args[1], args[2])
	elif args.size() >= 2 and args[0] is String:
		return args[0].substr(args[1])
	return ""

func _uppercase(args: Array):
	if args.size() > 0 and args[0] is String:
		return args[0].to_upper()
	return ""

func _lowercase(args: Array):
	if args.size() > 0 and args[0] is String:
		return args[0].to_lower()
	return ""

# Type conversion functions
func _str(args: Array):
	if args.size() > 0:
		if environment.is_list(args[0]) or environment.is_dict(args[0]):
			return environment.format_value_as_string(args[0])
		return str(args[0])
	return ""

func _num(args: Array):
	if args.size() > 0:
		if args[0] is String:
			# Try to convert string to number
			if args[0].is_valid_float():
				return float(args[0])
			elif args[0].is_valid_int():
				return int(args[0])
		elif args[0] is int or args[0] is float:
			return args[0]
	return 0

func _int(args: Array):
	if args.size() > 0:
		if args[0] is String and args[0].is_valid_int():
			return int(args[0])
		elif args[0] is int:
			return args[0]
		elif args[0] is float:
			return int(args[0])
	return 0

func _float(args: Array):
	if args.size() > 0:
		if args[0] is String and args[0].is_valid_float():
			return float(args[0])
		elif args[0] is int or args[0] is float:
			return float(args[0])
	return 0.0

# Add this to your MiniscriptStdLib.gd file

func std_print(args: Array):
	print("DEBUG [StdLib]: std_print called with args:", args)
	
	# Handle printing of single or multiple values
	var output = ""
	for i in range(args.size()):
		if i > 0:
			output += " "
		
		# Format the value as a string
		if args[i] == null:
			output += "null"
		# Handle lists and dictionaries if you have custom types
		elif typeof(args[i]) == TYPE_DICTIONARY and args[i].has("type"):
			if args[i].type == "LIST":
				output += format_list_value(args[i])
			elif args[i].type == "DICT":
				output += format_dict_value(args[i])
			else:
				output += str(args[i])
		else:
			output += str(args[i])
	
	# Print to the console
	print(output)
	
	
	
	return null

# Helper methods for formatting complex values
func format_list_value(list_obj):
	var elements = []
	for item in list_obj.value:
		if item == null:
			elements.append("null")
		elif typeof(item) == TYPE_DICTIONARY and item.has("type"):
			if item.type == "LIST":
				elements.append(format_list_value(item))
			elif item.type == "DICT":
				elements.append(format_dict_value(item))
			else:
				elements.append(str(item))
		else:
			elements.append(str(item))
	return "[" + ", ".join(elements) + "]"

func format_dict_value(dict_obj):
	var pairs = []
	for key in dict_obj.value:
		var value = dict_obj.value[key]
		var value_str
		if value == null:
			value_str = "null"
		elif typeof(value) == TYPE_DICTIONARY and value.has("type"):
			if value.type == "LIST":
				value_str = format_list_value(value)
			elif value.type == "DICT":
				value_str = format_dict_value(value)
			else:
				value_str = str(value)
		else:
			value_str = str(value)
		pairs.append(str(key) + ": " + value_str)
	return "{" + ", ".join(pairs) + "}"

func call_function(func_name: String, args: Array):
	if environment.functions.has(func_name):
		var func_data = environment.functions[func_name]
		
		# Check if it's a built-in function (Callable)
		if func_data is Callable:
			return func_data.call(args)
		# If it's a user-defined function, handle it through the function interpreter
		elif func_data is Dictionary:
			# User-defined functions should be handled by FunctionInterpreter
			if core_interpreter and core_interpreter.function_interpreter:
				return await core_interpreter.function_interpreter.execute_user_defined_function(func_name, args)
			else:
				push_error("Cannot call user-defined function: Core interpreter not set")
		
	return null
