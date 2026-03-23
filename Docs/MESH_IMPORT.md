# External 3D mesh import (Towards Build)

## Supported formats

| Format | Status |
|--------|--------|
| **OBJ** (`.obj`) | Supported: geometry is **triangulated on load** (polygon fans from the first vertex). Optional **MTL** with `map_Kd` diffuse textures next to the OBJ. |
| **glTF** (`.gltf` + `.bin`) | First `buffers[]` entry must use a **relative** `.bin` URI next to the `.gltf`. Uses the **default scene’s node hierarchy** (`nodes` / `children` / `mesh`) so **transforms match Sketchfab** (furniture not floating). Loads every referenced mesh primitive (indexed `POSITION`, optional `TEXCOORD_0`, `NORMAL`). **Base color textures** are shared per glTF texture index (less RAM when many parts reuse the same image). If there is no usable scene, falls back to listing all `meshes[]` with identity transform. |
| **GLB** (`.glb`) | Same as glTF, embedded BIN chunk. |
| **Blender `.blend`** | Not loaded natively. Export to **glTF 2.0** or **OBJ** (enable **Triangulate** in the exporter to match recommended workflow). |

## glTF / GLB notes

- Vertices are **re-oriented** on import for Mine-imator’s **Y-up** scene (internal axis bake). Most game/DCC exports appear upright; if a rare file does not, adjust **rotation** on the timeline.
- **Skins, animations, and node hierarchies** are not imported — only static mesh geometry and **PBR base color** (`baseColorTexture` + `baseColorFactor`). **Metallic–roughness textures** and **normals maps** are ignored by the importer (shading may differ from Sketchfab).
- If part of a scene looked **uniformly black** before: typical cause was **many materials** in one file while only the first primitive’s texture was used. Re-import after updating the fork, or merge materials in Blender for older builds.
- **Heavy RAM** on big scenes is mostly **many separate draw batches** (one vertex buffer per primitive) plus texture resolution; deduped textures help, but very large Sketchfab exports may still need simplification in Blender.

## OBJ notes

- Faces may be quads or n-gons; the importer splits them into triangles.
- Vertex data: `v`, `vt`, `vn`, and `f` with `v`, `v/vt`, `v//vn`, or `v/vt/vn` are supported.
- Indices may be positive or negative (relative to the end of the list).
- If vertex normals are missing, a **face normal** is computed per triangle.
- Textures: only **`map_Kd`** (diffuse) is read from MTL; paths are resolved relative to the OBJ directory.

## Recommended Blender export

1. **File → Export → Wavefront (.obj)** or **glTF 2.0**.
2. For OBJ: enable triangulation (or apply the Triangulate modifier before export).
3. Keep textures in the same folder as the OBJ/MTL, or use relative paths MTL can resolve.

## Sample file

- [samples/teddy.obj](samples/teddy.obj) — use for a quick import smoke test.

## Troubleshooting

- **Pink/black checkerboard:** texture path wrong or missing; assign a block sheet in the library or fix MTL paths.
- **Inside-out or invisible mesh:** try the timeline **Backfaces** option or flip normals in the DCC tool.
- **Huge or tiny model:** adjust template scale in Mine-imator after import.
