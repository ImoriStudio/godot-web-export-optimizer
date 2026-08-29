## Risultato di un'analisi export: popolato a export-time (nessuna API nativa
## permette di leggere un .pck già generato) e consumato dalla UI del dock.
class_name AnalysisReport
extends RefCounted

class CategoryStats:
	var size_bytes: int = 0
	var file_count: int = 0
	var files: PackedStringArray = PackedStringArray()

class TextureIssue:
	var path: String
	var size_bytes: int
	var compress_mode: int
	var width: int
	var height: int
	var oversized: bool = false
	var uncompressed: bool = false

var timestamp: int = 0
var total_size_bytes: int = 0
var categories: Dictionary = {} # AssetCategory.Category -> CategoryStats
var texture_issues: Array[TextureIssue] = []
var unused_assets: PackedStringArray = PackedStringArray()

func record_file(path: String, type: String, size_bytes: int) -> void:
	var category := AssetCategory.classify(path, type)
	if not categories.has(category):
		categories[category] = CategoryStats.new()
	var stats: CategoryStats = categories[category]
	stats.size_bytes += size_bytes
	stats.file_count += 1
	stats.files.append(path)
	total_size_bytes += size_bytes

func category_percentage(category: AssetCategory.Category) -> float:
	if total_size_bytes <= 0 or not categories.has(category):
		return 0.0
	var stats: CategoryStats = categories[category]
	return 100.0 * float(stats.size_bytes) / float(total_size_bytes)

## Serializzazione per persistere l'ultimo report su disco (report_store.gd):
## JSON non supporta chiavi non-stringa, quindi le categorie (enum int)
## vanno convertite ad andata e ritorno.
func to_dict() -> Dictionary:
	var categories_out := {}
	for category in categories:
		var stats: CategoryStats = categories[category]
		categories_out[str(int(category))] = {
			"size_bytes": stats.size_bytes,
			"file_count": stats.file_count,
			"files": Array(stats.files),
		}

	var issues_out := []
	for issue in texture_issues:
		issues_out.append({
			"path": issue.path,
			"size_bytes": issue.size_bytes,
			"compress_mode": issue.compress_mode,
			"width": issue.width,
			"height": issue.height,
			"oversized": issue.oversized,
			"uncompressed": issue.uncompressed,
		})

	return {
		"timestamp": timestamp,
		"total_size_bytes": total_size_bytes,
		"categories": categories_out,
		"texture_issues": issues_out,
		"unused_assets": Array(unused_assets),
	}

static func from_dict(data: Dictionary) -> AnalysisReport:
	var report := AnalysisReport.new()
	report.timestamp = int(data.get("timestamp", 0))
	report.total_size_bytes = int(data.get("total_size_bytes", 0))

	var categories_in: Dictionary = data.get("categories", {})
	for key in categories_in:
		var entry: Dictionary = categories_in[key]
		var stats := CategoryStats.new()
		stats.size_bytes = int(entry.get("size_bytes", 0))
		stats.file_count = int(entry.get("file_count", 0))
		var files := PackedStringArray()
		for file_path in entry.get("files", []):
			files.append(String(file_path))
		stats.files = files
		report.categories[int(key)] = stats

	for issue_data in data.get("texture_issues", []):
		var issue := TextureIssue.new()
		issue.path = String(issue_data.get("path", ""))
		issue.size_bytes = int(issue_data.get("size_bytes", 0))
		issue.compress_mode = int(issue_data.get("compress_mode", 0))
		issue.width = int(issue_data.get("width", 0))
		issue.height = int(issue_data.get("height", 0))
		issue.oversized = bool(issue_data.get("oversized", false))
		issue.uncompressed = bool(issue_data.get("uncompressed", false))
		report.texture_issues.append(issue)

	for asset_path in data.get("unused_assets", []):
		report.unused_assets.append(String(asset_path))

	return report
