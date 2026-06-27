"""OCR engine registry for the benchmark.

Each engine is a small adapter exposing a uniform interface so the harness can run
and score them identically. IMPORTANT: engine modules must do their heavy imports
(torch, mlx, paddle, ...) *inside* methods, never at module top — so importing this
package stays cheap and a missing/broken dependency degrades to available()=False
instead of crashing the whole benchmark.
"""

from importlib import import_module


class Engine:
    name = "base"
    # Big-RAM engines (VLMs): the scheduler runs these one at a time.
    heavy = False
    # True -> run this engine's subprocess under the dedicated VLM venv python.
    requires_venv = False

    def available(self):
        """Return (ok: bool, reason: str). reason explains why if not ok."""
        return False, "base engine"

    def ocr_batch(self, image_paths):
        """Return a list aligned with image_paths: [{"text": str, "seconds": float}].

        `seconds` is the engine's own inference time per image (model load may be
        folded into the first image). Process startup is excluded where possible."""
        raise NotImplementedError


# name -> "module:ClassName"  (kept as strings so we never eagerly import heavy deps)
_ENGINES = {
    # Stage 1 — zero/low install, run today
    "apple_vision": "apple_vision:AppleVision",
    "tesseract": "tesseract:Tesseract",
    # Stage 2 — desktop PaddleOCR PP-OCRv5 (Paddle venv; adapter TBD)
    "paddleocr": "paddleocr:PaddleOCRv5",
    # Stage 3 — quantized OCR VLMs via llama.cpp (GGUF Q4 + fp16 mmproj; no venv)
    "moondream": "llama_vlm:Moondream",
    "deepseek_ocr": "llama_vlm:DeepSeekOCR",
    "dots_ocr": "llama_vlm:DotsOCR",
    "unlimited_ocr": "llama_vlm:UnlimitedOCR",
    "glm_ocr": "llama_vlm:GLMOCR",
    "hunyuan_ocr": "llama_vlm:HunyuanOCR",
    "granite_docling": "llama_vlm:GraniteDocling",
    "qianfan_ocr": "llama_vlm:QianfanOCR",
    # Stage 3b — torch path (need venv: --venv code/ocr_bench/.venv/bin/python)
    "docling": "docling_engines:DoclingStandard",       # full Docling pipeline
    "granite_docling_full": "docling_engines:DoclingGranite",  # unquantized 258M VLM
    "got_ocr2": "got_ocr2:GOTOCR2",
    "mineru": "mineru:MinerU",
    "paddleocr_vl": "paddleocr_vl:PaddleOCRVL",
}


def all_names():
    return list(_ENGINES.keys())


def get_engine(name):
    if name not in _ENGINES:
        raise KeyError(f"unknown engine {name!r}; known: {', '.join(_ENGINES)}")
    mod_name, cls_name = _ENGINES[name].split(":")
    mod = import_module(f"engines.{mod_name}")
    return getattr(mod, cls_name)()
