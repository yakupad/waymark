import sys
from pathlib import Path

# Make `waymark_pack` importable when pytest is run from the repo root or from tools/.
TOOLS = Path(__file__).resolve().parent.parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import pytest

from waymark_pack import config as config_mod


@pytest.fixture
def tr_config():
    return config_mod.load(TOOLS / "config" / "tr.toml")
