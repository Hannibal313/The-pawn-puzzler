class_name ForParser
extends RefCounted

var core_parser

func _init(core):
	core_parser = core

func parse_for(statement, lines, current_line, current_indent):
	# Parse for loop tokens
	var result = parse_for_tokens(statement)
	if result is CoreParser.Statement and result.type == CoreParser.StatementType.UNKNOWN:
		return result
	
	# Find body and end
	var body_lines = []
	var i = current_line + 1
	var end_line = -1
	var depth = 1  # Track nested depth
	
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		if line.is_empty() or line.begins_with("#"):
			i += 1
			continue
		
		# Check for nested blocks
		var tokens = core_parser.tokenize(line, i + 1)
		if tokens.size() > 0 and tokens[0].type == CoreParser.TokenType.KEYWORD:
			match tokens[0].value:
				"for", "while", "if", "function":
					depth += 1
				"end":
					depth -= 1
					if depth == 0:
						end_line = i
						i += 1
						break
		
		body_lines.append(lines[i])
		i += 1
	
	if end_line == -1:
		return create_error("Missing 'end' for 'for' statement", statement.line)
	
	# Parse body
	if body_lines.size() > 0:
		var body_code = "\n".join(body_lines)
		var nested_statements = core_parser.parse(body_code)
		if nested_statements.size() > 0 and nested_statements[0].type == CoreParser.StatementType.UNKNOWN:
			return nested_statements[0]  # Return the parse error
		
		statement.body_statements = nested_statements
	
	statement.line_advance = i - current_line
	return statement

func parse_for_tokens(statement: CoreParser.Statement) -> Variant:
	if statement.tokens.size() < 4:
		return create_error("Invalid for syntax", statement.line)
	
	# Get variable name
	if statement.tokens[1].type != CoreParser.TokenType.IDENTIFIER:
		return create_error("Expected variable name", statement.line)
	statement.for_variable = statement.tokens[1].value
	
	# Check for equals
	if statement.tokens[2].type != CoreParser.TokenType.EQUALS:
		return create_error("Expected '='", statement.line)
	
	# Find commas
	var commas = []
	for i in range(3, statement.tokens.size()):
		if statement.tokens[i].type == CoreParser.TokenType.COMMA:
			commas.append(i)
	
	# Handle different formats
	match commas.size():
		0:  # for x=1 to 10
			statement.for_start_tokens = [CoreParser.Token.new(CoreParser.TokenType.NUMBER, "0", statement.line)]
			statement.for_end_tokens = statement.tokens.slice(3)
			statement.for_step_tokens = [CoreParser.Token.new(CoreParser.TokenType.NUMBER, "1", statement.line)]
		1:  # for x=1,10
			statement.for_start_tokens = statement.tokens.slice(3, commas[0])
			statement.for_end_tokens = statement.tokens.slice(commas[0] + 1)
			statement.for_step_tokens = [CoreParser.Token.new(CoreParser.TokenType.NUMBER, "1", statement.line)]
		_:  # for x=1,10,2
			statement.for_start_tokens = statement.tokens.slice(3, commas[0])
			statement.for_end_tokens = statement.tokens.slice(commas[0] + 1, commas[1])
			statement.for_step_tokens = statement.tokens.slice(commas[1] + 1)
	
	return statement

func create_error(msg: String, line: int) -> CoreParser.Statement:
	var error_token = CoreParser.Token.new(CoreParser.TokenType.UNKNOWN, msg, line)
	return CoreParser.Statement.new(CoreParser.StatementType.UNKNOWN, [error_token], line)
