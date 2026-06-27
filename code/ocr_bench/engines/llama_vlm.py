"""Quantized OCR VLMs via llama.cpp's multimodal runner (`llama-mtmd-cli`).

This is the path Aarav chose: quantized decoder + fp16 vision/mmproj projector.
`-hf <repo>` auto-downloads the model GGUF *and* its mmproj. No torch/Python needed.
Quant = whatever each repo publishes: the OCR specialists ship **Q8_0** (8-bit),
moondream/granite ship f16. (Q4 isn't published for most OCR VLMs — 8-bit is the
real on-device point for these.)

Each model is a ~2-line subclass (HF repo + OCR prompt). Prompts differ per model —
OCR VLMs are trained with specific prompt strings (see llama.cpp multimodal docs).

Latency reported = llama.cpp's own "total time" (prompt eval + generation), parsed from
stderr, so model-load time is excluded. RAM is captured by run_engine via child rusage.
"""

import re
import shutil
import subprocess
import time

from engines import Engine

_TOTAL_RE = re.compile(r"total time =\s*([\d.]+) ms")


class _LlamaVLM(Engine):
    requires_venv = False
    heavy = True            # big VLMs: scheduler runs them one at a time
    HF_REPO = ""
    QUANT = None            # None = use the repo's published quant (Q8_0 / f16)
    PROMPT = "OCR"
    N_PREDICT = 4096        # receipts -> long markdown tables; give headroom

    def available(self):
        if shutil.which("llama-mtmd-cli") is None:
            return False, "llama-mtmd-cli not on PATH (brew install llama.cpp)"
        if not self.HF_REPO:
            return False, "no HF repo configured"
        return True, "ok"

    def ocr_batch(self, image_paths):
        hf_arg = f"{self.HF_REPO}:{self.QUANT}" if self.QUANT else self.HF_REPO
        out = []
        for p in map(str, image_paths):
            cmd = ["llama-mtmd-cli", "-hf", hf_arg, "--image", p,
                   "-p", self.PROMPT, "-ngl", "99", "--temp", "0.0",
                   "-n", str(self.N_PREDICT), "--jinja"]  # OCR VLMs use custom chat templates
            t0 = time.perf_counter()
            proc = subprocess.run(cmd, capture_output=True, text=True)
            wall = time.perf_counter() - t0
            text = (proc.stdout or "").strip()
            m = _TOTAL_RE.search(proc.stderr or "")
            secs = (float(m.group(1)) / 1000.0) if m else wall
            out.append({"text": text, "seconds": secs})
        return out


# ── Models (user's wide set that has a GGUF) + high-value extras ──────────────
class Moondream(_LlamaVLM):
    name = "moondream"  # VQA model, not a doc-OCR specialist — included per request
    heavy = False
    HF_REPO = "ggml-org/moondream2-20250414-GGUF"
    PROMPT = "Transcribe all the text in this image."


class DeepSeekOCR(_LlamaVLM):
    name = "deepseek_ocr"
    HF_REPO = "ggml-org/DeepSeek-OCR-GGUF"
    PROMPT = "Free OCR."  # plain text; grounding mode emits bbox coords we don't want


class DotsOCR(_LlamaVLM):
    name = "dots_ocr"
    HF_REPO = "ggml-org/dots.ocr-GGUF"
    PROMPT = "OCR"


class UnlimitedOCR(_LlamaVLM):
    name = "unlimited_ocr"
    HF_REPO = "sahilchachra/Unlimited-OCR-GGUF"  # community (no ggml-org repo)
    PROMPT = "OCR"


class GLMOCR(_LlamaVLM):
    name = "glm_ocr"  # 0.9B-class OCR VLM (the middle tier)
    heavy = False
    HF_REPO = "ggml-org/GLM-OCR-GGUF"
    PROMPT = "OCR markdown"


class HunyuanOCR(_LlamaVLM):
    name = "hunyuan_ocr"
    HF_REPO = "ggml-org/HunyuanOCR-GGUF"
    PROMPT = "OCR"


class GraniteDocling(_LlamaVLM):
    name = "granite_docling"  # 258M — tiny, 4GB-tier candidate (project TODO)
    heavy = False
    HF_REPO = "ggml-org/granite-docling-258M-GGUF"
    QUANT = None
    PROMPT = "Convert this page to docling."


class QianfanOCR(_LlamaVLM):
    name = "qianfan_ocr"  # Baidu Qianfan OCR
    HF_REPO = "ggml-org/Qianfan-OCR-GGUF"
    PROMPT = "OCR"
