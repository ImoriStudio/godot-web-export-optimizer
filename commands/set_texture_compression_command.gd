## Passa una texture da Lossless/VRAM Uncompressed a Lossy: riduce il peso su
## disco senza il compromesso qualità-2D di VRAM Compressed/Basis Universal.
class_name SetTextureCompressionCommand
extends FixCommand

const TARGET_COMPRESS_MODE := 1 # Lossy

func _init(texture_path: String) -> void:
	path = texture_path

func description() -> String:
	return WebOptLocalization.t("confirm_texture_fix") % path.get_file()

func execute() -> bool:
	var import_path := path + ".import"
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		return false

	config.set_value("params", "compress/mode", TARGET_COMPRESS_MODE)
	if config.save(import_path) != OK:
		return false

	EditorInterface.get_resource_filesystem().reimport_files(PackedStringArray([path]))
	return true
