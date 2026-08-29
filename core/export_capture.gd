## EditorExportPlugin che intercetta ogni file dell'export Web per costruire
## l'inventario per categoria: non esiste un'API nativa per leggere un .pck
## già generato, quindi i dati vanno raccolti durante l'export stesso.
class_name WebExportCapture
extends EditorExportPlugin

signal analysis_completed(report: AnalysisReport)

## Cartella di destinazione dell'ultimo export Web, esposta per il Pro (es.
## pck_splitter.gd deve sapere dove copiare il pck differito): il Free non la
## usa mai internamente.
var last_export_output_dir: String

var last_report: AnalysisReport

var _report: AnalysisReport

func _init() -> void:
	## Senza questo, chiudere e riaprire l'editor cancella tutto ciò che il
	## dock mostra finché non si rifà un export — recupera l'ultimo report
	## salvato, se c'è.
	last_report = WebOptReportStore.load()

func _get_name() -> String:
	return "WebExportCapture"

func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	_report = AnalysisReport.new() if features.has("web") else null
	if _report:
		_report.timestamp = int(Time.get_unix_time_from_system())
		last_export_output_dir = path.get_base_dir()

func _export_file(path: String, type: String, _features: PackedStringArray) -> void:
	if _report:
		_report.record_file(path, type, FileUtils.exported_size(path))

func _export_end() -> void:
	if _report == null:
		return
	TextureAuditAnalyzer.new().analyze(_report)
	UnusedAssetAnalyzer.new().analyze(_report)
	last_report = _report
	_report = null
	WebOptReportStore.save(last_report)
	analysis_completed.emit(last_report)
