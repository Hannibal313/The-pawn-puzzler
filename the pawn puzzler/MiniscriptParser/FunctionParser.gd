class_name FunctionParser
extends RefCounted

var core_parser

func _init(core):
	core_parser = core

func parse_function(statement: CoreParser.Statement, lines: Array, current_line: int, current_indent: int) -> CoreParser.Statement:
	if statement.tokens.size() < 4 or statement.tokens[0].value != "function":
		return create_error("Invalid function declaration", statement.line)
	
	var func_name_token = statement.tokens[1]
	if func_name_token.type != CoreParser.TokenType.IDENTIFIER:
		return create_error("Invalid function name", statement.line)
	
	var func_name = func_name_token.value
	var params = []
	var i = 2
	
	if i < statement.tokens.size() and statement.tokens[i].type == CoreParser.TokenType.PARENTHESIS_OPEN:
		i += 1
		while i < statement.tokens.size() and statement.tokens[i].type != CoreParser.TokenType.PARENTHESIS_CLOSE:
			if statement.tokens[i].type == CoreParser.TokenType.IDENTIFIER:
				params.append(statement.tokens[i].value)
			elif statement.tokens[i].type != CoreParser.TokenType.COMMA:
				return create_error("Invalid parameter in function declaration", statement.line)
			i += 1
		i += 1
	
	if i >= statement.tokens.size() or statement.tokens[i].type != CoreParser.TokenType.COLON:
		return create_error("Expected ':' after function declaration", statement.line)
	
	var body_lines = []
	var found_end = false
	var depth = 1  # Track nested blocks depth
	i = current_line + 1
	
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		if line.is_empty() or line.begins_with("#"):
			i += 1
			continue
		
		# Track nested blocks to properly find the function end
		var tokens = core_parser.tokenize(line, i + 1)
		if tokens.size() > 0 and tokens[0].type == CoreParser.TokenType.KEYWORD:
			match tokens[0].value:
				"if", "while", "for", "function", "repeat":
					depth += 1
				"end":
					depth -= 1
					if depth == 0:
						found_end = true
						i += 1
						break
		
		body_lines.append(lines[i])
		i += 1
	
	if not found_end:
		return create_error("Missing 'end' for function", statement.line)
	
	if body_lines.size() > 0:
		var body_code = "\n".join(body_lines)
		var nested_statements = core_parser.parse(body_code)
		
		# Check if there was a parsing error in the function body
		if nested_statements.size() > 0 and nested_statements[0].type == CoreParser.StatementType.UNKNOWN:
			return nested_statements[0]  # Return the parse error
			
		statement.body_statements = nested_statements
	
	statement.line_advance = i - current_line
	return statement

func execute_function_declaration(statement: CoreParser.Statement) -> void:
	var func_name = statement.tokens[1].value
	var params = []
	
	# Extract parameters
	var i = 2
	if i < statement.tokens.size() and statement.tokens[i].type == CoreParser.TokenType.PARENTHESIS_OPEN:
		i += 1
		while i < statement.tokens.size() and statement.tokens[i].type != CoreParser.TokenType.PARENTHESIS_CLOSE:
			if statement.tokens[i].type == CoreParser.TokenType.IDENTIFIER:
				params.append(statement.tokens[i].value)
			i += 1
	
	# Create function object
	var function_obj = {
		"name": func_name,
		"params": params,
		"body": statement.body_statements,
		"line": statement.line
	}
	
	# Register function in environment
	core_parser.environment.define_function(func_name, function_obj)

func execute_return_statement(statement: CoreParser.Statement) -> void:
	if statement.tokens.size() <= 1:
		# Return with no value
		core_parser.should_return = true
		core_parser.return_value = null
		return
	
	# Evaluate expression and return its value
	var value_tokens = statement.tokens.slice(1)
	var value = await core_parser.evaluate_expression(value_tokens)
	
	core_parser.should_return = true
	core_parser.return_value = value

func execute_pass_statement(_statement: CoreParser.Statement) -> void:
	# Do nothing, just a placeholder
	pass

func execute_break_statement(_statement: CoreParser.Statement) -> void:
	core_parser.should_break = true

func execute_continue_statement(_statement: CoreParser.Statement) -> void:
	core_parser.should_continue = true

func create_error(msg: String, line: int) -> CoreParser.Statement:
	var error_token = CoreParser.Token.new(CoreParser.TokenType.UNKNOWN, msg, line)
	return CoreParser.Statement.new(CoreParser.StatementType.UNKNOWN, [error_token], line)
