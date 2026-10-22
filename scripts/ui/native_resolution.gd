class_name RallyNativeResolution
extends RefCounted

# Menus lay out in a 1280x720 logical canvas ("canvas_items" stretch) while the
# window renders at its real pixel size. Off-screen 3D views must be sized in
# real pixels, not logical units, or they render at a fraction of the window
# and are magnified (blurry on Retina and any window larger than 1280x720).

# Real framebuffer pixels per logical UI unit for this control's window.
static func scale_for(control: Control) -> float:
	if not is_instance_valid(control) or not control.is_inside_tree(): return 1.0
	var transform := control.get_viewport().get_final_transform()
	return maxf(1.0,maxf(absf(transform.x.x),absf(transform.y.y)))


# Real pixel size of a control's on-screen rectangle.
static func pixel_size(control: Control) -> Vector2i:
	var factor := scale_for(control)
	return Vector2i(maxi(1,roundi(control.size.x*factor)),maxi(1,roundi(control.size.y*factor)))
