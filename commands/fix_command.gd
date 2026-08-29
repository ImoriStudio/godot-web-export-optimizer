## Contratto per un'azione di fix applicabile dalla UI: sempre descrivibile
## prima dell'esecuzione, mai eseguita senza conferma esplicita dell'utente.
class_name FixCommand
extends RefCounted

## Path della risorsa toccata: permette alla UI di aggiornarsi subito dopo
## l'esecuzione senza dover rifare un export completo.
var path: String

func description() -> String:
	assert(false, "%s non implementa description()" % get_script().resource_path)
	return ""

func execute() -> bool:
	assert(false, "%s non implementa execute()" % get_script().resource_path)
	return false
