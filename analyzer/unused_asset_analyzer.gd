## Segnala texture/audio/font inclusi nell'export ma non raggiungibili dal
## grafo delle dipendenze di nessuna scena del progetto.
##
## Le scene vengono cercate sul filesystem del progetto, non nei file
## catturati dall'export: in fase di export Godot converte i .tscn in un
## binario temporaneo sotto res://.godot/exported/, quindi il path passato a
## _export_file() per una scena non è quello sorgente utilizzabile per la
## ricerca.
##
## Limite noto: le risorse caricate dinamicamente da script (load()/preload()
## con percorso non statico) non compaiono nel grafo delle dipendenze e
## possono generare falsi positivi — per questo il check è limitato alle
## categorie dove il rischio è più contenuto e il beneficio più concreto.
class_name UnusedAssetAnalyzer
extends AssetAnalyzer

const CHECKED_CATEGORIES := [
	AssetCategory.Category.TEXTURE,
	AssetCategory.Category.AUDIO,
	AssetCategory.Category.FONT,
]

func analyze(report: AnalysisReport) -> void:
	var scene_paths := _find_scenes("res://")
	if scene_paths.is_empty():
		return
	var referenced := _collect_referenced(scene_paths)

	for category in CHECKED_CATEGORIES:
		if not report.categories.has(category):
			continue
		var stats: AnalysisReport.CategoryStats = report.categories[category]
		for path in stats.files:
			if not referenced.has(path):
				report.unused_assets.append(path)

func _find_scenes(dir_path: String) -> PackedStringArray:
	var scenes := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return scenes

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full_path := dir_path.path_join(entry)
			if dir.current_is_dir():
				scenes.append_array(_find_scenes(full_path))
			elif entry.get_extension() in ["tscn", "scn"]:
				scenes.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()

	return scenes

func _collect_referenced(scene_paths: PackedStringArray) -> Dictionary:
	var referenced := {}
	var pending: Array[String] = []
	for path in scene_paths:
		pending.append(path)

	while not pending.is_empty():
		var current: String = pending.pop_back()
		if referenced.has(current) or not ResourceLoader.exists(current):
			continue
		referenced[current] = true
		for dependency in ResourceLoader.get_dependencies(current):
			var resolved := FileUtils.resolve_dependency_path(dependency)
			if not referenced.has(resolved):
				pending.append(resolved)

	return referenced
