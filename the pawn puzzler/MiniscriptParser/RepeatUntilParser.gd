class_name RepeatUntilParser
extends RefCounted

var core_parser

func _init(core):
	core_parser = core

func parse_repeat_until(statement, lines, current_line, current_indent):
	var i = current_line + 1
	var body_lines = []
	var until_found = false
	var until_condition_tokens = []
	var depth = 1  # Track nested block depth
	
	# Parse body until we find 'until'
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		if line.is_empty() or line.begins_with("#"):
			i += 1
			continue
		
		# Check for nested blocks
		var tokens = core_parser.tokenize(line, i + 1)
		if tokens.size() > 0 and tokens[0].type == CoreParser.TokenType.KEYWORD:
			match tokens[0].value:
				"repeat", "if", "while", "for", "function":
					depth += 1
				"until":
					if depth == 1:  # Only handle top-level until
						until_found = true
						until_condition_tokens = tokens.slice(1)
						i += 1
						break
		
		body_lines.append(lines[i])
		i += 1
	
	if not until_found:
		return create_error("Missing 'until' for 'repeat' statement at line " + str(statement.line), statement.line)
	
	# Parse body statements
	if body_lines.size() > 0:
		var body_code = "\n".join(body_lines)
		var nested_statements = core_parser.parse(body_code)
		if nested_statements.size() > 0 and nested_statements[0].type == CoreParser.StatementType.UNKNOWN:
			return nested_statements[0]  # Return parse error if any
		statement.body_statements = nested_statements
	
	statement.condition_tokens = until_condition_tokens
	statement.line_advance = i - current_line
	
	# Add until condition validation (deepseek)
	if statement.condition_tokens.is_empty():
		return create_error("Until condition cannot be empty", statement.line)
	
	return statement

func create_error(msg, line):
	var error_token = CoreParser.Token.new(CoreParser.TokenType.UNKNOWN, msg, line)
	return CoreParser.Statement.new(CoreParser.StatementType.UNKNOWN, [error_token], line)
