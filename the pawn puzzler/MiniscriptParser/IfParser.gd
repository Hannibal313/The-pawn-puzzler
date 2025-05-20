class_name IfParser
extends RefCounted

var core_parser

func _init(core):
	core_parser = core

func parse_if(statement, lines, current_line, current_indent):
	statement.condition_tokens = statement.tokens.slice(1)
	var i = current_line + 1
	var if_body_lines = []
	var end_found = false
	var depth = 1
	
	# Parse if body
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		if line.is_empty() or line.begins_with("#"):
			i += 1
			continue
		
		var tokens = core_parser.tokenize(line, i + 1)
		if tokens.size() > 0 and tokens[0].type == CoreParser.TokenType.KEYWORD:
			match tokens[0].value:
				"if", "while", "for", "function", "repeat":
					depth += 1
				"end":
					depth -= 1
					if depth == 0:
						end_found = true
						i += 1
						break
				"elif", "else":
					if depth == 1:
						break
		
		if_body_lines.append(lines[i])
		i += 1
	
	if if_body_lines.size() > 0:
		var if_body_code = "\n".join(if_body_lines)
		var nested_statements = core_parser.parse(if_body_code)
		if nested_statements.size() > 0 and nested_statements[0].type == CoreParser.StatementType.UNKNOWN:
			return nested_statements[0]
		statement.if_body_statements = nested_statements
	
	# Parse elif/else blocks
	while i < lines.size():
		var line = lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			i += 1
			continue
		
		var tokens = core_parser.tokenize(line, i + 1)
		if tokens.size() == 0:
			i += 1
			continue
		
		if tokens[0].type == CoreParser.TokenType.KEYWORD:
			if tokens[0].value == "elif":
				var elif_statement = CoreParser.Statement.new(CoreParser.StatementType.IF_STATEMENT, tokens, i + 1)
				elif_statement.condition_tokens = tokens.slice(1)
				
				# Parse elif body
				i += 1
				var elif_body_lines = []
				var elif_depth = 1
				
				while i < lines.size():
					var elif_line = lines[i].strip_edges()
					
					if elif_line.is_empty() or elif_line.begins_with("#"):
						i += 1
						continue
					
					var elif_tokens = core_parser.tokenize(elif_line, i + 1)
					if elif_tokens.size() > 0 and elif_tokens[0].type == CoreParser.TokenType.KEYWORD:
						match elif_tokens[0].value:
							"if", "while", "for", "function", "repeat":
								elif_depth += 1
							"end":
								elif_depth -= 1
								if elif_depth == 0:
									i += 1
									break
							"elif", "else":
								if elif_depth == 1:
									break
					
					elif_body_lines.append(lines[i])
					i += 1
				
				if elif_body_lines.size() > 0:
					var elif_body_code = "\n".join(elif_body_lines)
					var elif_nested_statements = core_parser.parse(elif_body_code)
					if elif_nested_statements.size() > 0 and elif_nested_statements[0].type == CoreParser.StatementType.UNKNOWN:
						return elif_nested_statements[0]
					elif_statement.if_body_statements = elif_nested_statements
				
				statement.else_body_statements.append(elif_statement)
			
			elif tokens[0].value == "else":
				# Parse else body
				i += 1
				var else_body_lines = []
				var else_depth = 1
				
				while i < lines.size():
					var else_line = lines[i].strip_edges()
					
					if else_line.is_empty() or else_line.begins_with("#"):
						i += 1
						continue
					
					var else_tokens = core_parser.tokenize(else_line, i + 1)
					if else_tokens.size() > 0 and else_tokens[0].type == CoreParser.TokenType.KEYWORD:
						match else_tokens[0].value:
							"if", "while", "for", "function", "repeat":
								else_depth += 1
							"end":
								else_depth -= 1
								if else_depth == 0:
									i += 1
									break
					
					else_body_lines.append(lines[i])
					i += 1
				
				if else_body_lines.size() > 0:
					var else_body_code = "\n".join(else_body_lines)
					var else_nested_statements = core_parser.parse(else_body_code)
					if else_nested_statements.size() > 0 and else_nested_statements[0].type == CoreParser.StatementType.UNKNOWN:
						return else_nested_statements[0]
					
					# Create an else statement with empty condition
					var else_statement = CoreParser.Statement.new(CoreParser.StatementType.IF_STATEMENT, [], i + 1)
					else_statement.if_body_statements = else_nested_statements
					statement.else_body_statements.append(else_statement)
				
				break
			else:
				break
		else:
			break
	
	statement.line_advance = i - current_line
	return statement

func create_error(msg, line):
	var error_token = CoreParser.Token.new(CoreParser.TokenType.UNKNOWN, msg, line)
	return CoreParser.Statement.new(CoreParser.StatementType.UNKNOWN, [error_token], line)
