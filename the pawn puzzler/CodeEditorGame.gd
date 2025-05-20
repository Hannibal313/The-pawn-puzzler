class_name CodeEditorGame
extends Control

var highlighted_lines := []
var code_editor: CodeEdit
var output_panel: RichTextLabel
var play_button: Button
var stop_button: Button
var open_blocks = []
var code_runner = CodeRunner.new()

func _ready():
	# Connect code runner signals
	code_runner.standard_output.connect(_on_code_output)
	code_runner.error_output.connect(_on_code_error)
	code_runner.execution_completed.connect(_on_execution_completed)
	code_runner.execution_stopped.connect(_on_execution_stopped)
	
	# Create the main UI layout
	create_layout()
	setup_syntax_highlighting()
	
	play_button.pressed.connect(on_play_pressed)
	stop_button.pressed.connect(on_stop_pressed)
	code_editor.text_changed.connect(_on_code_changed)
	
	# Set default code example
	code_editor.text = """# Welcome to MiniScript!
function factorial(n):
	if n <= 1
		return 1
	end
	return n * factorial(n - 1)
end
print(factorial(5))
"""

func setup_syntax_highlighting():
	var highlighter = CodeHighlighter.new()
	
	# Set colors for different syntax elements
	highlighter.add_color_region('"', '"', Color("#F1FA8C"), false)
	highlighter.add_color_region("'", "'", Color("#F1FA8C"), false)
	highlighter.add_color_region("#", "", Color("#6272A4"), true)
	
	# Numbers
	highlighter.number_color = Color("#FF79C6")
	
	# Symbols
	highlighter.symbol_color = Color("#BD93F9")
	
	# Functions
	highlighter.function_color = Color("#50FA7B")
	
	# Member variables
	highlighter.member_variable_color = Color("#8BE9FD")
	
	# Block highlight
	highlighter.set("theme_override_colors/block_highlight_color", Color("#3A4D5A"))

	# Keywords
	var keywords = [
		"if", "else", "elif", "for", "while", 
		"function", "return", "break", "continue", 
		"print", "var", "const", "pass", "end", "and", "or", "repeat", "until"
	]
	
	for keyword in keywords:
		if keyword == "print":
			highlighter.add_keyword_color(keyword, Color("#50FA7B"))
		else:
			highlighter.add_keyword_color(keyword, Color("#FF79C6"))
	
	code_editor.syntax_highlighter = highlighter

func update_block_highlights():
	for line in range(code_editor.get_line_count()):
		code_editor.set_line_background_color(line, Color.TRANSPARENT)
	
	for block in open_blocks:
		var highlight_color := Color("#3A5D7A")
		highlight_color.a = 0.4
		code_editor.set_line_background_color(block.line, highlight_color)
	
	highlighted_lines = []
	for block in open_blocks:
		highlighted_lines.append(block.line)
	
	code_editor.queue_redraw()

func parse_blocks():
	open_blocks.clear()
	var block_stack = []
	
	for line_num in range(code_editor.get_line_count()):
		var line = code_editor.get_line(line_num).strip_edges()
		
		if line.begins_with("if ") or line.begins_with("while ") or \
		   line.begins_with("for ") or line.begins_with("function "):
			block_stack.push_back({"line": line_num, "text": line})
		elif line == "end" or line.ends_with(" end"):
			if block_stack.size() > 0:
				block_stack.pop_back()
	
	open_blocks = block_stack.duplicate()
	update_block_highlights()

func _on_code_changed():
	parse_blocks()
	
func create_layout():
	for child in get_children():
		child.queue_free()
	
	size = get_viewport().get_visible_rect().size
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	var main_split = HSplitContainer.new()
	main_split.name = "MainSplit"
	main_split.anchor_right = 1.0
	main_split.anchor_bottom = 1.0
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_split)
	
	main_split.collapsed = false
	main_split.add_theme_constant_override("separation", 0.01)
	main_split.add_theme_constant_override("autohide", 0)

	var line_style = StyleBoxFlat.new()
	line_style.bg_color = Color("#8B8000")
	line_style.content_margin_left = 0
	line_style.content_margin_right = 0
	line_style.content_margin_top = 0
	line_style.content_margin_bottom = 0
	main_split.add_theme_stylebox_override("grabber", line_style)
	
	var left_panel = VBoxContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.add_child(left_panel)
	
	code_editor = CodeEdit.new()
	code_editor.name = "CodeEditor"
	code_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_editor.size_flags_stretch_ratio = 0.70
	left_panel.add_child(code_editor)
	
	code_editor.syntax_highlighter = CodeHighlighter.new()
	code_editor.gutters_draw_line_numbers = true
	code_editor.auto_brace_completion_enabled = true
	code_editor.set_indent_size(4)
	code_editor.set_line_folding_enabled(true)
	code_editor.set_draw_executing_lines_gutter(true)
	code_editor.set_draw_tabs(true)
	code_editor.add_theme_color_override("font_color_readonly", Color.RED)
	code_editor.code_completion_prefixes = ["var", "print", "if", "else", "while"]
	code_editor.set_code_completion_enabled(true)
	
	var code_edit_style = StyleBoxFlat.new()
	code_edit_style.bg_color = Color.WHITE
	code_editor.add_theme_stylebox_override("normal", code_edit_style)
	code_editor.add_theme_color_override("background_color", Color("#050519"))
	code_editor.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	
	var output_container = PanelContainer.new()
	output_container.name = "OutputContainer"
	output_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_container.size_flags_stretch_ratio = 0.25
	left_panel.add_child(output_container)
	
	var output_border_style = StyleBoxFlat.new()
	output_border_style.bg_color = Color("#050519")
	output_border_style.border_color = Color("#78640A")
	output_border_style.border_width_left = 1
	output_border_style.border_width_right = 1
	output_border_style.border_width_top = 1
	output_border_style.border_width_bottom = 1
	output_container.add_theme_stylebox_override("panel", output_border_style)
	
	var output_scroll = ScrollContainer.new()
	output_scroll.name = "OutputScroll"
	output_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_container.add_child(output_scroll)
	
	output_panel = RichTextLabel.new()
	output_panel.selection_enabled = true
	output_panel.name = "OutputPanel"
	output_panel.bbcode_enabled = true
	output_panel.scroll_following = true
	output_panel.autowrap_mode = TextServer.AUTOWRAP_WORD
	output_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_panel.text = "Output will appear here..."
	output_scroll.add_child(output_panel)
	
	var button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.size_flags_stretch_ratio = 0.05
	button_container.custom_minimum_size.y = 40
	left_panel.add_child(button_container)
	
	play_button = Button.new()
	play_button.text = "Play"
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(play_button)
	
	stop_button = Button.new()
	stop_button.text = "Stop"
	stop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(stop_button)
	
	var right_panel = PanelContainer.new()
	right_panel.name = "RightPanel"
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.add_child(right_panel)
	
	var right_panel_style = StyleBoxFlat.new()
	right_panel_style.bg_color = Color("#050519")
	right_panel.add_theme_stylebox_override("panel", right_panel_style)
	
	left_panel.add_theme_constant_override("separation", 0)
	get_viewport().size_changed.connect(Callable(self, "_on_viewport_resized"))

func _on_viewport_resized():
	var viewport_size = get_viewport().get_visible_rect().size
	if has_node("MainSplit"):
		var split = get_node("MainSplit")
		split.size = viewport_size
		split.split_offset = 0

func on_play_pressed():
	if code_runner.is_running:
		return
	
	play_button.disabled = true
	stop_button.disabled = false
	
	output_panel.clear()
	code_runner.reset()
	
	var code = code_editor.text
	await code_runner.execute(code)

func on_stop_pressed():
	if not code_runner.is_running:
		return
	
	code_runner.stop_execution()

func _on_code_output(text: String):
	output_panel.append_text(text + "\n")

func _on_code_error(text: String):
	output_panel.append_text("[color=red]" + text + "[/color]\n")

func _on_execution_completed():
	play_button.disabled = false
	stop_button.disabled = true

func _on_execution_stopped():
	play_button.disabled = false
	stop_button.disabled = true
	output_panel.append_text("\n[color=yellow]Execution stopped by user.[/color]")
