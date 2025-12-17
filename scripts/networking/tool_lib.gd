extends Node


#################################################[ TIMERS ]#################################################

func create_delay(target_node: Variant, delay: float, function: Callable) -> void:
	if delay < 0.001:
		function.call()
		return
	else:
		var tmr = Timer.new()
		tmr.autostart = true
		tmr.one_shot = true
		tmr.wait_time = delay
		tmr.connect("timeout", 
			func() -> void:
				function.call()
				target_node.remove_child(tmr)
		)
		target_node.call_deferred("add_child", tmr)

func create_timer(target_node: Variant, delay: float, function: Callable) -> Timer:
	var tmr = Timer.new()
	tmr.wait_time = delay
	tmr.connect("timeout", function)
	target_node.call_deferred("add_child", tmr)
	return tmr
func create_timer_autostart(target_node: Variant, delay: float, function: Callable) -> Timer:
	var tmr = create_timer(target_node, delay, function)
	tmr.autostart = true
	return tmr
func create_timer_autostop(target_node: Variant, delay: float, function: Callable) -> Timer:
	var tmr = create_timer(target_node, delay, function)
	tmr.one_shot = true
	return tmr
func create_timer_autostartstop(target_node: Variant, delay: float, function: Callable) -> Timer:
	var tmr = create_timer_autostart(target_node, delay, function)
	tmr.one_shot = true
	return tmr

#################################################[ NUMBERS ]#################################################

func round_decimal(value: float, decimal_places: int) -> float:
	var factor = pow(10, decimal_places)
	return round(value * factor) / factor
