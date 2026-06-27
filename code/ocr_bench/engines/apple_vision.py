"""Apple Vision (VNRecognizeTextRequest) via a compiled Swift helper.

On-device, free, built into macOS — our proxy for the iOS lightweight OCR tier.
No Python deps; needs the Swift toolchain (present with Xcode)."""

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from engines import Engine

_BENCH_DIR = Path(__file__).resolve().parent.parent
_SWIFT_SRC = _BENCH_DIR / "vision_ocr.swift"
_BIN = _BENCH_DIR / ".bin" / "vision_ocr"


class AppleVision(Engine):
    name = "apple_vision"

    def _ensure_binary(self):
        if _BIN.exists() and _BIN.stat().st_mtime >= _SWIFT_SRC.stat().st_mtime:
            return None
        _BIN.parent.mkdir(parents=True, exist_ok=True)
        proc = subprocess.run(
            ["swiftc", "-O", str(_SWIFT_SRC), "-o", str(_BIN)],
            capture_output=True, text=True,
        )
        if proc.returncode != 0:
            return f"swiftc failed: {proc.stderr.strip()[:300]}"
        return None

    def available(self):
        if shutil.which("swiftc") is None:
            return False, "swiftc not on PATH (install Xcode command line tools)"
        err = self._ensure_binary()
        if err:
            return False, err
        return True, "ok"

    def ocr_batch(self, image_paths):
        err = self._ensure_binary()
        if err:
            raise RuntimeError(err)
        fd, out_json = tempfile.mkstemp(suffix=".json")
        os.close(fd)
        try:
            proc = subprocess.run(
                [str(_BIN), out_json, *map(str, image_paths)],
                capture_output=True, text=True,
            )
            if proc.returncode != 0:
                raise RuntimeError(f"vision_ocr failed: {proc.stderr.strip()[:300]}")
            rows = json.loads(Path(out_json).read_text())
        finally:
            os.unlink(out_json)
        by_path = {r["image"]: r for r in rows}
        out = []
        for p in map(str, image_paths):
            r = by_path.get(p, {"text": "", "seconds": -1.0})
            out.append({"text": r.get("text", ""), "seconds": float(r.get("seconds", -1.0))})
        return out
