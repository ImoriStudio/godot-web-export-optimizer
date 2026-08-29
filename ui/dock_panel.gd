## Pannello editor "Web Export Optimizer": mostra il report dell'ultima
## analisi e applica le fix sicure sulle texture segnalate, sempre dietro
## conferma esplicita (pattern Command + Observer sui segnali di WebExportCapture).
class_name WebExportOptimizerDock
extends EditorDock

var _capture: WebExportCapture
var _pending_commands: Array[FixCommand] = []

var _root: VBoxContainer
var _confirm_dialog: ConfirmationDialog
var _status_label: Label
var _category_tree: Tree
var _texture_issues_box: VBoxContainer
var _unused_assets_box: VBoxContainer
var _total_label: Label

var _settings_popup: PopupPanel
var _settings_root: VBoxContainer

var _data_dir_input: LineEdit
var _data_dir_status_label: Label
var _data_dir_dialog: EditorFileDialog
var _move_confirm_dialog: ConfirmationDialog

func _init() -> void:
	title = "Web Export Optimizer"
	default_slot = EditorDock.DOCK_SLOT_RIGHT_BL
	dock_icon = preload("res://addons/webexport_optimizer/icon.svg")

func setup(capture: WebExportCapture) -> void:
	_capture = capture
	_capture.analysis_completed.connect(_on_analysis_completed)

func _ready() -> void:
	_build_ui()
	if _capture and _capture.last_report:
		_render_report(_capture.last_report)

func _build_ui() -> void:
	## Senza questo scroll esterno, se il dock è più basso della somma di
	## tutte le sezioni (categorie + texture + asset + storico + CI +
	## licenza...) il resto resta tagliato fuori senza modo di raggiungerlo —
	## gli scroll interni (texture/asset) da soli non bastano.
	var outer_scroll := ScrollContainer.new()
	outer_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(outer_scroll)

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 8)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_scroll.add_child(_root)
	var root := _root

	var header := HBoxContainer.new()
	root.add_child(header)
	var analyze_button := Button.new()
	analyze_button.text = WebOptLocalization.t("analyze_button")
	analyze_button.pressed.connect(_on_analyze_pressed)
	header.add_child(analyze_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	## flat=true replica lo stile delle icone toolbar native dell'editor
	## (es. FileSystem dock): riquadro visibile solo in hover/pressed, non un
	## bottone bordato sempre visibile come "Attiva"/"Sfoglia"/"Salva".
	var settings_button := Button.new()
	settings_button.icon = get_theme_icon("Tools", "EditorIcons")
	settings_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	settings_button.custom_minimum_size = Vector2(28, 28)
	settings_button.flat = true
	settings_button.tooltip_text = WebOptLocalization.t("settings_button_tooltip")
	settings_button.pressed.connect(_on_settings_pressed)
	header.add_child(settings_button)

	_status_label = Label.new()
	_status_label.text = WebOptLocalization.t("status_none")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_status_label)

	root.add_child(_section_title(WebOptLocalization.t("section_categories")))
	_category_tree = Tree.new()
	_category_tree.custom_minimum_size = Vector2(0, 140)
	_category_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_category_tree.size_flags_stretch_ratio = 1.0
	_category_tree.columns = 3
	_category_tree.column_titles_visible = true
	_category_tree.set_column_title(0, WebOptLocalization.t("col_category"))
	_category_tree.set_column_title(1, WebOptLocalization.t("col_size"))
	_category_tree.set_column_title(2, WebOptLocalization.t("col_percent"))
	_category_tree.hide_root = true
	root.add_child(_category_tree)

	root.add_child(_section_title(WebOptLocalization.t("section_textures")))
	var texture_scroll := ScrollContainer.new()
	texture_scroll.custom_minimum_size = Vector2(0, 160)
	texture_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_scroll.size_flags_stretch_ratio = 2.0
	root.add_child(texture_scroll)
	_texture_issues_box = VBoxContainer.new()
	_texture_issues_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_scroll.add_child(_texture_issues_box)

	root.add_child(_section_title(WebOptLocalization.t("section_unused")))
	var unused_scroll := ScrollContainer.new()
	unused_scroll.custom_minimum_size = Vector2(0, 100)
	unused_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	unused_scroll.size_flags_stretch_ratio = 1.0
	root.add_child(unused_scroll)
	_unused_assets_box = VBoxContainer.new()
	_unused_assets_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unused_scroll.add_child(_unused_assets_box)

	root.add_child(HSeparator.new())
	_total_label = Label.new()
	_total_label.text = "%s: —" % WebOptLocalization.t("total_label")
	root.add_child(_total_label)

	_build_settings_popup()

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.confirmed.connect(_on_fix_confirmed)
	add_child(_confirm_dialog)

func _build_settings_popup() -> void:
	_settings_popup = PopupPanel.new()
	add_child(_settings_popup)

	_settings_root = VBoxContainer.new()
	_settings_root.add_theme_constant_override("separation", 8)
	_settings_root.custom_minimum_size = Vector2(360, 0)
	_settings_popup.add_child(_settings_root)

	_build_data_dir_section()

func _on_settings_pressed() -> void:
	## popup_centered() senza argomenti usa la size corrente della finestra,
	## che per un popup mai mostrato prima resta quella di default (enorme) —
	## va ricalcolata sul contenuto reale ad ogni apertura, perché il Pro può
	## aver aggiunto la sezione licenza nel frattempo.
	var content_size := _settings_root.get_combined_minimum_size()
	_settings_popup.popup_centered(Vector2i(content_size) + Vector2i(32, 32))

## Punto di estensione per il livello Pro: aggiunge una sezione titolata nel
## popup impostazioni (non nel corpo principale del pannello) e restituisce
## il contenitore da popolare — usato per la gestione della licenza.
func add_settings_section(title_text: String) -> VBoxContainer:
	if _settings_root.get_child_count() > 0:
		_settings_root.add_child(HSeparator.new())
	_settings_root.add_child(_section_title(title_text))
	var box := VBoxContainer.new()
	_settings_root.add_child(box)
	return box

## Cambiare la cartella dati sposta anche il contenuto già esistente, invece
## di farlo sparire — l'utente non deve rifare l'analisi solo perché ha
## deciso di tenere i dati altrove.
func _build_data_dir_section() -> void:
	var box := add_settings_section(WebOptLocalization.t("section_data_dir"))

	var hint := Label.new()
	hint.text = WebOptLocalization.t("data_dir_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.modulate.a = 0.75
	box.add_child(hint)

	var row := HBoxContainer.new()
	box.add_child(row)

	_data_dir_input = LineEdit.new()
	_data_dir_input.text = WebOptDataDir.get_data_path()
	_data_dir_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_data_dir_input)

	var browse_button := Button.new()
	browse_button.text = WebOptLocalization.t("data_dir_browse_button")
	browse_button.pressed.connect(_on_browse_data_dir_pressed)
	row.add_child(browse_button)

	var save_button := Button.new()
	save_button.text = WebOptLocalization.t("data_dir_save_button")
	save_button.pressed.connect(_on_save_data_dir_pressed)
	box.add_child(save_button)

	_data_dir_status_label = Label.new()
	_data_dir_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_data_dir_status_label.modulate.a = 0.75
	box.add_child(_data_dir_status_label)

	_data_dir_dialog = EditorFileDialog.new()
	_data_dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_data_dir_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_data_dir_dialog.dir_selected.connect(_on_data_dir_picked)
	add_child(_data_dir_dialog)

	_move_confirm_dialog = ConfirmationDialog.new()
	_move_confirm_dialog.confirmed.connect(_on_move_data_dir_confirmed)
	add_child(_move_confirm_dialog)

func _on_browse_data_dir_pressed() -> void:
	_data_dir_dialog.popup_centered_ratio(0.5)

func _on_data_dir_picked(dir: String) -> void:
	_data_dir_input.text = dir

func _on_save_data_dir_pressed() -> void:
	var new_path := _data_dir_input.text.strip_edges()
	var old_path := WebOptDataDir.get_data_path()
	if new_path == old_path:
		return

	if DirAccess.dir_exists_absolute(old_path):
		_move_confirm_dialog.dialog_text = WebOptLocalization.t("data_dir_move_confirm") % [old_path, new_path]
		_move_confirm_dialog.popup_centered()
	else:
		_apply_data_dir_change(false)

func _on_move_data_dir_confirmed() -> void:
	_apply_data_dir_change(true)

func _apply_data_dir_change(move_existing: bool) -> void:
	var new_path := _data_dir_input.text.strip_edges()
	var result := WebOptDataDir.set_data_path(new_path, move_existing)
	if result.get("ok", false):
		_data_dir_status_label.text = WebOptLocalization.t("data_dir_saved")
	else:
		_data_dir_status_label.text = WebOptLocalization.t("data_dir_failed")
		_data_dir_input.text = WebOptDataDir.get_data_path()

## Riusa la riga di stato esistente per conferme rapide del Pro (es. "workflow
## CI generato"), invece di duplicare un'altra label nel pannello.
func set_status(text: String) -> void:
	_status_label.text = text

## Punto di estensione per il livello Pro: aggiunge una sezione titolata in
## fondo al pannello e restituisce il contenitore da popolare, così il Free
## non deve conoscere nulla del Pro (e viceversa il Pro non deve duplicare
## lo stile delle sezioni esistenti).
func add_section(title_text: String) -> VBoxContainer:
	_root.add_child(HSeparator.new())
	_root.add_child(_section_title(title_text))
	var box := VBoxContainer.new()
	_root.add_child(box)
	return box

func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	return label

func _on_analyze_pressed() -> void:
	if _capture and _capture.last_report:
		_render_report(_capture.last_report)
	else:
		_status_label.text = WebOptLocalization.t("status_unavailable")

func _on_analysis_completed(report: AnalysisReport) -> void:
	_render_report(report)

func _render_report(report: AnalysisReport) -> void:
	_status_label.text = WebOptLocalization.t("status_analyzed") % Time.get_datetime_string_from_unix_time(report.timestamp)
	_render_categories(report)
	_render_texture_issues(report)
	_render_unused_assets(report)
	_total_label.text = "%s: %s" % [WebOptLocalization.t("total_label"), FormatUtils.size(report.total_size_bytes)]

func _render_categories(report: AnalysisReport) -> void:
	_category_tree.clear()
	var root := _category_tree.create_item()
	var categories := report.categories.keys()
	categories.sort_custom(func(a, b): return report.categories[a].size_bytes > report.categories[b].size_bytes)
	for category in categories:
		var stats: AnalysisReport.CategoryStats = report.categories[category]
		var item := _category_tree.create_item(root)
		item.set_text(0, AssetCategory.label(category))
		item.set_text(1, FormatUtils.size(stats.size_bytes))
		item.set_text(2, "%.1f%%" % report.category_percentage(category))

func _render_texture_issues(report: AnalysisReport) -> void:
	_clear_box(_texture_issues_box)
	if report.texture_issues.is_empty():
		_texture_issues_box.add_child(_info_label(WebOptLocalization.t("empty_textures")))
		return

	var fixable_count := 0
	for issue in report.texture_issues:
		if issue.uncompressed:
			fixable_count += 1
	if fixable_count > 1:
		var fix_all_button := Button.new()
		fix_all_button.text = WebOptLocalization.t("apply_all_fixes_button") % fixable_count
		fix_all_button.pressed.connect(_on_apply_all_pressed)
		_texture_issues_box.add_child(fix_all_button)

	for issue in report.texture_issues:
		_texture_issues_box.add_child(_texture_issue_row(issue))

func _texture_issue_row(issue: AnalysisReport.TextureIssue) -> Control:
	var row := HBoxContainer.new()

	var tags: Array[String] = []
	if issue.uncompressed:
		tags.append(WebOptLocalization.t("tag_uncompressed"))
	if issue.oversized:
		tags.append("%dx%d px" % [issue.width, issue.height])

	var info := Label.new()
	info.text = "%s — %s (%s)" % [issue.path.get_file(), FormatUtils.size(issue.size_bytes), ", ".join(tags)]
	info.tooltip_text = issue.path
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.clip_text = true
	row.add_child(info)

	if issue.uncompressed:
		var fix_button := Button.new()
		fix_button.text = WebOptLocalization.t("apply_fix_button")
		fix_button.pressed.connect(_on_apply_fix_pressed.bind(issue.path))
		row.add_child(fix_button)

	return row

func _on_apply_fix_pressed(path: String) -> void:
	var cmd := SetTextureCompressionCommand.new(path)
	_pending_commands = [cmd]
	_confirm_dialog.dialog_text = cmd.description()
	_confirm_dialog.popup_centered()

func _on_apply_all_pressed() -> void:
	var report := _capture.last_report if _capture else null
	if report == null:
		return

	var commands: Array[FixCommand] = []
	for issue in report.texture_issues:
		if issue.uncompressed:
			commands.append(SetTextureCompressionCommand.new(issue.path))
	if commands.is_empty():
		return

	_pending_commands = commands
	_confirm_dialog.dialog_text = WebOptLocalization.t("confirm_texture_fix_all") % commands.size()
	_confirm_dialog.popup_centered()

func _on_fix_confirmed() -> void:
	if _pending_commands.is_empty():
		return

	var applied_count := 0
	for cmd in _pending_commands:
		if cmd.execute():
			applied_count += 1
			_patch_report_after_fix(cmd.path)

	var report := _capture.last_report if _capture else null
	if report:
		_render_categories(report)
		_render_texture_issues(report)
		_total_label.text = "%s: %s" % [WebOptLocalization.t("total_label"), FormatUtils.size(report.total_size_bytes)]

	_status_label.text = WebOptLocalization.t("status_fix_applied") if applied_count == _pending_commands.size() \
		else WebOptLocalization.t("status_fix_failed")
	_pending_commands = []

## Aggiorna il report in memoria subito dopo una fix, senza aspettare un
## nuovo export: rimuove la vecchia voce, ricalcola la dimensione reale della
## texture appena reimportata e la ri-controlla — se non ha più problemi,
## semplicemente sparisce dalla lista.
func _patch_report_after_fix(path: String) -> void:
	var report := _capture.last_report if _capture else null
	if report == null or not report.categories.has(AssetCategory.Category.TEXTURE):
		return

	var stats: AnalysisReport.CategoryStats = report.categories[AssetCategory.Category.TEXTURE]
	for i in range(report.texture_issues.size() - 1, -1, -1):
		if report.texture_issues[i].path == path:
			var old_size: int = report.texture_issues[i].size_bytes
			stats.size_bytes -= old_size
			report.total_size_bytes -= old_size
			report.texture_issues.remove_at(i)
			break

	var new_size := FileUtils.exported_size(path)
	stats.size_bytes += new_size
	report.total_size_bytes += new_size

	var updated_issue := TextureAuditAnalyzer.audit(path)
	if updated_issue:
		report.texture_issues.append(updated_issue)

func _render_unused_assets(report: AnalysisReport) -> void:
	_clear_box(_unused_assets_box)
	if report.unused_assets.is_empty():
		_unused_assets_box.add_child(_info_label(WebOptLocalization.t("empty_unused")))
		return
	for path in report.unused_assets:
		_unused_assets_box.add_child(_info_label(path))

func _clear_box(box: VBoxContainer) -> void:
	for child in box.get_children():
		child.queue_free()

func _info_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate.a = 0.75
	return label
