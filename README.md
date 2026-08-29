# Web Export Optimizer

Editor plugin for Godot 4.7 that analyzes a Web (HTML5) export and reports where its size comes from, so you can act on it without leaving the editor.

By [IMORI STUDIO](https://imoristudio.com). For a longer, illustrated walkthrough (English/Italian), see [docs/guide.html](docs/guide.html).

<!-- TODO: swap this anchor for the live Dodo Payments checkout link once merchant verification is complete -->
**Pro upgrade — coming soon.** €9 one-time, adds build size history, GitHub Actions CI, and progressive loading. This README will be updated with the purchase link once it's live — see the [Pro](#pro) section below for what's included.

## What it does

- Breaks down the last Web export by category (texture, audio, scene, font, 3D model/material) with size and percentage of the total — GDScript files are compiled through a separate engine step that doesn't expose per-file size, so they aren't part of this breakdown
- Flags textures that are neither disk-compressed nor within a reasonable resolution for their weight
- Flags textures and audio/font files that are exported but not reachable from any project scene's dependency graph
- Applies safe compression fixes to flagged textures with one click, always behind a confirmation dialog

## How it works

- Godot has no API to read back an already-built `.pck`, so the plugin captures per-file data live during export (`EditorExportPlugin._export_file`) rather than parsing the output afterward
- Reported sizes are the size of what each file *imports to* (`res://.godot/imported/...`), not the source file on disk — for a texture or audio file those can differ by an order of magnitude, and importing to the wrong one is the single easiest way to make a size report meaningless. Validated against a real export: total reported size tracked the actual `.pck` within ~0.6%, both before and after applying a fix
- "Unreferenced asset" detection walks every `.tscn`/`.scn` in the project (not just the ones in this export) and follows `ResourceLoader.get_dependencies()` from there; resources loaded dynamically from a non-literal path in a script won't be seen by this graph and may be reported as unreferenced by mistake — verify before deleting anything
- The plugin's own files are counted like any other exported resource. If you don't want it in your release Web build, add `addons/webexport_optimizer/*` to the export preset's **Resources → Filters to exclude** field — this is the standard Godot mechanism for keeping editor-only addons out of a build
- `.res`/`.tres` files are native Godot resources of many kinds (mesh, material, but also things like a `Theme` or an `Environment`), so extension alone can't categorize them. The plugin uses the resource type Godot reports at export time and only buckets unambiguous 3D types (`ArrayMesh`, the primitive mesh classes, `StandardMaterial3D`, `ORMMaterial3D`) under **Model** — anything else native stays under **Other** rather than risk a wrong label

## Texture fix — design choice

The one-click fix switches oversized, disk-uncompressed textures (Lossless / VRAM Uncompressed) to **Lossy**, which reduces on-disk size without changing runtime memory behavior.

VRAM Compressed and Basis Universal are not offered as an automatic fix: Godot's own docs recommend against them for 2D elements, and the right choice depends on how a texture is actually used in the scene. Textures flagged as oversized are reported with their resolution but left for you to resize deliberately.

## Usage

1. Enable the plugin in **Project Settings → Plugins**
2. Run **Project → Export…** for a Web preset
3. Open the **Web Export Optimizer** dock (bottom-left dock area by default)
4. Review the category breakdown and the flagged textures/assets
5. Apply fixes where relevant, confirm, then re-export to verify the result

## Interface language

The panel follows Godot's own editor language (**Editor Settings → Interface → Editor Language**), not the project's — those are two separate settings in Godot. Currently shipped: English, Italian. An unsupported editor language falls back to English. Adding a language means adding one entry to `i18n/strings.gd`; nothing else needs to change.

## Compatibility

Built and tested against Godot **4.7**. No compatibility layer for earlier versions is included — some APIs used here (`EditorDock`, `add_dock`) were introduced in 4.6 and are not available before it.

## Pro

An optional `pro/` module, loaded automatically if present, adds four features on top of the Free tier:

- **Size history**: every export appends its total and per-category size to `.export_history/size_history.json`, shown in the dock with the change against the previous build
- **Badge**: a static, shields.io-style SVG (`.export_history/web-build-size-badge.svg`) regenerated on every export, ready to link from your own README — no network calls
- **CI**: a "Generate GitHub Actions workflow" button writes `.github/workflows/web-export-size.yml`, which exports the project headlessly and prints/summarizes the size report on every push and pull request
- **Progressive loading**: "Enable progressive loading" moves everything above a size threshold (default 200 KB — scripts and scenes are always kept in the initial download) out of the main `.pck` and into a second `deferred.pck`, fetched and merged in at runtime after the game has already started

### How progressive loading actually works

`EditorExportPlugin`'s `exclude_filter` keeps files out of the main `.pck`; `PCKPacker` builds the second one; `ProjectSettings.load_resource_pack()` merges it back in at runtime. None of that is new — what makes it work *transparently*, with existing scenes unmodified, is what goes into that second `.pck`: not the source `.png`, but its `.import` file plus the compiled data Godot generated under `res://.godot/imported/`. Without the `.import` file, a scene's existing `texture = ExtResource(...)` reference to that path resolves to nothing — Godot needs it to find the compiled resource. Verified in an isolated test project with no access to the original source files: all four asset types the demo exercises (oversized texture, mesh, plus a case just over the compression threshold) loaded at their original paths with correct data after `load_resource_pack()`.

One thing this can't do: retroactively fix a node that was already showing a deferred asset before the pack finished loading. A scene that depends on deferred content should wait for `WebOptDeferredLoader.deferred_assets_ready` (the autoload registered when you enable this) before displaying it — a loading screen is the natural place for that. Re-export after enabling for it to take effect.

Pro isn't part of this repository — it's distributed separately. **It's not on sale yet**: we're finishing payment/license setup now, and this README will be updated with a direct purchase link in a follow-up release once it's live.

<!-- TODO: add the live Dodo Payments checkout link here once merchant verification is complete -->

## License

MIT — see [LICENSE](LICENSE). Applies to everything in this repository, which does not include the Pro module above.
