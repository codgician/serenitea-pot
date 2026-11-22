from pathlib import Path
import json
import os
import sys
import tempfile

import json5

config_path = Path(sys.argv[1])
static = json.loads(Path(sys.argv[2]).read_text())
config_path.parent.mkdir(parents=True, exist_ok=True)

if config_path.is_symlink():
    config_path.unlink()

# Antigravity creates some of these files empty; the IDE's settings may hold comments.
text = config_path.read_text() if config_path.exists() else ""
dynamic = json5.loads(text) if text.strip() else {}


def merge(dynamic, static):
    for key, static_value in static.items():
        dynamic_value = dynamic.get(key)
        if isinstance(dynamic_value, dict) and isinstance(static_value, dict):
            merge(dynamic_value, static_value)
        else:
            dynamic[key] = static_value


merge(dynamic, static)
with tempfile.NamedTemporaryFile(
    mode="w", encoding="utf-8", dir=config_path.parent, prefix=f".{config_path.name}.", delete=False
) as temporary_file:
    json.dump(dynamic, temporary_file, indent=2)
    temporary_file.write("\n")
    temporary_path = temporary_file.name

os.chmod(temporary_path, 0o600)
os.replace(temporary_path, config_path)
