class_name CoreParser
extends RefCounted

enum TokenType {
	NUMBER,
	STRING,
	IDENTIFIER,
	OPERATOR,
	KEYWORD,
	PARENTHESIS_OPEN,
	PARENTHESIS_CLOSE,
	EQUALS,
	SEMICOLON,
	COMMA,
	COLON,
	RETURN_KEYWORD,
	PASS_KEYWORD,
	BREAK_KEYWORD,
	CONTINUE_KEYWORD,
	UNKNOWN
}

enum StatementType {
	VARIABLE_DECLARATION,
	VARIABLE_ASSIGNMENT,
	PRINT_STATEMENT,
	EXPRESSION,
	WHILE_LOOP,
	IF_STATEMENT,
	FOR_LOOP,
	FUNCTION_DECLARATION,
	RETURN_STATEMENT,
	PASS_STATEMENT,
	BREAK_STATEMENT,
	CONTINUE_STATEMENT,
	REPEAT_UNTIL_LOOP,
	LIST_LITERAL,
	DICT_LITERAL,
	UNKNOWN
}

class Token:
	var type: int
	var value: String
	var line: int
	
	var is_function_call: bool = false
	var func_tokens: Array = []
	
	func _init(p_type: int, p_value: String, p_line: int):
		type = p_type
		value = p_value
		line = p_line
	func _to_string() -> String:
		return "Token(" + str(type) + ", '" + value + "', line " + str(line) + ")"

class Statement:
	var type: int
	var tokens: Array
	var line: int
	var condition_tokens: Array
	var body_statements: Array
	var if_body_statements: Array
	var else_body_statements: Array
	var for_variable: String
	var for_start_tokens: Array
	var for_end_tokens: Array
	var for_step_tokens: Array
	var line_advance: int = 1
	func _init(p_type: int, p_tokens: Array, p_line: int):
		type = p_type
		tokens = p_tokens
		line = p_line
		condition_tokens = []
		body_statements = []
		if_body_statements = []
		else_body_statements = []
		for_start_tokens = []
		for_end_tokens = []
		for_step_tokens = []

var keywords = ["var", "print", "if", "else", "elif", "while", "for", "function", "return", "pass", "break", "continue", "end", "and", "or", "not", "repeat", "until"]

var if_parser: IfParser
var while_parser: WhileParser
var for_parser: ForParser
var function_parser: FunctionParser
var expression_parser: ExpressionParser
var variable_parser: VariableParser
var repeat_parser: RepeatUntilParser

func _init():
	if_parser = IfParser.new(self)
	while_parser = WhileParser.new(self)
	for_parser = ForParser.new(self)
	function_parser = FunctionParser.new(self)
	expression_parser = ExpressionParser.new(self)
	variable_parser = VariableParser.new(self)
	repeat_parser = RepeatUntilParser.new(self)
	
func parse(code: String) -> Array:
	var statements = []
	var lines = code.split("\n", false)  # Keep empty lines
	
	# First perform validation of blocks
	var validation_result = validate_indentation_and_blocks(lines)
	if validation_result != "":
		# Create an error statement with the validation message
		var error_token = Token.new(TokenType.UNKNOWN, validation_result, 1)
		return [Statement.new(StatementType.UNKNOWN, [error_token], 1)]
	
	var i = 0
	while i < lines.size():
		var raw_line = lines[i]
		var line = raw_line.strip_edges()
		
		if line.is_empty() or line.begins_with("#"):
			i += 1
			continue
			
		var tokens = tokenize(line, i + 1)
		if tokens.is_empty():
			i += 1
			continue
			
		var statement_type = determine_statement_type(tokens)
		var statement = Statement.new(statement_type, tokens, i + 1)
		
		match statement_type:
			StatementType.IF_STATEMENT:
				statement = if_parser.parse_if(statement, lines, i, 0)
			StatementType.WHILE_LOOP:
				statement = while_parser.parse_while(statement, lines, i, 0)
			StatementType.FOR_LOOP:
				statement = for_parser.parse_for(statement, lines, i, 0)
			StatementType.FUNCTION_DECLARATION:
				statement = function_parser.parse_function(statement, lines, i, 0)
			StatementType.VARIABLE_DECLARATION:
				statement = variable_parser.parse_variable_declaration(statement)
			StatementType.VARIABLE_ASSIGNMENT:
				statement = variable_parser.parse_variable_assignment(statement)
			StatementType.EXPRESSION:
				statement = expression_parser.parse_expression(statement)
			StatementType.REPEAT_UNTIL_LOOP:
				statement = repeat_parser.parse_repeat_until(statement, lines, i, 0)
		
		if statement.type == StatementType.UNKNOWN:
			# Improve error message
			if statement.tokens.size() > 0:
				var error_msg = "Syntax error at line %d: %s" % [statement.line, statement.tokens[0].value]
				statement.tokens[0].value = error_msg
			return [statement]
			
		statements.append(statement)
		i += statement.line_advance
	
	return statements

func validate_indentation_and_blocks(lines: Array) -> String:
	var block_stack = []
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
			
		var tokens = tokenize(line, i + 1)
		if tokens.is_empty():
			continue
			
		# Handle block-starting keywords
		if tokens.size() > 0 and tokens[0].type == TokenType.KEYWORD:
			match tokens[0].value:
				"if", "while", "for", "function", "repeat":
					block_stack.push_back({
						"type": tokens[0].value,
						"line": i + 1
					})
				"else", "elif":
					if block_stack.is_empty() or block_stack.back().type != "if":
						return "Line %d: '%s' without matching 'if'" % [i + 1, tokens[0].value]
				"end":
					if block_stack.is_empty():
						return "Line %d: 'end' without matching block" % [i + 1]
					block_stack.pop_back()
	
	# Check for unclosed blocks
	if not block_stack.is_empty():
		var block = block_stack.back()
		return "Missing 'end' for %s block starting at line %d" % [block.type, block.line]
	
	return ""  # Validation passed

func determine_statement_type(tokens: Array) -> int:
	for token in tokens:
		pass
	
	if tokens.size() == 0:
		return StatementType.EXPRESSION
	
	var first_token = tokens[0]
	
	# Handle all keyword-based statements first
	if first_token.type == TokenType.KEYWORD:
		match first_token.value:
			"var":
				return StatementType.VARIABLE_DECLARATION
			"print":
				return StatementType.PRINT_STATEMENT
			"while":
				return StatementType.WHILE_LOOP
			"if":
				return StatementType.IF_STATEMENT
			"for":
				return StatementType.FOR_LOOP
			"function":
				return StatementType.FUNCTION_DECLARATION
			"return":
				return StatementType.RETURN_STATEMENT
			"pass":
				return StatementType.PASS_STATEMENT
			"break":
				return StatementType.BREAK_STATEMENT
			"continue":
				return StatementType.CONTINUE_STATEMENT
			"repeat":
				return StatementType.REPEAT_UNTIL_LOOP
	
	# Handle variable assignments (including compound assignments)
	if tokens.size() > 1 and first_token.type == TokenType.IDENTIFIER:
		var second_token = tokens[1]
		
		# List of all valid assignment operators
		var assignment_operators = ["=", "+=", "-=", "*=", "/=", "%="]
		
		if (second_token.type == TokenType.EQUALS) or \
		   (second_token.type == TokenType.OPERATOR and assignment_operators.has(second_token.value)):
			
			return StatementType.VARIABLE_ASSIGNMENT
	
	# Handle function calls and other expressions
	if first_token.type == TokenType.IDENTIFIER:
		
		return StatementType.EXPRESSION
	
	
	return StatementType.EXPRESSION

# Fix for the tokenize function in CoreParser.gd
func tokenize(line: String, line_num: int) -> Array:
	var tokens = []
	var i = 0
	while i < line.length():
		var char = line[i]
		if char == " " or char == "\t":
			i += 1
			continue
		if char == "#":
			break
			
		if char in ["+", "-", "*", "/", "%"] and i + 1 < line.length() and line[i+1] == "=":
			tokens.append(Token.new(TokenType.OPERATOR, char + "=", line_num))
			i += 2
			continue
		if char.is_valid_int() or (char == "-" and i + 1 < line.length() and line[i + 1].is_valid_int()):
			var start = i
			if char == "-":
				i += 1
			while i < line.length() and (line[i].is_valid_int() or line[i] == "."):
				i += 1
			var number_str = line.substr(start, i - start)
			tokens.append(Token.new(CoreParser.TokenType.NUMBER, number_str, line_num))
			continue
		if char == "\"" or char == "'":
			var quote_type = char
			var start = i
			i += 1
			var in_escape = false
			while i < line.length():
				if in_escape:
					in_escape = false
					i += 1
				elif line[i] == "\\":
					in_escape = true
					i += 1
				elif line[i] == quote_type:
					break
				else:
					i += 1
			if i < line.length():
				i += 1
				var string_value = line.substr(start, i - start)
				tokens.append(Token.new(CoreParser.TokenType.STRING, string_value, line_num))
			else:
				tokens.append(Token.new(CoreParser.TokenType.UNKNOWN, line.substr(start), line_num))
			continue
		
		# Check for 'and' and 'or' keywords first
		if i + 3 <= line.length() and line.substr(i, 3) == "and":
			# Verify it's a standalone keyword
			var before_ok = i == 0 or not line[i-1].is_valid_identifier()
			var after_ok = i + 3 >= line.length() or not line[i+3].is_valid_identifier()
			if before_ok and after_ok:
				tokens.append(Token.new(TokenType.OPERATOR, "and", line_num))
				i += 3
				continue
		elif i + 2 <= line.length() and line.substr(i, 2) == "or":
			# Verify it's a standalone keyword
			var before_ok = i == 0 or not line[i-1].is_valid_identifier()
			var after_ok = i + 2 >= line.length() or not line[i+2].is_valid_identifier()
			if before_ok and after_ok:
				tokens.append(Token.new(TokenType.OPERATOR, "or", line_num))
				i += 2
				continue
		
		elif i + 3 <= line.length() and line.substr(i, 3) == "not":
			# Verify it's a standalone keyword
			var before_ok = i == 0 or not line[i-1].is_valid_identifier()
			var after_ok = i + 3 >= line.length() or not line[i+3].is_valid_identifier()
			if before_ok and after_ok:
				tokens.append(Token.new(TokenType.OPERATOR, "not", line_num))
				i += 3
				continue
		
		if char.is_valid_identifier():
			var start = i
			while i < line.length() and (line[i].is_valid_identifier() or line[i].is_valid_int()):
				i += 1
			var identifier = line.substr(start, i - start)
			if keywords.has(identifier):
				tokens.append(Token.new(CoreParser.TokenType.KEYWORD, identifier, line_num))
			else:
				tokens.append(Token.new(CoreParser.TokenType.IDENTIFIER, identifier, line_num))
			continue
			
		if (char == "&" and i + 1 < line.length() and line[i + 1] == "&") or \
			 (char == "|" and i + 1 < line.length() and line[i + 1] == "|"):
			var op = line.substr(i, 2)
			tokens.append(Token.new(TokenType.OPERATOR, op, line_num))
			i += 2
			continue
		if char == "!" and (i + 1 >= line.length() or line[i + 1] != "="):
			tokens.append(Token.new(CoreParser.TokenType.OPERATOR, char, line_num))
			i += 1
			continue
		if char in ["+", "-", "*", "/", "%"]:
			tokens.append(Token.new(CoreParser.TokenType.OPERATOR, char, line_num))
			i += 1
			continue
		if char in ["=", "!", "<", ">"]:
			var op = char
			if i + 1 < line.length():
				if char in ["=", "!", "<", ">"] and line[i + 1] == "=":
					op += "="
					i += 1
				elif char == "<" and line[i + 1] == "=":
					op += "="
					i += 1
				elif char == ">" and line[i + 1] == "=":
					op += "="
					i += 1
			if op == "=":
				tokens.append(Token.new(CoreParser.TokenType.EQUALS, op, line_num))
			else:
				tokens.append(Token.new(CoreParser.TokenType.OPERATOR, op, line_num))
			i += 1
			continue
			
		if char in ["+", "-"] and i + 1 < line.length() and line[i + 1] == "=":
			tokens.append(Token.new(CoreParser.TokenType.OPERATOR, char + "=", line_num))
			i += 2
			continue
			
		if char == "(":
			tokens.append(Token.new(CoreParser.TokenType.PARENTHESIS_OPEN, char, line_num))
			i += 1
			continue
		if char == ")":
			tokens.append(Token.new(CoreParser.TokenType.PARENTHESIS_CLOSE, char, line_num))
			i += 1
			continue
		if char == ";":
			tokens.append(Token.new(CoreParser.TokenType.SEMICOLON, char, line_num))
			i += 1
			continue
		if char == ",":
			tokens.append(Token.new(CoreParser.TokenType.COMMA, char, line_num))
			i += 1
			continue
		if char == ":":
			tokens.append(Token.new(TokenType.COLON, char, line_num))
			i += 1
			continue
		if char == "[":
			tokens.append(Token.new(TokenType.PARENTHESIS_OPEN, char, line_num))
			i += 1
			continue
		if char == "]":
			tokens.append(Token.new(TokenType.PARENTHESIS_CLOSE, char, line_num))
			i += 1
			continue
		if char == "{":
			tokens.append(Token.new(TokenType.PARENTHESIS_OPEN, char, line_num))
			i += 1
			continue
		if char == "}":
			tokens.append(Token.new(TokenType.PARENTHESIS_CLOSE, char, line_num))
			i += 1
			continue
		tokens.append(Token.new(CoreParser.TokenType.UNKNOWN, char, line_num))
		i += 1
	return tokens

func statement_type_to_string(type: int) -> String:
	match type:
		StatementType.VARIABLE_DECLARATION:
			return "VARIABLE_DECLARATION"
		StatementType.VARIABLE_ASSIGNMENT:
			return "VARIABLE_ASSIGNMENT"
		StatementType.PRINT_STATEMENT:
			return "PRINT_STATEMENT"
		StatementType.EXPRESSION:
			return "EXPRESSION"
		StatementType.WHILE_LOOP:
			return "WHILE_LOOP"
		StatementType.IF_STATEMENT:
			return "IF_STATEMENT"
		StatementType.FOR_LOOP:
			return "FOR_LOOP"
		_:
			return "UNKNOWN"

func token_type_to_string(type: int) -> String:
	match type:
		TokenType.NUMBER:
			return "NUMBER"
		TokenType.STRING:
			return "STRING"
		TokenType.IDENTIFIER:
			return "IDENTIFIER"
		TokenType.OPERATOR:
			return "OPERATOR"
		TokenType.KEYWORD:
			return "KEYWORD"
		TokenType.PARENTHESIS_OPEN:
			return "PARENTHESIS_OPEN"
		TokenType.PARENTHESIS_CLOSE:
			return "PARENTHESIS_CLOSE"
		TokenType.EQUALS:
			return "EQUALS"
		TokenType.SEMICOLON:
			return "SEMICOLON"
		TokenType.COMMA:
			return "COMMA"
		_:
			return "UNKNOWN"

