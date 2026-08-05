import pytest
import importlib.util
import os
from pathlib import Path
from urllib.parse import urlparse

os.environ.setdefault("IMAGE_ROBOT_DATA_DIR", "/tmp/contentglows-test-images")
os.environ.setdefault("IMAGE_ROBOT_TEMP_DIR", "/tmp/contentglows-test-images-tmp")

_TOOLS_PATH = Path(__file__).resolve().parents[1] / "agents" / "images" / "tools" / "bunny_cdn_tools.py"
_SPEC = importlib.util.spec_from_file_location("bunny_cdn_tools_under_test", _TOOLS_PATH)
bunny_cdn_tools = importlib.util.module_from_spec(_SPEC)
assert _SPEC and _SPEC.loader
_SPEC.loader.exec_module(bunny_cdn_tools)


def test_remote_image_download_rejects_loopback_url():
    with pytest.raises(ValueError, match="non-public"):
        bunny_cdn_tools._validate_public_remote_url("http://127.0.0.1/image.png")


def test_remote_image_download_rejects_non_image_content(monkeypatch):
    class Response:
        headers = {"Content-Type": "text/html"}

        def raise_for_status(self):
            return None

        def iter_content(self, chunk_size):
            yield b"<html></html>"

    monkeypatch.setattr(
        bunny_cdn_tools,
        "_validate_public_remote_url",
        lambda source: urlparse(source),
    )
    monkeypatch.setattr(
        bunny_cdn_tools.requests,
        "get",
        lambda source, timeout, stream: Response(),
    )

    with pytest.raises(ValueError, match="Unsupported remote image"):
        bunny_cdn_tools._download_remote_image("https://cdn.example.com/not-image")
