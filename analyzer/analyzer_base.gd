## Contratto comune agli analyzer: ricevono il report già popolato con le
## dimensioni per-file e vi aggiungono le proprie rilevazioni (SRP: un
## analyzer, una responsabilità).
class_name AssetAnalyzer
extends RefCounted

func analyze(_report: AnalysisReport) -> void:
	assert(false, "%s non implementa analyze()" % get_script().resource_path)
