class_name UI
extends Control


signal server_started(port: int)
signal client_started(port: int, ip: String)
signal enterd_title_screen
signal leave_to_title_screen


func _ready() -> void:
	_to_title()
	
	GameData.set_ui_link(self)
	multiplayer.connection_failed.connect(func()->void:_to_title())
	multiplayer.connected_to_server.connect(func()->void:_on_server_connect())
	multiplayer.server_disconnected.connect(func()->void:_to_title())
	
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and DisplayServer.window_is_focused():
		if !$title.visible:
			$ingame_menu.visible = !$ingame_menu.visible
			GameData.capture_mouse(!$ingame_menu.visible)
			$ingame_ui.visible = !$ingame_menu.visible

func update_ammo_label(current_ammo: String) -> void:
	$ingame_ui/ammo.text = current_ammo

func _on_server_connect() -> void:
	_off()
	$ingame_ui.visible = true

func _title_menu_title_host_pressed() -> void:
	$title/main_menu/title_screen.visible = false
	$title/main_menu/host_screen.visible = true
func _title_menu_title_join_pressed() -> void:
	$title/main_menu/title_screen.visible = false
	$title/main_menu/join_screen.visible = true

func _title_menu_host_host_pressed() -> void:
	_off()
	server_started.emit(int($title/main_menu/host_screen/buttons/port.text))
	$ingame_ui.visible = true
func _title_menu_host_back_pressed() -> void:
	$title/main_menu/host_screen.visible = false
	$title/main_menu/title_screen.visible = true
	
func _title_menu_join_join_pressed() -> void:
	$title/main_menu/join_screen.visible = false
	client_started.emit(int($title/main_menu/join_screen/buttons/port.text), $title/main_menu/join_screen/buttons/ip.text)
	$title/main_menu/waiting_screen.visible = true
	
func _title_menu_join_back_pressed() -> void:
	$title/main_menu/join_screen.visible = false
	$title/main_menu/title_screen.visible = true

func _title_menu_waiting_back_pressed() -> void:
	$title/main_menu/waiting_screen.visible = false
	$title/main_menu/join_screen.visible = true
func _title_menu_waiting_timeout() -> void:
	if len($title/main_menu/waiting_screen/buttons/TextField.text) < 3:
		$title/main_menu/waiting_screen/buttons/TextField.text += "."
	else:
		$title/main_menu/waiting_screen/buttons/TextField.text = ""
func  _title_menu_waiting_visibility_changed() -> void:
	if $title/main_menu/waiting_screen.visible:
		$title/main_menu/waiting_screen/buttons/TextField.text = ""
		$title/main_menu/waiting_screen/display_timer.start()
	else:
		$title/main_menu/waiting_screen/display_timer.stop()

func _on_leave_button_pressed() -> void:
	leave_to_title_screen.emit()
	_to_title()

func _off() -> void:
	$title.visible = false
	$title/main_menu.visible = false
	$title/main_menu/title_screen.visible = false
	$title/main_menu/host_screen.visible = false
	$title/main_menu/join_screen.visible = false
	$title/main_menu/waiting_screen.visible = false
	$ingame_menu.visible = false
	$ingame_ui.visible = false
func _to_title() -> void:
	_off()
	$title.visible = true
	$title/main_menu.visible = true
	$title/main_menu/title_screen.visible = true
	enterd_title_screen.emit()
