/// render_world_block_map(modelmap, resource)
/// @arg modelmap
/// @arg resource
/// @desc Renders each vbuffer in the given map, with the key as the chosen texture from the resource.

function render_world_block_map(modelmap, res)
{
	var key;
	
	if (modelmap = null)
		return 0
	
	key = ds_map_find_first(modelmap)
	while (!is_undefined(key))
	{
		var vbuffer = modelmap[?key];
		if (!vbuffer_is_empty(vbuffer))
		{
			var tex;
			with (res)
				tex = res_get_model_texture(key)
			if (tex = null || !sprite_exists(tex))
				tex = spr_shape;
			render_set_texture(tex)
			vbuffer_render(vbuffer)
		}
		
		key = ds_map_find_next(modelmap, key)	
	}
}
