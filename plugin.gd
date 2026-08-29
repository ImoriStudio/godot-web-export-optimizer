@tool
## Entry point del plugin: collega la cattura dati export (EditorExportPlugin)
## al dock di analisi (Observer via segnale analysis_completed).
extends EditorPlugin

const PRO_ENTRY_PATH := "res://addons/webexport_optimizer/pro/pro_plugin.gd"

var _export_capture: WebExportCapture
var _dock: WebExportOptimizerDock
var _pro: RefCounted

func _enter_tree() -> void:
	_export_capture = WebExportCapture.new()
	add_export_plugin(_export_capture)

	_dock = WebExportOptimizerDock.new()
	_dock.setup(_export_capture)
	add_dock(_dock)

	_load_pro()

func _exit_tree() -> void:
	_pro = null
	if _dock:
		remove_dock(_dock)
		_dock.queue_free()
		_dock = null
	if _export_capture:
		remove_export_plugin(_export_capture)
		_export_capture = null

## Il livello Pro non è un requisito del Free: se la cartella pro/ non è
## presente (distribuzione Free) il plugin funziona esattamente come senza
## questo metodo. Il coordinatore Pro si aggancia solo via API pubbliche di
## WebExportCapture/WebExportOptimizerDock, mai il contrario.
func _load_pro() -> void:
	if not ResourceLoader.exists(PRO_ENTRY_PATH):
		return
	_pro = load(PRO_ENTRY_PATH).new()
	_pro.setup(_export_capture, _dock)
