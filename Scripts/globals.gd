extends Node

var current_selected_star_index = -1
var can_move: bool = true

signal find_clicked_star(pos)
signal fly_to_star()
signal change_console_visible()
