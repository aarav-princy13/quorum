"""Tesseract 5 (LSTM) via the CLI — classic open-source CPU OCR baseline.

No Python dep; calls the `tesseract` binary. Uses `eng` (all our gold drug names
are Latin). Add `-l eng+hin` once hin.traineddata is installed for Devanagari trials."""

import shutil
import subprocess
import time

from engines import Engine


class Tesseract(Engine):
    name = "tesseract"

    def available(self):
        if shutil.which("tesseract") is None:
            return False, "tesseract not on PATH (brew install tesseract)"
        langs = subprocess.run(["tesseract", "--list-langs"],
                               capture_output=True, text=True).stdout
        if "eng" not in langs:
            return False, "tesseract 'eng' language data missing"
        return True, "ok"

    def ocr_batch(self, image_paths):
        out = []
        for p in map(str, image_paths):
            t0 = time.perf_counter()
            proc = subprocess.run(
                ["tesseract", p, "stdout", "-l", "eng", "--oem", "1", "--psm", "6"],
                capture_output=True, text=True,
            )
            dt = time.perf_counter() - t0
            text = proc.stdout if proc.returncode == 0 else ""
            out.append({"text": text, "seconds": dt})
        return out
