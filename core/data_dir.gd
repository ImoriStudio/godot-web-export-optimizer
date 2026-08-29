## Cartella dove il plugin salva dati che devono sopravvivere al riavvio
## dell'editor (ultimo report, storico dimensioni, badge...). Il path è per
## progetto — salvato in ProjectSettings, quindi condiviso col team se il
## project.godot va in git — non per macchina come la chiave di licenza Pro
## (quella resta in EditorSettings, vedi pro/license_state.gd).
class_name WebOptDataDir
extends RefCounted

const SETTING_KEY := "webexport_optimizer/data_directory"
const DEFAULT_PATH := "res://.export_history"

static func get_data_path() -> String:
	if ProjectSettings.has_setting(SETTING_KEY):
		var value := String(ProjectSettings.get_setting(SETTING_KEY))
		if not value.is_empty():
			return value
	return DEFAULT_PATH

static func file_path(filename: String) -> String:
	return get_data_path().path_join(filename)

## Cambia la cartella salvata in ProjectSettings. Se move_existing è vero e la
## cartella attuale esiste, sposta l'intero contenuto sulla nuova invece di
## ricominciare da zero — altrimenti l'utente perderebbe report/storico già
## accumulati solo perché ha cambiato idea su dove tenerli.
static func set_data_path(new_path: String, move_existing: bool) -> Dictionary:
	new_path = new_path.strip_edges()
	while new_path.length() > "res://".length() and new_path.ends_with("/"):
		new_path = new_path.left(new_path.length() - 1)

	if new_path.is_empty():
		return {"ok": false, "reason": "empty"}
	if not new_path.begins_with("res://"):
		return {"ok": false, "reason": "not_res"}

	var old_path := get_data_path()
	if move_existing and old_path != new_path and DirAccess.dir_exists_absolute(old_path):
		if DirAccess.dir_exists_absolute(new_path):
			return {"ok": false, "reason": "destination_exists"}
		var parent := new_path.get_base_dir()
		if parent != "res://":
			DirAccess.make_dir_recursive_absolute(parent)
		if DirAccess.rename_absolute(old_path, new_path) != OK:
			return {"ok": false, "reason": "move_failed"}

	ProjectSettings.set_setting(SETTING_KEY, new_path)
	ProjectSettings.save()
	return {"ok": true}
