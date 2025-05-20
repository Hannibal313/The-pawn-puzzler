class_name WhileParser
extends RefCounted

var core_parser

func _init(core):
	core_parser = core

func parse_while(statement, lines, current_line, current_indent):
	statement.condition_tokens = statement.tokens.slice(1)
	var i = current_line + 1
	var body_lines = []
	var end_line = -1
	var depth = 1  # Track nested block depth
	
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		if line.is_empty() or line.begins_with("#"):
			i += 1
			continue
		
		# Check for nested blocks
		var tokens = core_parser.tokenize(line, i + 1)
		if tokens.size() > 0 and tokens[0].type == CoreParser.TokenType.KEYWORD:
			match tokens[0].value:
				"while", "if", "for", "function":
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
		return create_error("Missing 'end' for 'while' statement at line " + str(statement.line), statement.line)
	
	# Parse body statements
	if body_lines.size() > 0:
		var body_code = "\n".join(body_lines)
		var nested_statements = core_parser.parse(body_code)
		if nested_statements.size() > 0 and nested_statements[0].type == CoreParser.StatementType.UNKNOWN:
			return nested_statements[0]  # Return parse error if any
		statement.body_statements = nested_statements
	
	statement.line_advance = i - current_line
	
	# Add condition validation
	if statement.condition_tokens.is_empty():
		return create_error("While condition cannot be empty", statement.line)
	
	# Check for obviously non-boolean conditions
	var first_token = statement.condition_tokens[0]
	if statement.condition_tokens.size() == 1:
		match first_token.type:
			CoreParser.TokenType.NUMBER:
				return create_error("Numeric condition without comparison", statement.line)
			CoreParser.TokenType.STRING:
				return create_error("String condition without comparison", statement.line)
	
	return statement

func create_error(msg, line):
	var error_token = CoreParser.Token.new(CoreParser.TokenType.UNKNOWN, msg, line)
	return CoreParser.Statement.new(CoreParser.StatementType.UNKNOWN, [error_token], line)
