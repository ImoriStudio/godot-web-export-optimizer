## Formattazione dimensioni condivisa tra dock (Free) e sezioni Pro.
class_name FormatUtils
extends RefCounted

static func size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	if bytes < 1024 * 1024:
		return "%.1f KB" % (bytes / 1024.0)
	return "%.2f MB" % (bytes / (1024.0 * 1024.0))
