## Utility di I/O condivise tra capture ed analyzer.
class_name FileUtils
extends RefCounted

static func file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size := file.get_length()
	file.close()
	return size

## Path del file compilato che un asset importato risolve a runtime
## (res://.godot/imported/...), oppure "" se path non è una risorsa importata
## (nessun .import accanto, es. una scena o un .tres nativo).
static func imported_dest_path(path: String) -> String:
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return ""
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		return ""
	var dest_files: Array = config.get_value("deps", "dest_files", [])
	return String(dest_files[0]) if not dest_files.is_empty() else ""

## Dimensione di ciò che finisce davvero nel pck. Per le risorse importate
## (texture, audio, ...) Godot esporta il file convertito sotto
## res://.godot/imported/, non il sorgente — misurare il sorgente sottostima o
## sovrastima anche di un ordine di grandezza (una texture 1.7 MB può
## importare a poche centinaia di KB una volta compressa).
static func exported_size(path: String) -> int:
	var dest := imported_dest_path(path)
	return file_size(dest) if not dest.is_empty() else file_size(path)

## ResourceLoader.get_dependencies() restituisce "path" oppure "uid::(vuoto)::path_fallback".
static func resolve_dependency_path(dependency: String) -> String:
	if "::" in dependency:
		var parts := dependency.split("::")
		return parts[2] if parts.size() >= 3 else parts[0]
	return dependency
