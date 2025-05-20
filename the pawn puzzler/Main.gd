extends Node2D

func _ready():
	var code_editor_game = CodeEditorGame.new()
	add_child(code_editor_game)
