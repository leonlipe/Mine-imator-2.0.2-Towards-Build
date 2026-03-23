/// mesh_load_obj(filename, resource)
/// @arg filename
/// @arg resource
/// @desc Loads a Wavefront OBJ into resource.model_block_map (triangulated). Optional MTL + map_Kd.

function mesh_load_obj_trim(str)
{
	if (str = "")
		return "";
	while (string_length(str) > 0 && ord(string_char_at(str, 1)) <= 32)
		str = string_delete(str, 1, 1);
	while (string_length(str) > 0 && ord(string_char_at(str, string_length(str))) <= 32)
		str = string_delete(str, string_length(str), 1);
	return str;
}

function mesh_load_obj(fn, res)
{
	var objdir = filename_dir(fn);
	var file = file_text_open_read(fn);
	if (file = -1)
		return false;
	
	var verts = [];
	var uvs = [];
	var norms = [];
	var curmtl = "";
	var mtllib = "";
	
	// material -> ds_list of [v0,vt0,vn0, v1,vt1,vn1, v2,vt2,vn2] (resolved indices, -1 if missing)
	var facemap = ds_map_create();
	// Fail fast on multi‑million‑vertex OBJ (e.g. 100MB+ room meshes) to avoid freeze/OOM.
	var MESH_LOAD_OBJ_MAX_VERTICES = 800000;
	// Many rips have modest vertex counts but huge triangle lists (dense scenes) — cap tris too.
	var MESH_LOAD_OBJ_MAX_TRIANGLES = 2000000;
	var MESH_LOAD_OBJ_MAX_FACE_VERTS = 512;
	var triTotal = 0;
	
	while (!file_text_eof(file))
	{
		var line = mesh_load_obj_trim(file_text_readln(file));
		if (line = "" || string_char_at(line, 1) = "#")
			continue;
		
		var sp = string_split(line, " ");
		var cmd = sp[0];
		if (cmd = "mtllib" && array_length(sp) > 1)
		{
			var rest = string_copy(line, string_pos(" ", line) + 1, string_length(line));
			mtllib = mesh_load_obj_trim(rest);
		}
		else if (cmd = "usemtl" && array_length(sp) > 1)
		{
			curmtl = mesh_load_obj_trim(string_copy(line, string_pos(" ", line) + 1, string_length(line)));
		}
		else if (cmd = "v" && array_length(sp) >= 4)
		{
			if (array_length(verts) >= MESH_LOAD_OBJ_MAX_VERTICES)
			{
				file_text_close(file);
				var kcap = ds_map_find_first(facemap);
				while (!is_undefined(kcap))
				{
					ds_list_destroy(facemap[?kcap]);
					kcap = ds_map_find_next(facemap, kcap);
				}
				ds_map_destroy(facemap);
				return false;
			}
			var vi = array_length(verts);
			verts[vi] = [real(sp[1]), real(sp[2]), real(sp[3])];
		}
		else if (cmd = "vt" && array_length(sp) >= 3)
		{
			var uvi = array_length(uvs);
			uvs[uvi] = [real(sp[1]), real(sp[2])];
		}
		else if (cmd = "vn" && array_length(sp) >= 4)
		{
			var ni = array_length(norms);
			norms[ni] = [real(sp[1]), real(sp[2]), real(sp[3])];
		}
		else if (cmd = "f")
		{
			var n = array_length(sp) - 1;
			if (n < 3 || n > MESH_LOAD_OBJ_MAX_FACE_VERTS)
				continue;
			
			var addTris = n - 2;
			if (triTotal + addTris > MESH_LOAD_OBJ_MAX_TRIANGLES)
			{
				file_text_close(file);
				var ktri = ds_map_find_first(facemap);
				while (!is_undefined(ktri))
				{
					ds_list_destroy(facemap[?ktri]);
					ktri = ds_map_find_next(facemap, ktri);
				}
				ds_map_destroy(facemap);
				return false;
			}
			triTotal += addTris;
			
			var corners = array_create(n);
			for (var c = 0; c < n; c++)
				corners[c] = mesh_load_obj_parse_corner(sp[c + 1], array_length(verts), array_length(uvs), array_length(norms));
			
			for (var t = 1; t < n - 1; t++)
			{
				var tri = array_create(9);
				array_copy(tri, 0, corners[0], 0, 3);
				array_copy(tri, 3, corners[t], 0, 3);
				array_copy(tri, 6, corners[t + 1], 0, 3);
				
				if (!ds_map_exists(facemap, curmtl))
					ds_map_add(facemap, curmtl, ds_list_create());
				ds_list_add(facemap[?curmtl], tri);
			}
		}
	}
	file_text_close(file);
	
	if (ds_map_size(facemap) = 0)
	{
		ds_map_destroy(facemap);
		return false;
	}
	
	var mtlmap = mesh_load_obj_parse_mtl(objdir, mtllib);
	
	with (res)
	{
		model_block_map = ds_map_create();
		model_texture_map = ds_map_create();
		
		var mkey = ds_map_find_first(facemap);
		while (!is_undefined(mkey))
		{
			var trilist = facemap[?mkey];
			var vb = mesh_load_obj_build_vbuffer(trilist, verts, uvs, norms);
			if (vb = null || vbuffer_is_empty(vb))
			{
				if (vb != null)
					vbuffer_destroy(vb);
			}
			else
				model_block_map[?mkey] = vb;
			
			if (mtlmap != null && ds_map_exists(mtlmap, mkey))
			{
				var texrel = mtlmap[?mkey];
				texrel = string_replace_all(texrel, "\\", "/");
				var texpath = objdir + "/" + texrel;
				if (file_exists_lib(texpath))
				{
					var spr = texture_create(texpath);
					if (spr != null)
						model_texture_map[?mkey] = spr;
				}
			}
			
			ds_list_destroy(trilist);
			mkey = ds_map_find_next(facemap, mkey);
		}
		
		if (model_texture_name_map != null)
			ds_map_clear(model_texture_name_map);
		else
			model_texture_name_map = ds_map_create();
		
		if (model_texture_material_name_map != null)
			ds_map_clear(model_texture_material_name_map);
		else
			model_texture_material_name_map = ds_map_create();
		
		if (model_tex_normal_name_map != null)
			ds_map_clear(model_tex_normal_name_map);
		else
			model_tex_normal_name_map = ds_map_create();
		
		if (model_color_name_map != null)
			ds_map_clear(model_color_name_map);
		else
			model_color_name_map = ds_map_create();
		
		if (ds_map_size(model_texture_map) = 0)
		{
			ds_map_destroy(model_texture_map);
			model_texture_map = null;
		}
	}
	
	ds_map_destroy(facemap);
	if (mtlmap != null)
		ds_map_destroy(mtlmap);
	
	var ok = ds_map_size(res.model_block_map) > 0;
	if (!ok)
	{
		with (res)
		{
			if (model_block_map != null)
			{
				var kf = ds_map_find_first(model_block_map);
				while (!is_undefined(kf))
				{
					vbuffer_destroy(model_block_map[?kf]);
					kf = ds_map_find_next(model_block_map, kf);
				}
				ds_map_destroy(model_block_map);
				model_block_map = null;
			}
			if (model_texture_map != null)
			{
				var kf2 = ds_map_find_first(model_texture_map);
				while (!is_undefined(kf2))
				{
					texture_free(model_texture_map[?kf2]);
					kf2 = ds_map_find_next(model_texture_map, kf2);
				}
				ds_map_destroy(model_texture_map);
				model_texture_map = null;
			}
		}
	}
	return ok;
}

/// @ignore
function mesh_load_obj_resolve_index(i, count)
{
	if (i = 0)
		return -1;
	if (i < 0)
		return count + i;
	return i - 1;
}

/// @ignore
function mesh_load_obj_parse_corner(token, vc, utc, nc)
{
	var parts = string_split(token, "/");
	var pn = array_length(parts);
	var vi = 0, vti = -1, vni = -1;
	
	if (pn >= 1 && parts[0] != "")
		vi = mesh_load_obj_resolve_index(real(parts[0]), vc);
	if (pn >= 2 && parts[1] != "")
		vti = mesh_load_obj_resolve_index(real(parts[1]), utc);
	if (pn >= 3 && parts[2] != "")
		vni = mesh_load_obj_resolve_index(real(parts[2]), nc);
	else if (pn = 3 && parts[1] = "" && parts[2] != "")
		vni = mesh_load_obj_resolve_index(real(parts[2]), nc);
	
	return [vi, vti, vni];
}

/// @ignore
function mesh_load_obj_parse_mtl(objdir, mtllib)
{
	if (mtllib = "" || !file_exists_lib(objdir + "/" + mtllib))
		return null;
	
	var m = ds_map_create();
	var file = file_text_open_read(objdir + "/" + mtllib);
	if (file = -1)
	{
		ds_map_destroy(m);
		return null;
	}
	
	var cur = "";
	while (!file_text_eof(file))
	{
		var line = mesh_load_obj_trim(file_text_readln(file));
		if (line = "" || string_char_at(line, 1) = "#")
			continue;
		var sp = string_split(line, " ");
		var cmd = sp[0];
		if (cmd = "newmtl" && array_length(sp) > 1)
			cur = mesh_load_obj_trim(string_copy(line, string_pos(" ", line) + 1, string_length(line)));
		else if ((cmd = "map_Kd" || cmd = "map_kd") && cur != "" && array_length(sp) > 1)
		{
			var texname = mesh_load_obj_trim(string_copy(line, string_pos(" ", line) + 1, string_length(line)));
			// Strip optional flags (-s, -o, etc.) by taking last token if path has spaces issue — use last space segment
			var sp2 = string_split(texname, " ");
			texname = sp2[array_length(sp2) - 1];
			if (ds_map_exists(m, cur))
				ds_map_delete(m, cur);
			ds_map_add(m, cur, texname);
		}
	}
	file_text_close(file);
	return m;
}

/// @ignore
function mesh_load_obj_corner_pos(vertidx, verts)
{
	if (vertidx < 0 || vertidx >= array_length(verts))
		return [0, 0, 0];
	return verts[vertidx];
}

/// @ignore
function mesh_load_obj_corner_uv(vtidx, uvs)
{
	if (vtidx < 0 || vtidx >= array_length(uvs))
		return [0, 0];
	return uvs[vtidx];
}

/// @ignore
function mesh_load_obj_corner_nor(vnidx, norms, p0, p1, p2)
{
	if (vnidx >= 0 && vnidx < array_length(norms))
		return vec3_normalize(norms[vnidx]);
	var e1 = vec3_sub(p1, p0);
	var e2 = vec3_sub(p2, p0);
	var cr = vec3_cross(e1, e2);
	if (vec3_length(cr) < 0.0000001)
		return [0, 0, 1];
	return vec3_normalize(cr);
}

/// @ignore
function mesh_load_obj_build_vbuffer(trilist, verts, uvs, norms)
{
	var vb = vbuffer_start();
	vertex_rgb = c_white;
	vertex_alpha = 1;
	vertex_wave = e_vertex_wave.NONE;
	vertex_emissive = 0;
	vertex_subsurface = 0;
	vertex_wave_zmin = null;
	vertex_wave_zmax = null;
	
	for (var i = 0; i < ds_list_size(trilist); i++)
	{
		var tri = trilist[|i];
		var p0 = mesh_load_obj_corner_pos(tri[0], verts);
		var p1 = mesh_load_obj_corner_pos(tri[3], verts);
		var p2 = mesh_load_obj_corner_pos(tri[6], verts);
		
		// Unrolled corners: CppGen indexes arrays with IntType only (no RealType index).
		var pi0 = mesh_load_obj_corner_pos(tri[0], verts);
		var uv0 = mesh_load_obj_corner_uv(tri[1], uvs);
		var n0 = mesh_load_obj_corner_nor(tri[2], norms, p0, p1, p2);
		vertex_add(pi0, n0, [uv0[0], 1 - uv0[1]]);
		var pi1 = mesh_load_obj_corner_pos(tri[3], verts);
		var uv1 = mesh_load_obj_corner_uv(tri[4], uvs);
		var n1 = mesh_load_obj_corner_nor(tri[5], norms, p0, p1, p2);
		vertex_add(pi1, n1, [uv1[0], 1 - uv1[1]]);
		var pi2 = mesh_load_obj_corner_pos(tri[6], verts);
		var uv2 = mesh_load_obj_corner_uv(tri[7], uvs);
		var n2 = mesh_load_obj_corner_nor(tri[8], norms, p0, p1, p2);
		vertex_add(pi2, n2, [uv2[0], 1 - uv2[1]]);
	}
	
	vertex_end(vb);
	vb = vbuffer_generate_tangents(vb);
	vertex_freeze(vb);
	return vb;
}
