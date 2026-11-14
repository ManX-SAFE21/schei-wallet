"""
bal.qml
=======

Entry point of the Àncòra plugin for the Schȅi (QML, Android) app.

For now the QML front-end uses the same headless plugin as the command line
(bal.cli.plugin): every inheritance page of Schȅi calls the bal_*
commands, so the logic is exactly the one of the desktop plugin. The Schȅi
pages (QML) and their bridge object come in a later step.

Schȅi ships the plugin as an internal plugin (electrum/plugins/bal), so a
normal relative import is enough here (no zip loading on Android).
"""

from .cli.plugin import Plugin  # noqa: F401  (re-exported for Electrum)
