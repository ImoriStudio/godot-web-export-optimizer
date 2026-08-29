## Fa parlare il pannello nella stessa lingua dell'editor di Godot (Editor
## Settings > Interface > Editor Language) — non quella del progetto/gioco,
## che in Godot è un'impostazione separata e indipendente.
##
## "auto" (il default) segue la lingua del sistema operativo, quindi in quel
## caso si legge OS.get_locale() invece della chiave editor_language.
class_name WebOptLocalization
extends RefCounted

const _SETTING_KEY := "interface/editor/localization/editor_language"
const _AUTO_VALUE := "auto"

static var _active: Dictionary
static var _resolved := false

static func t(key: String) -> String:
	_ensure_resolved()
	var fallback: Dictionary = WebOptStrings.STRINGS[WebOptStrings.FALLBACK_LOCALE]
	return _active.get(key, fallback.get(key, key))

static func _ensure_resolved() -> void:
	if _resolved:
		return
	_resolved = true
	var locale := _detect_locale()
	_active = WebOptStrings.STRINGS.get(locale, WebOptStrings.STRINGS[WebOptStrings.FALLBACK_LOCALE])

static func _detect_locale() -> String:
	var raw := _read_editor_language()
	if raw.is_empty() or raw == _AUTO_VALUE:
		raw = OS.get_locale()
	var short := raw.split("_")[0].split("-")[0].to_lower()
	return short if WebOptStrings.STRINGS.has(short) else WebOptStrings.FALLBACK_LOCALE

static func _read_editor_language() -> String:
	if not Engine.is_editor_hint():
		return ""
	var settings := EditorInterface.get_editor_settings()
	return String(settings.get_setting(_SETTING_KEY)) if settings else ""
