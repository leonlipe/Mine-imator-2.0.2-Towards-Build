/// tl_update_values_ease(valueid)
/// @arg valueid

function tl_update_values_ease(vid)
{
	var oldval, curval, nextval, val, beforeval, afterval;
	oldval = value[vid]

	if (keyframe_animate)
	{
		curval = keyframe_current_values[vid]
		nextval = keyframe_next_values[vid]

		if ((oldval = curval) && (oldval = nextval))
			return 0

		if (keyframe_transition == "catmullrom")
		{
			beforeval = keyframe_before_values[vid]
			afterval = keyframe_after_values[vid]
			val = tl_value_interpolate(vid, keyframe_progress, curval, nextval, beforeval, afterval)
		}
		else
			val = tl_value_interpolate(vid, keyframe_progress_ease, curval, nextval)
	}
	else if (keyframe_next)
		val = keyframe_next_values[vid]
	else
		val = value_default[vid]
	
	if (oldval != val)
	{
		update_matrix = true
		value[vid] = val
	}
}
