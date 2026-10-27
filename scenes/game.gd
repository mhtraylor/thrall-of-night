extends Node2D


func _ready() -> void:
    var version = ProjectSettings.get_setting_with_override("application/config/version")
    print("Build " + version)
