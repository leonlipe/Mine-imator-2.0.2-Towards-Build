# Data transparency (Towards Build)

Build-from-source steps for this fork: [BUILD.md](BUILD.md) (`Scripts\Setup-DevEnvironment.ps1` then `Scripts\Build-FromCpp.ps1` from the repo root).

This document covers two different meanings of “transparency” that show up in projects and support questions.

## 1. Rendering transparency (graphics)

Mine-imator’s renderer distinguishes **opaque**, **semi-transparent**, and **cutout** behavior for blocks, particles, and materials. Project settings that affect how alpha is interpreted include (names may vary slightly by UI version):

- **Transparent shadows** — whether light/shadow passes respect partially transparent surfaces.
- **Transparent block texture filtering** — filtering behavior on transparent block textures (can change edge halos).
- **Alpha mode** (per-timeline / material-related options) — hashed alpha vs blend modes in modern render paths.

These values are stored inside project and render preset JSON (for example `.miproject` and `.mirender` files) as numeric or boolean fields. When sharing a project, expect **texture paths, Minecraft asset versions, and render preset names** to travel with the file.

## 2. Project data (what gets saved)

A typical Mine-imator project references:

- **`.miproject`** — timeline, keyframes, library entries, render settings references, and resource IDs.
- **Resource folders** — copied models, images, audio, particle files, and cached data depending on how resources were imported.
- **User settings** — stored under the application data path (see in-app **Settings** / `Data` folder layout for your OS).

This fork does **not** change the fundamental privacy model of Mine-imator: projects you distribute contain what you put in them (assets, text, embedded paths). Do not commit personal tokens, paid asset licenses you are not allowed to redistribute, or private paths if you publish the repo.

## 3. Open-source and forks

Source code for this fork is available under the terms of the repository **LICENSE**. Third-party assets (Minecraft assets, user skins, packs) remain subject to **their** licenses. Some repo hygiene files (for example under `.github`) were aligned with the Stegripe template; they do not change application behavior.
