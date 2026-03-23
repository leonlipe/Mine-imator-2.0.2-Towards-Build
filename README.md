# Mine-imator 2.0.2 Towards Build

<p align="center">
  <img src="https://u.cubeupload.com/YogaindoCR/Simply.png" width=800/>
  <br/>
  <br/>
  <img src="https://raw.githubusercontent.com/YogaindoCR/Mine-imator-2.0.2-Simply-Upscaled-Build/refs/heads/master/Iklan.webp" width=800/>
  <br/>
  <img src="https://u.cubeupload.com/YogaindoCR/Misu.png" width=312/>
</p>

## Build this fork (no GameMaker IDE)

From the **repository root** in PowerShell, in order:

| Step | Run | Purpose |
|------|-----|---------|
| **1** | [`Scripts/Setup-DevEnvironment.ps1`](Scripts/Setup-DevEnvironment.ps1) | Windows: install .NET 8, CMake, MSVC via winget; optional `-SetUserDevDirEnv` for `DEV_DIR`. |
| **2** | [`Scripts/Build-FromCpp.ps1`](Scripts/Build-FromCpp.ps1) | CppGen → CMake → `Release\` plus a **distributable `.zip`** (unless `-NoZip`). |

Details, Qt/External checklist, and macOS/Linux notes: **[Docs/BUILD.md](Docs/BUILD.md)**.

- External meshes: [Docs/MESH_IMPORT.md](Docs/MESH_IMPORT.md)  
- Data / transparency notes: [Docs/DATA_TRANSPARENCY.md](Docs/DATA_TRANSPARENCY.md)  
- Upstream Qt & library sources: [CppProject/BUILD.md](CppProject/BUILD.md)

Mine-imator is a 3D movie maker based on the sandbox game Minecraft, with over 8 million downloads since its launch in 2012. Version 2.0, the 10th anniversary update brings numerous additions including a new UI, new renderer, animation features, multiplatform support and 3D world importer.

Website and download: https://www.mineimator.com
