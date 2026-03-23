/// mesh_load_glb / mesh_load_gltf — glTF 2.0: scene graph node transforms + all mesh primitives (indexed POSITION, optional TEXCOORD_0, NORMAL).
/// Textures deduped by glTF texture index. Fallback: flat mesh list with identity if no valid scene. GLB / .gltf+.bin as before.

function mesh_load_glb(fn, res)
{
	var b = buffer_load(fn);
	if (b < 0)
		return false;
	
	if (buffer_get_size(b) < 20)
	{
		buffer_delete(b);
		return false;
	}
	
	if (buffer_peek(b, 0, buffer_u32) != 1179937895) // GLB magic "glTF" (0x46546C67)
	{
		buffer_delete(b);
		return false;
	}
	
	buffer_seek(b, buffer_seek_start, 12);
	var jsonLen = buffer_read(b, buffer_u32);
	var jsonType = buffer_read(b, buffer_u32);
	if (jsonType != 1313821514) // JSON chunk type (0x4E4F534A)
	{
		buffer_delete(b);
		return false;
	}
	
	var jsonOff = buffer_tell(b);
	var jsonStr = mesh_load_glb_extract_utf8(b, jsonOff, jsonLen);
	buffer_seek(b, buffer_seek_start, jsonOff + jsonLen);
	// GLB: chunk data is padded so (8 + chunkLength) is a multiple of 4 bytes before the next chunk.
	var jsonChunkPad = (4 - (jsonLen mod 4)) mod 4;
	buffer_seek(b, buffer_seek_relative, jsonChunkPad);
	
	if (buffer_tell(b) >= buffer_get_size(b))
	{
		buffer_delete(b);
		return false;
	}
	
	var binLen = buffer_read(b, buffer_u32);
	var binType = buffer_read(b, buffer_u32);
	if (binType != 5130562) // BIN chunk type "BIN\0" (0x004E4942)
	{
		buffer_delete(b);
		return false;
	}
	
	var binOff = buffer_tell(b);
	var tmp = file_directory + "tmp_mesh_glb.json";
	var fh = file_text_open_write(tmp);
	file_text_write_string(fh, jsonStr);
	file_text_close(fh);
	
	var root = json_load(tmp);
	file_delete_lib(tmp);
	
	if (!ds_map_valid(root))
	{
		buffer_delete(b);
		return false;
	}
	
	var ok = mesh_load_gltf_parse(root, b, binOff, res, filename_dir(fn));
	buffer_delete(b);
	return ok;
}

function mesh_load_gltf(fn, res)
{
	if (!file_exists_lib(fn))
		return false;
	
	var root = json_load(fn);
	if (!ds_map_valid(root))
		return false;
	
	var buffers = root[?"buffers"];
	if (!ds_list_valid(buffers) || ds_list_size(buffers) < 1)
		return false;
	
	var b0 = buffers[|0];
	var uri = b0[?"uri"];
	if (!is_string(uri))
		return false;
	
	var binpath = filename_dir(fn) + "/" + uri;
	if (!file_exists_lib(binpath))
		return false;
	
	var bb = buffer_load(binpath);
	if (bb < 0)
		return false;
	
	var ok = mesh_load_gltf_parse(root, bb, 0, res, filename_dir(fn));
	buffer_delete(bb);
	return ok;
}

/// @ignore
function mesh_load_gltf_prim_base_color_tex_index(root, prim)
{
	var materials = root[?"materials"];
	var textures = root[?"textures"];
	if (!ds_list_valid(textures))
		return -1;
	var matI = round(value_get_real(prim[?"material"], -1));
	if (matI < 0 || !ds_list_valid(materials) || matI >= ds_list_size(materials))
		return -1;
	var mat = materials[|matI];
	var pbr = mat[?"pbrMetallicRoughness"];
	if (!ds_map_valid(pbr))
		return -1;
	var bct = pbr[?"baseColorTexture"];
	if (!ds_map_valid(bct))
		return -1;
	var texI = round(value_get_real(bct[?"index"], -1));
	if (texI < 0 || texI >= ds_list_size(textures))
		return -1;
	return texI;
}

/// @ignore
function mesh_load_gltf_load_base_color_sprite_cached(root, dataBuf, dataBase, gltfDir, prim, texCache)
{
	var texI = mesh_load_gltf_prim_base_color_tex_index(root, prim);
	if (texI < 0)
		return null;
	var k = string(texI);
	if (ds_map_exists(texCache, k))
		return texCache[?k];
	var spr = mesh_load_gltf_load_base_color_sprite(root, dataBuf, dataBase, gltfDir, prim);
	if (spr != null)
		texCache[?k] = spr;
	return spr;
}

/// @ignore
function mesh_load_gltf_load_base_color_sprite(root, dataBuf, dataBase, gltfDir, prim)
{
	var materials = root[?"materials"];
	var textures = root[?"textures"];
	var images = root[?"images"];
	var bufferViews = root[?"bufferViews"];
	if (!ds_list_valid(textures) || !ds_list_valid(images))
		return null;
	
	var matI = round(value_get_real(prim[?"material"], -1));
	if (matI < 0 || !ds_list_valid(materials) || matI >= ds_list_size(materials))
		return null;
	var mat = materials[|matI];
	var pbr = mat[?"pbrMetallicRoughness"];
	if (!ds_map_valid(pbr))
		return null;
	var bct = pbr[?"baseColorTexture"];
	if (!ds_map_valid(bct))
		return null;
	var texI = round(value_get_real(bct[?"index"], -1));
	if (texI < 0 || texI >= ds_list_size(textures))
		return null;
	var tex = textures[|texI];
	var srcI = round(value_get_real(tex[?"source"], -1));
	if (srcI < 0 || srcI >= ds_list_size(images))
		return null;
	var img = images[|srcI];
	
	var uri = img[?"uri"];
	if (is_string(uri) && string_length(uri) > 0)
	{
		if (string_length(uri) >= 5 && string_copy(uri, 1, 5) = "data:")
			return null;
		var path = gltfDir + "/" + uri;
		path = string_replace_all(path, "\\", "/");
		if (file_exists_lib(path))
			return texture_create(path);
		return null;
	}
	
	var bvi = round(value_get_real(img[?"bufferView"], -1));
	if (bvi < 0 || !ds_list_valid(bufferViews) || bvi >= ds_list_size(bufferViews))
		return null;
	var bv = bufferViews[|bvi];
	var off = value_get_real(bv[?"byteOffset"], 0);
	var len = value_get_real(bv[?"byteLength"], 0);
	if (len < 8 || off < 0)
		return null;
	var absOff = dataBase + off;
	if (absOff + len > buffer_get_size(dataBuf))
		return null;
	
	var mime = img[?"mimeType"];
	var ext = ".png";
	if (is_string(mime))
	{
		if (string_pos("jpeg", mime) > 0 || string_pos("jpg", mime) > 0)
			ext = ".jpg";
	}
	var tmp = file_directory + "tmp_mesh_gltf_tex" + ext;
	var slice = buffer_create(len, buffer_fixed, 1);
	buffer_copy(slice, 0, dataBuf, absOff, len);
	buffer_save(slice, tmp);
	buffer_delete(slice);
	var spr = texture_create(tmp);
	file_delete_lib(tmp);
	return spr;
}

function mesh_load_glb_extract_utf8(buf, offset, len)
{
	var s = "";
	for (var i = 0; i < len; i++)
		s += chr(buffer_peek(buf, offset + i, buffer_u8));
	return s;
}

/// glTF vertex → Mine-imator model space. First attempt (x, z, -y) matched RHS Rx(-90°) but appeared upside-down in-app (likely engine rotation sign / handedness). This map is Rx(180°)·Rx(-90°) on raw = (x, -z, y), i.e. fixes inversion vs that bake.
/// @ignore
function mesh_load_gltf_bake_import_orient_vec3(v)
{
	return [v[0], -v[2], v[1]];
}

/// Normal direction: upper 3×3 of node world matrix (glTF column-major layout, same as GameMaker matrix array).
/// @ignore
function mesh_load_gltf_mul_normal_linear(mat, n)
{
	var nx = mat[@ 0] * n[@ X] + mat[@ 4] * n[@ Y] + mat[@ 8] * n[@ Z];
	var ny = mat[@ 1] * n[@ X] + mat[@ 5] * n[@ Y] + mat[@ 9] * n[@ Z];
	var nz = mat[@ 2] * n[@ X] + mat[@ 6] * n[@ Y] + mat[@ 10] * n[@ Z];
	return vec3_normalize([nx, ny, nz]);
}

/// @ignore
function mesh_load_gltf_matrix16_from_list(lst)
{
	var m = array_create(16);
	for (var i = 0; i < 16; i++)
		m[i] = value_get_real(lst[|i], 0);
	return m;
}

/// glTF rotation [qx,qy,qz,qw] → 4×4 (column-major, rotation only).
/// @ignore
function mesh_load_gltf_quat_to_matrix4(qx, qy, qz, qw)
{
	var len = sqrt(qx * qx + qy * qy + qz * qz + qw * qw);
	if (len > 0.0001)
	{
		qx /= len;
		qy /= len;
		qz /= len;
		qw /= len;
	}
	else
	{
		qx = 0;
		qy = 0;
		qz = 0;
		qw = 1;
	}
	var xx = qx * qx;
	var yy = qy * qy;
	var zz = qz * qz;
	var xy = qx * qy;
	var xz = qx * qz;
	var yz = qy * qz;
	var wx = qw * qx;
	var wy = qw * qy;
	var wz = qw * qz;
	var m00 = 1 - 2 * (yy + zz);
	var m01 = 2 * (xy - wz);
	var m02 = 2 * (xz + wy);
	var m10 = 2 * (xy + wz);
	var m11 = 1 - 2 * (xx + zz);
	var m12 = 2 * (yz - wx);
	var m20 = 2 * (xz - wy);
	var m21 = 2 * (yz + wx);
	var m22 = 1 - 2 * (xx + yy);
	return [m00, m10, m20, 0, m01, m11, m21, 0, m02, m12, m22, 0, 0, 0, 0, 1];
}

/// Node TRS or 4×4 matrix (glTF defaults: identity TRS).
/// @ignore
function mesh_load_gltf_node_local_matrix(node)
{
	var marr = node[?"matrix"];
	if (ds_list_valid(marr) && ds_list_size(marr) >= 16)
		return mesh_load_gltf_matrix16_from_list(marr);
	
	var t = node[?"translation"];
	var r = node[?"rotation"];
	var s = node[?"scale"];
	var hasT = ds_list_valid(t) && ds_list_size(t) >= 3;
	var hasR = ds_list_valid(r) && ds_list_size(r) >= 4;
	var hasS = ds_list_valid(s) && ds_list_size(s) >= 3;
	if (!hasT && !hasR && !hasS)
		return matrix_build(0, 0, 0, 0, 0, 0, 1, 1, 1);
	
	var tx = hasT ? value_get_real(t[|0], 0) : 0;
	var ty = hasT ? value_get_real(t[|1], 0) : 0;
	var tz = hasT ? value_get_real(t[|2], 0) : 0;
	var qx = hasR ? value_get_real(r[|0], 0) : 0;
	var qy = hasR ? value_get_real(r[|1], 0) : 0;
	var qz = hasR ? value_get_real(r[|2], 0) : 0;
	var qw = hasR ? value_get_real(r[|3], 1) : 1;
	var sx = hasS ? value_get_real(s[|0], 1) : 1;
	var sy = hasS ? value_get_real(s[|1], 1) : 1;
	var sz = hasS ? value_get_real(s[|2], 1) : 1;
	
	var rotM = mesh_load_gltf_quat_to_matrix4(qx, qy, qz, qw);
	var scaleM = matrix_build(0, 0, 0, 0, 0, 0, sx, sy, sz);
	var trs = matrix_multiply(rotM, scaleM);
	var transM = matrix_build(tx, ty, tz, 0, 0, 0, 1, 1, 1);
	return matrix_multiply(transM, trs);
}

/// @ignore
function mesh_load_gltf_visit_node(nodes, nodeIdx, worldMat, meshes, root, dataBuf, dataBase, gltfDir, mapBlock, mapTex, texCache)
{
	if (nodeIdx < 0 || nodeIdx >= ds_list_size(nodes))
		return false;
	var node = nodes[|nodeIdx];
	var localMat = mesh_load_gltf_node_local_matrix(node);
	var wm = matrix_multiply(worldMat, localMat);
	var added = false;
	
	var meshRef = node[?"mesh"];
	if (!is_undefined(meshRef))
	{
		var midx = round(value_get_real(meshRef, -1));
		if (midx >= 0 && midx < ds_list_size(meshes))
		{
			var meshInst = meshes[|midx];
			var prims = meshInst[?"primitives"];
			if (ds_list_valid(prims))
			{
				var pc = ds_list_size(prims);
				for (var primIdx = 0; primIdx < pc; primIdx++)
				{
					var prim = prims[|primIdx];
					var vb = mesh_load_gltf_primitive_build_vbuffer(root, dataBuf, dataBase, prim, wm);
					if (vb = null)
						continue;
					var key = "n" + string(nodeIdx) + "_m" + string(midx) + "_p" + string(primIdx);
					ds_map_add(mapBlock, key, vb);
					var baseSpr = mesh_load_gltf_load_base_color_sprite_cached(root, dataBuf, dataBase, gltfDir, prim, texCache);
					if (baseSpr != null)
						ds_map_add(mapTex, key, baseSpr);
					added = true;
				}
			}
		}
	}
	
	var ch = node[?"children"];
	if (ds_list_valid(ch))
	{
		var cn = ds_list_size(ch);
		for (var ci = 0; ci < cn; ci++)
		{
			var cidx = round(value_get_real(ch[|ci], -1));
			if (mesh_load_gltf_visit_node(nodes, cidx, wm, meshes, root, dataBuf, dataBase, gltfDir, mapBlock, mapTex, texCache))
				added = true;
		}
	}
	return added;
}

/// glTF baseColorFactor (defaults 1,1,1,1) multiplies base color texture; apply as vertex color.
/// @ignore
function mesh_load_gltf_pbr_vertex_rgb_from_prim(root, prim)
{
	var materials = root[?"materials"];
	var matI = round(value_get_real(prim[?"material"], -1));
	if (matI < 0 || !ds_list_valid(materials) || matI >= ds_list_size(materials))
		return c_white;
	var mat = materials[|matI];
	var pbr = mat[?"pbrMetallicRoughness"];
	if (!ds_map_valid(pbr))
		return c_white;
	var bcf = pbr[?"baseColorFactor"];
	if (!ds_list_valid(bcf) || ds_list_size(bcf) < 3)
		return c_white;
	var rf = value_get_real(bcf[|0], 1);
	var gf = value_get_real(bcf[|1], 1);
	var bf = value_get_real(bcf[|2], 1);
	return make_color_rgb(round(clamp(rf, 0, 1) * 255), round(clamp(gf, 0, 1) * 255), round(clamp(bf, 0, 1) * 255));
}

/// @ignore
function mesh_load_gltf_primitive_build_vbuffer(root, dataBuf, dataBase, prim, worldMat)
{
	var accessors = root[?"accessors"];
	var bufferViews = root[?"bufferViews"];
	if (!ds_list_valid(accessors) || !ds_list_valid(bufferViews))
		return null;
	
	var attr = prim[?"attributes"];
	if (!ds_map_valid(attr))
		return null;
	
	var posAccI = round(value_get_real(attr[?"POSITION"], -1));
	var idxAccI = round(value_get_real(prim[?"indices"], -1));
	if (posAccI < 0 || idxAccI < 0)
		return null;
	
	var uvAccI = round(value_get_real(attr[?"TEXCOORD_0"], -1));
	var norAccI = round(value_get_real(attr[?"NORMAL"], -1));
	
	var posAcc = accessors[|posAccI];
	var idxAcc = accessors[|idxAccI];
	var posCount = round(value_get_real(posAcc[?"count"], 0));
	var idxCount = round(value_get_real(idxAcc[?"count"], 0));
	if (posCount < 1 || idxCount < 3 || (idxCount mod 3) != 0)
		return null;
	
	var posStride = mesh_load_gltf_accessor_stride(posAcc, bufferViews, 12);
	var uvStride = 8;
	var uvCompType = 5126;
	var uvNorm = false;
	if (uvAccI >= 0)
	{
		var uvAccA = accessors[|uvAccI];
		uvCompType = round(value_get_real(uvAccA[?"componentType"], 5126));
		var uvNormFld = uvAccA[?"normalized"];
		if (is_bool(uvNormFld))
			uvNorm = uvNormFld;
		else
			uvNorm = (value_get_real(uvNormFld, 0) != 0);
		uvStride = mesh_load_gltf_accessor_stride(uvAccA, bufferViews, 0);
		if (uvStride <= 0)
			uvStride = 2 * mesh_load_gltf_component_byte_size(uvCompType);
	}
	
	var posOff = mesh_load_gltf_accessor_byte_offset(posAcc, bufferViews, dataBase);
	var idxOff = mesh_load_gltf_accessor_byte_offset(idxAcc, bufferViews, dataBase);
	var uvOff = 0;
	if (uvAccI >= 0)
		uvOff = mesh_load_gltf_accessor_byte_offset(accessors[|uvAccI], bufferViews, dataBase);
	
	var hasNor = false;
	var norOff = 0;
	var norStride = 12;
	if (norAccI >= 0)
	{
		var nAccChk = accessors[|norAccI];
		if (round(value_get_real(nAccChk[?"count"], 0)) = posCount)
			hasNor = true;
	}
	if (hasNor)
	{
		var nAcc = accessors[|norAccI];
		norStride = mesh_load_gltf_accessor_stride(nAcc, bufferViews, 12);
		norOff = mesh_load_gltf_accessor_byte_offset(nAcc, bufferViews, dataBase);
	}
	
	var idxType = round(value_get_real(idxAcc[?"componentType"], 0));
	var idxElem = (idxType = 5123) ? 2 : ((idxType = 5125) ? 4 : 0);
	if (idxElem = 0)
		return null;
	
	var posArr = array_create(posCount);
	for (var p = 0; p < posCount; p++)
	{
		var o = posOff + p * posStride;
		var rawP = [
			buffer_peek(dataBuf, o, buffer_f32),
			buffer_peek(dataBuf, o + 4, buffer_f32),
			buffer_peek(dataBuf, o + 8, buffer_f32)
		];
		var wp = point3D_mul_matrix(rawP, worldMat);
		posArr[p] = mesh_load_gltf_bake_import_orient_vec3(wp);
	}
	
	var uvArr = array_create(posCount);
	var hasUv = (uvAccI >= 0);
	if (hasUv)
	{
		for (var u = 0; u < posCount; u++)
		{
			var o2 = uvOff + u * uvStride;
			if (o2 + uvStride > buffer_get_size(dataBuf))
			{
				uvArr[u] = [0, 0];
				continue;
			}
			uvArr[u] = mesh_load_gltf_read_uv_pair(dataBuf, o2, uvCompType, uvNorm);
		}
	}
	
	var normArr = array_create(posCount);
	if (hasNor)
	{
		for (var ni = 0; ni < posCount; ni++)
		{
			var on = norOff + ni * norStride;
			var rawN = [
				buffer_peek(dataBuf, on, buffer_f32),
				buffer_peek(dataBuf, on + 4, buffer_f32),
				buffer_peek(dataBuf, on + 8, buffer_f32)
			];
			var wn = mesh_load_gltf_mul_normal_linear(worldMat, rawN);
			normArr[ni] = vec3_normalize(mesh_load_gltf_bake_import_orient_vec3(wn));
		}
	}
	
	var vb = vbuffer_start();
	vertex_rgb = mesh_load_gltf_pbr_vertex_rgb_from_prim(root, prim);
	vertex_alpha = 1;
	vertex_wave = e_vertex_wave.NONE;
	vertex_emissive = 0;
	vertex_subsurface = 0;
	vertex_wave_zmin = null;
	vertex_wave_zmax = null;
	
	var triCount = idxCount div 3;
	for (var ti = 0; ti < triCount; ti++)
	{
		var oi = idxOff + (ti * 3) * idxElem;
		var i0 = mesh_load_gltf_read_index(dataBuf, oi, idxType);
		var i1 = mesh_load_gltf_read_index(dataBuf, oi + idxElem, idxType);
		var i2 = mesh_load_gltf_read_index(dataBuf, oi + idxElem * 2, idxType);
		if (i0 < 0 || i1 < 0 || i2 < 0 || i0 >= posCount || i1 >= posCount || i2 >= posCount)
			continue;
		
		var p0 = posArr[i0];
		var p1 = posArr[i1];
		var p2 = posArr[i2];
		var nf = mesh_load_obj_corner_nor(-1, [], p0, p1, p2);
		var n0 = hasNor ? vec3_normalize(normArr[i0]) : nf;
		var n1 = hasNor ? vec3_normalize(normArr[i1]) : nf;
		var n2 = hasNor ? vec3_normalize(normArr[i2]) : nf;
		
		var uvs0 = hasUv ? uvArr[i0] : [0, 0];
		var uvs1 = hasUv ? uvArr[i1] : [0, 0];
		var uvs2 = hasUv ? uvArr[i2] : [0, 0];
		vertex_add(p0, n0, [uvs0[0], uvs0[1]]);
		vertex_add(p1, n1, [uvs1[0], uvs1[1]]);
		vertex_add(p2, n2, [uvs2[0], uvs2[1]]);
	}
	
	vertex_end(vb);
	vb = vbuffer_generate_tangents(vb);
	vertex_freeze(vb);
	
	if (vbuffer_is_empty(vb))
	{
		vbuffer_destroy(vb);
		return null;
	}
	return vb;
}

function mesh_load_gltf_parse(root, dataBuf, dataBase, res, gltfDir)
{
	var accessors = root[?"accessors"];
	var bufferViews = root[?"bufferViews"];
	var meshes = root[?"meshes"];
	if (!ds_list_valid(accessors) || !ds_list_valid(bufferViews) || !ds_list_valid(meshes))
		return false;
	var meshCount = ds_list_size(meshes);
	if (meshCount < 1)
		return false;
	
	var mapBlock = ds_map_create();
	var mapTex = ds_map_create();
	var texCache = ds_map_create();
	var identity = matrix_build(0, 0, 0, 0, 0, 0, 1, 1, 1);
	var anyOk = false;
	
	var nodes = root[?"nodes"];
	var scenes = root[?"scenes"];
	if (ds_list_valid(nodes) && ds_list_valid(scenes) && ds_list_size(scenes) > 0 && ds_list_size(nodes) > 0)
	{
		var defSceneI = round(value_get_real(root[?"scene"], 0));
		if (defSceneI < 0 || defSceneI >= ds_list_size(scenes))
			defSceneI = 0;
		var sc = scenes[|defSceneI];
		var rootsN = sc[?"nodes"];
		if (ds_list_valid(rootsN))
		{
			var rn = ds_list_size(rootsN);
			for (var ri = 0; ri < rn; ri++)
			{
				var ridx = round(value_get_real(rootsN[|ri], -1));
				if (mesh_load_gltf_visit_node(nodes, ridx, identity, meshes, root, dataBuf, dataBase, gltfDir, mapBlock, mapTex, texCache))
					anyOk = true;
			}
		}
	}
	
	if (!anyOk)
	{
		for (var mi = 0; mi < meshCount; mi++)
		{
			var meshInst = meshes[|mi];
			var prims = meshInst[?"primitives"];
			if (!ds_list_valid(prims))
				continue;
			var primCount = ds_list_size(prims);
			for (var primIdx = 0; primIdx < primCount; primIdx++)
			{
				var prim = prims[|primIdx];
				var vb = mesh_load_gltf_primitive_build_vbuffer(root, dataBuf, dataBase, prim, identity);
				if (vb = null)
					continue;
				var key = "m" + string(mi) + "_p" + string(primIdx);
				ds_map_add(mapBlock, key, vb);
				var baseSpr = mesh_load_gltf_load_base_color_sprite_cached(root, dataBuf, dataBase, gltfDir, prim, texCache);
				if (baseSpr != null)
					ds_map_add(mapTex, key, baseSpr);
				anyOk = true;
			}
		}
	}
	
	ds_map_destroy(texCache);
	
	if (!anyOk)
	{
		var kk = ds_map_find_first(mapBlock);
		while (!is_undefined(kk))
		{
			vbuffer_destroy(mapBlock[?kk]);
			kk = ds_map_find_next(mapBlock, kk);
		}
		ds_map_destroy(mapBlock);
		ds_map_destroy(mapTex);
		return false;
	}
	
	// Avoid with(res) here so CppGen does not capture outer locals oddly; res is the resource instance id.
	res.model_block_map = mapBlock;
	if (ds_map_size(mapTex) > 0)
		res.model_texture_map = mapTex;
	else
	{
		ds_map_destroy(mapTex);
		res.model_texture_map = null;
	}
	
	if (res.model_texture_name_map != null)
		ds_map_clear(res.model_texture_name_map);
	else
		res.model_texture_name_map = ds_map_create();
	
	if (res.model_texture_material_name_map != null)
		ds_map_clear(res.model_texture_material_name_map);
	else
		res.model_texture_material_name_map = ds_map_create();
	
	if (res.model_tex_normal_name_map != null)
		ds_map_clear(res.model_tex_normal_name_map);
	else
		res.model_tex_normal_name_map = ds_map_create();
	
	if (res.model_color_name_map != null)
		ds_map_clear(res.model_color_name_map);
	else
		res.model_color_name_map = ds_map_create();
	
	return true;
}

function mesh_load_gltf_accessor_byte_offset(acc, bufferViews, dataBase)
{
	var bvi = round(value_get_real(acc[?"bufferView"], -1));
	if (bvi < 0)
		return dataBase;
	var bv = bufferViews[|bvi];
	var bvOff = value_get_real(bv[?"byteOffset"], 0);
	var accOff = value_get_real(acc[?"byteOffset"], 0);
	return dataBase + bvOff + accOff;
}

function mesh_load_gltf_accessor_stride(acc, bufferViews, defaultStride)
{
	var bvi = round(value_get_real(acc[?"bufferView"], -1));
	if (bvi < 0)
		return defaultStride;
	var bv = bufferViews[|bvi];
	var st = value_get_real(bv[?"byteStride"], 0);
	if (st > 0)
		return st;
	return defaultStride;
}

function mesh_load_gltf_read_index(buf, offset, compType)
{
	if (compType = 5123)
		return buffer_peek(buf, offset, buffer_u16);
	if (compType = 5125)
		return buffer_peek(buf, offset, buffer_u32);
	return -1;
}

/// glTF accessor componentType byte width (FLOAT / UNSIGNED_SHORT / UNSIGNED_BYTE).
/// @ignore
function mesh_load_gltf_component_byte_size(compType)
{
	if (compType = 5126)
		return 4;
	if (compType = 5123)
		return 2;
	if (compType = 5121)
		return 1;
	return 4;
}

/// Read TEXCOORD_0 VEC2; UNSIGNED_* + normalized is common in game rips (was mis-read as float → garbage UVs).
/// @ignore
function mesh_load_gltf_read_uv_pair(buf, offset, compType, normalized)
{
	if (compType = 5126)
	{
		var uf = buffer_peek(buf, offset, buffer_f32);
		var vf = buffer_peek(buf, offset + 4, buffer_f32);
		return [uf, vf];
	}
	if (compType = 5123)
	{
		var ua = buffer_peek(buf, offset, buffer_u16);
		var va = buffer_peek(buf, offset + 2, buffer_u16);
		if (normalized)
			return [ua / 65535.0, va / 65535.0];
		return [real(ua), real(va)];
	}
	if (compType = 5121)
	{
		var ub = buffer_peek(buf, offset, buffer_u8);
		var vb = buffer_peek(buf, offset + 1, buffer_u8);
		if (normalized)
			return [ub / 255.0, vb / 255.0];
		return [real(ub), real(vb)];
	}
	return [0, 0];
}
