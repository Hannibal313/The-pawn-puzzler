# Replace the entire ExpressionParser.gd content with:
class_name ExpressionParser
extends RefCounted

var core_parser

func _init(core):
	core_parser = core

func parse_expression(statement: CoreParser.Statement) -> CoreParser.Statement:
	var tokens = statement.tokens
	
	# Handle list literals
	if tokens.size() > 0 and tokens[0].type == CoreParser.TokenType.PARENTHESIS_OPEN and tokens[0].value == "[":
		return parse_list_literal(statement)
	
	# Handle dict literals
	if tokens.size() > 0 and tokens[0].type == CoreParser.TokenType.PARENTHESIS_OPEN and tokens[0].value == "{":
		return parse_dict_literal(statement)
	
	return statement

func parse_list_literal(statement: CoreParser.Statement) -> CoreParser.Statement:
	var elements = []
	var tokens = statement.tokens
	var i = 1  # Skip opening '['
	
	while i < tokens.size() and tokens[i].value != "]":
		# Parse each element (including nested structures)
		var element_tokens = []
		var brace_count = 0
		while i < tokens.size():
			var token = tokens[i]
			if token.value in ["{", "["]:
				brace_count += 1
			elif token.value in ["}", "]"]:
				if brace_count > 0:
					brace_count -= 1
				else:
					break
			elif token.value == "," and brace_count == 0:
				break
				
			element_tokens.append(token)
			i += 1
		
		if not element_tokens.is_empty():
			elements.append(parse_expression(CoreParser.Statement.new(
				CoreParser.StatementType.EXPRESSION,
				element_tokens,
				statement.line
			)))
		
		if i < tokens.size() and tokens[i].value == ",":
			i += 1  # Skip comma
	
	statement.tokens = []
	statement.type = CoreParser.StatementType.LIST_LITERAL
	statement.elements = elements
	return statement

func parse_dict_literal(statement: CoreParser.Statement) -> CoreParser.Statement:
	var pairs = []
	var tokens = statement.tokens
	var i = 1  # Skip opening '{'
	
	while i < tokens.size() and tokens[i].value != "}":
		# Parse key
		var key_tokens = []
		while i < tokens.size() and tokens[i].value not in [":", ",", "}"]:
			key_tokens.append(tokens[i])
			i += 1
		
		if i >= tokens.size() or tokens[i].value != ":":
			statement.type = CoreParser.StatementType.UNKNOWN
			statement.tokens = [CoreParser.Token.new(
				CoreParser.TokenType.UNKNOWN, 
				"Expected ':' in dictionary literal", 
				statement.line
			)]
			return statement
		
		i += 1  # Skip ':'
		
		# Parse value
		var value_tokens = []
		while i < tokens.size() and tokens[i].value not in [",", "}"]:
			value_tokens.append(tokens[i])
			i += 1
		
		if not key_tokens.is_empty() and not value_tokens.is_empty():
			pairs.append({
				"key": CoreParser.Statement.new(CoreParser.StatementType.EXPRESSION, key_tokens, statement.line),
				"value": CoreParser.Statement.new(CoreParser.StatementType.EXPRESSION, value_tokens, statement.line)
			})
		
		if i < tokens.size() and tokens[i].value == ",":
			i += 1  # Skip comma
	
	# Create new statement with the parsed data
	var new_statement = CoreParser.Statement.new(
		CoreParser.StatementType.DICT_LITERAL,
		[],  # Clear original tokens
		statement.line
	)
	new_statement.set_meta("dict_pairs", pairs)
	return new_statement
