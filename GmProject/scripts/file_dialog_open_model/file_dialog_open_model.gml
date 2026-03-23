/// file_dialog_open_model()

function file_dialog_open_model()
{
	return file_dialog_open(text_get("filedialogopenmodel") + " (*.mimodel;*.json;*.obj;*.glb;*.gltf;*.zip)|*.mimodel;*.json;*.obj;*.glb;*.gltf;*.zip", "", "", text_get("filedialogopenmodelcaption"))
}
