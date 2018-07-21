# PrinterSettingsScope

A simple delphi class to force the printer to specific settings (via DEVMODE), currently only color implemented but easily extendable.

Please note that this changes the global printer settings. If possible, it is always better/safer to use the DEVMODE structure directly, if a class exposes a method for that.

The settings are valid while the object exists and are automatically restored when destroyed.
