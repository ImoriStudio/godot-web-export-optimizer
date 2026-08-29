## Rileva texture non ottimizzate per il Web: prive di compressione disco
## (Lossless/VRAM Uncompressed) sopra soglia di peso, o con risoluzione
## sorgente eccessiva.
##
## Non propone mai VRAM Compressed/Basis Universal come fix automatica: la
## documentazione ufficiale Godot la sconsiglia per elementi 2D, quindi la
## scelta va lasciata allo sviluppatore in base al contesto d'uso.
class_name TextureAuditAnalyzer
extends AssetAnalyzer

const DISK_SIZE_THRESHOLD_BYTES := 300 * 1024
const RESOLUTION_THRESHOLD_PX := 2048

const COMPRESS_LOSSLESS := 0
const COMPRESS_VRAM_UNCOMPRESSED := 3
const UNCOMPRESSED_MODES := [COMPRESS_LOSSLESS, COMPRESS_VRAM_UNCOMPRESSED]

func analyze(report: AnalysisReport) -> void:
	if not report.categories.has(AssetCategory.Category.TEXTURE):
		return
	var stats: AnalysisReport.CategoryStats = report.categories[AssetCategory.Category.TEXTURE]
	for path in stats.files:
		var issue := audit(path)
		if issue:
			report.texture_issues.append(issue)

## Pubblico e riutilizzabile dalla UI: dopo una fix, il dock ri-controlla la
## singola texture invece di aspettare un nuovo export per aggiornarsi.
## Restituisce null se la texture non ha (più) problemi.
static func audit(path: String) -> AnalysisReport.TextureIssue:
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return null
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		return null

	var issue := AnalysisReport.TextureIssue.new()
	issue.path = path
	issue.size_bytes = FileUtils.exported_size(path)
	issue.compress_mode = config.get_value("params", "compress/mode", COMPRESS_LOSSLESS)

	var texture := ResourceLoader.load(path) as Texture2D
	if texture:
		issue.width = texture.get_width()
		issue.height = texture.get_height()
		issue.oversized = maxi(issue.width, issue.height) > RESOLUTION_THRESHOLD_PX

	issue.uncompressed = issue.compress_mode in UNCOMPRESSED_MODES \
		and issue.size_bytes > DISK_SIZE_THRESHOLD_BYTES

	return issue if (issue.oversized or issue.uncompressed) else null
