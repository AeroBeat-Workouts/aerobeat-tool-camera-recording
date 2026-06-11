## Base template for a Tool Manager.
##
## This class is a clone-time placeholder only.
## Rename the file/class/autoload to the repo-specific manager name
## before treating a template clone as real runtime surface area.
## Examples: AeroApiManager, AeroSettingsManager.
class_name AeroToolManager
extends Node

#region SIGNALS
## Emitted when the tool has finished initializing.
signal initialized
#endregion

#region ENUMS & CONSTANTS
const VERSION: String = "0.0.1"
#endregion

#region EXPORTS
@export var is_active: bool = true
#endregion

#region PRIVATE VARIABLES
var _is_initialized: bool = false
#endregion

#region LIFECYCLE
func _ready() -> void:
	_initialize()

func _initialize() -> void:
	if _is_initialized:
		return
	
	# TODO: Add initialization logic here after renaming this placeholder manager.
	_is_initialized = true
	initialized.emit()
	print("AeroToolManager placeholder initialized. Rename this manager for the cloned repo.")
#endregion
