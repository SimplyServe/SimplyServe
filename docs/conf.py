from datetime import datetime

project = "SimplyServe"
author = "SimplyServe Team"
copyright = "2026, Team 2D"
release = "1.0"

extensions = [
    "myst_parser",
]

templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

html_theme = "furo"
html_static_path = ["_static"]

source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}
