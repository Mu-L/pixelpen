@tool
extends ConfirmationDialog


signal closed


const SCALE_MAX_EXPONENT : int = 2
const SCALE_MIN_EXPONENT : int = -5
const IMPORT_SIZE_LIMIT : int = 16384
const ICON_DEFAULT_COLOR : Color = Color.GRAY
const ICON_HOVER_COLOR : Color = Color.WHITE


@export var sprite : Sprite2D
@export var scale_slider : HSlider
@export var scale_ticks : HBoxContainer
@export var scale_label : Label
@export var zoom_label : Label
@export var size_label : Label
@export var grid_button : TextureButton
@export var zoom_in_button : TextureButton
@export var zoom_out_button : TextureButton
@export var zoom_fit_button : TextureButton
@export var grid_view : Node2D

var tint_shader = load("res://addons/net.yarvis.pixel_pen/resources/tint_color.gdshader")

var _src_image : Image
var _first : bool = true
var _zoom_percent : int = -1


func _init():
	add_to_group("pixelpen_popup")


func _ready():
	ThemeConfig.upgrade_icons(self)
	grid_button.shortcut = PixelPen.state.userconfig.shorcuts.view_show_grid
	for button in [grid_button, zoom_in_button, zoom_out_button, zoom_fit_button]:
		_setup_icon_button(button)


func _setup_icon_button(button : TextureButton):
	var material := ShaderMaterial.new()
	material.shader = tint_shader
	button.material = material
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(func():
			button.material.set_shader_parameter("tint", ICON_HOVER_COLOR)
			)
	button.mouse_exited.connect(func():
			_refresh_icon_tint(button)
			)
	_refresh_icon_tint(button)


func _refresh_icon_tint(button : TextureButton):
	if button == grid_button and grid_view.show_grid:
		button.material.set_shader_parameter("tint", PixelPen.state.userconfig.accent_color)
	else:
		button.material.set_shader_parameter("tint", ICON_DEFAULT_COLOR)


func _process(_delta):
	if _first:
		grab_focus()
		_first = false
		grid_view.update_camera_zoom()
	_update_zoom_label()


func show_file(path : String):
	_src_image = Image.load_from_file(path)
	_src_image.convert(Image.FORMAT_RGBA8)
	if _src_image.is_empty():
		return
	sprite.texture = ImageTexture.create_from_image(_src_image)
	_update_slider_range()
	scale_slider.set_value_no_signal(0)
	_update_scale_label()
	update_label()


func get_image()->Image:
	return sprite.texture.get_image()


func _exponent_of(value : float) -> int:
	return -(value as int)


func _update_slider_range():
	var img_size : Vector2i = _src_image.get_size()
	var smallest : int = mini(img_size.x, img_size.y)
	var largest : int = maxi(img_size.x, img_size.y)
	var min_exponent : int = 0
	while min_exponent > SCALE_MIN_EXPONENT and (smallest >> (abs(min_exponent) + 1)) >= 1:
		min_exponent -= 1
	var max_exponent : int = 0
	while max_exponent < SCALE_MAX_EXPONENT and largest * pow(2, max_exponent + 1) <= IMPORT_SIZE_LIMIT:
		max_exponent += 1
	scale_slider.min_value = -max_exponent
	scale_slider.max_value = -min_exponent
	scale_slider.tick_count = (max_exponent - min_exponent) + 1
	scale_slider.editable = min_exponent != max_exponent
	_build_scale_ticks(max_exponent, min_exponent)


func _build_scale_ticks(max_exponent : int, min_exponent : int):
	for child in scale_ticks.get_children():
		child.queue_free()
	var total : int = (max_exponent - min_exponent) + 1
	var index : int = 0
	var exponent : int = max_exponent
	while exponent >= min_exponent:
		var tick := Label.new()
		tick.text = _scale_multiplier(exponent)
		tick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if index == 0:
			tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		elif index == total - 1:
			tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scale_ticks.add_child(tick)
		index += 1
		exponent -= 1


func _scale_multiplier(exponent : int) -> String:
	if exponent >= 0:
		return str("x", pow(2, exponent) as int)
	return str("x1/", pow(2, abs(exponent)) as int)


func _update_scale_label():
	scale_label.text = _scale_multiplier(_exponent_of(scale_slider.value))


func _update_zoom_label():
	var percent : int = grid_view.get_zoom_percent()
	if percent != _zoom_percent:
		_zoom_percent = percent
		zoom_label.text = str(percent, "%")


func _on_scale_slider_value_changed(value : float):
	if _src_image == null:
		return
	var previous_size : Vector2 = sprite.texture.get_size()
	var scale_factor : int = _exponent_of(value)
	if scale_factor == 0:
		sprite.texture = ImageTexture.create_from_image(_src_image)
	elif scale_factor > 0:
		scale_up(pow(2, scale_factor))
	else:
		scale_down(pow(2, abs(scale_factor)))
	var new_size : Vector2 = sprite.texture.get_size()
	if previous_size.x > 0:
		grid_view.rescale_view(new_size.x / previous_size.x)
	_update_scale_label()
	update_label()


func update_label():
	size_label.text = str("Size : (", _src_image.get_width(),"x",_src_image.get_height(),"px) -> (",
			sprite.texture.get_width() , "x", sprite.texture.get_height(),"px)")


func scale_up(factor : int):
	var img_size = _src_image.get_size()
	if img_size.x * factor >= 1 and img_size.y * factor >= 1:
		var new_img : Image = _src_image.duplicate()
		new_img.resize(img_size.x * factor, img_size.y * factor, Image.INTERPOLATE_NEAREST)
		sprite.texture = ImageTexture.create_from_image(new_img)


func scale_down(factor : int):
	var img_size = _src_image.get_size()
	if img_size.x / factor >= 1 and img_size.y / factor >= 1:
		var new_img : Image = _src_image.duplicate()
		new_img.resize(img_size.x / factor, img_size.y / factor, Image.INTERPOLATE_NEAREST)
		sprite.texture = ImageTexture.create_from_image(new_img)


func _on_grid_pressed():
	grid_view.show_grid = not grid_view.show_grid
	_refresh_icon_tint(grid_button)


func _on_zoom_in_pressed():
	grid_view.zoom_at_center(1.25)


func _on_zoom_out_pressed():
	grid_view.zoom_at_center(0.8)


func _on_zoom_fit_pressed():
	grid_view.update_camera_zoom()
