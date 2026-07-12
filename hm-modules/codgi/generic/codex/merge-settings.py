from collections.abc import MutableMapping
from pathlib import Path
import os
import sys
import tempfile

import tomlkit

config_path = Path(sys.argv[1])
static_path = Path(sys.argv[2])
config_path.parent.mkdir(parents=True, exist_ok=True)

if config_path.is_symlink():
    config_path.unlink()

dynamic = tomlkit.parse(config_path.read_text()) if config_path.exists() else tomlkit.document()
static = tomlkit.parse(static_path.read_text())


def merge(dynamic, static):
    for key, static_value in static.items():
        dynamic_value = dynamic.get(key)
        if isinstance(dynamic_value, MutableMapping) and isinstance(static_value, MutableMapping):
            merge(dynamic_value, static_value)
        else:
            dynamic[key] = static_value


merge(dynamic, static)
with tempfile.NamedTemporaryFile(
    mode="w", encoding="utf-8", dir=config_path.parent, prefix=".config.toml.", delete=False
) as temporary_file:
    temporary_file.write(tomlkit.dumps(dynamic))
    temporary_path = temporary_file.name

os.chmod(temporary_path, 0o600)
os.replace(temporary_path, config_path)
