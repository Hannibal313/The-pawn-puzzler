class_name VariableParser
extends RefCounted

var core_parser

func _init(core):
	core_parser = core

func parse_variable_declaration(statement: CoreParser.Statement) -> CoreParser.Statement:
	var tokens = statement.tokens
	if tokens.size() < 4 or tokens[0].value != "var" or tokens[1].type != CoreParser.TokenType.IDENTIFIER or tokens[2].type != CoreParser.TokenType.EQUALS:
		var error_token = CoreParser.Token.new(CoreParser.TokenType.UNKNOWN, 
			"Invalid variable declaration at line " + str(statement.line), statement.line)
		return CoreParser.Statement.new(CoreParser.StatementType.UNKNOWN, [error_token], statement.line)
	
	return statement

func parse_variable_assignment(statement: CoreParser.Statement) -> CoreParser.Statement:
	var tokens = statement.tokens
	if tokens.size() < 3 or tokens[0].type != CoreParser.TokenType.IDENTIFIER:
		var error_token = CoreParser.Token.new(CoreParser.TokenType.UNKNOWN, 
			"Invalid variable assignment at line " + str(statement.line), statement.line)
		return CoreParser.Statement.new(CoreParser.StatementType.UNKNOWN, [error_token], statement.line)
	
	return statement
