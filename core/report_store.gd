## Persiste l'ultimo report su disco: senza questo, chiudere e riaprire
## l'editor cancella tutto ciò che il dock mostra finché non si rifà un
## export. Il path segue WebOptDataDir, quindi cambiare la cartella dati
## dal dock sposta anche questo.
class_name WebOptReportStore
extends RefCounted

const FILENAME := "last_report.json"

static func save(report: AnalysisReport) -> void:
	var dir := WebOptDataDir.get_data_path()
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(WebOptDataDir.file_path(FILENAME), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(report.to_dict(), "\t"))
	file.close()

static func load() -> AnalysisReport:
	var path := WebOptDataDir.file_path(FILENAME)
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return AnalysisReport.from_dict(parsed) if parsed is Dictionary else null
