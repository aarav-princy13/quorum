"""Minimal Cerebras (Gemma 4) client over the stdlib only — no SDK, no deps.

The Cerebras Inference API is OpenAI-compatible, so a plain HTTPS POST with the
standard chat-completions body is all we need. Keeping this dependency-free
honours the backend's "stdlib only, no heavy deps" rule.

Supports: text + image (OpenAI `image_url`) input, strict Structured Outputs
(`response_format` json_schema), reasoning_effort, and per-request timing.

Set CEREBRAS_API_KEY to use it. No key (or CEREBRAS_MOCK=1) -> callers use mock.
"""

import base64
import json
import os
import time
import urllib.error
import urllib.request

API_URL = "https://api.cerebras.ai/v1/chat/completions"
MODEL_ID = "gemma-4-31b"
API_KEY_ENV = "CEREBRAS_API_KEY"
MAX_OUTPUT_TOKENS = 1024


def have_key():
    return bool(os.environ.get(API_KEY_ENV))


def image_part(b64, mime="image/jpeg"):
    """OpenAI multimodal content part from an already-base64 image string."""
    return {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}}


def encode_image(path):
    """Return an OpenAI multimodal content part for a local image file."""
    with open(path, "rb") as fh:
        data = base64.b64encode(fh.read()).decode("ascii")
    ext = (os.path.splitext(path)[1].lstrip(".") or "png").lower()
    if ext == "jpg":
        ext = "jpeg"
    return image_part(data, f"image/{ext}")


def build_messages(system_prompt, user_text, image_part=None):
    """Compose a chat message list, optionally multimodal."""
    if image_part is not None:
        user_content = [{"type": "text", "text": user_text}, image_part]
    else:
        user_content = user_text
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_content},
    ]


def complete(messages, schema=None, reasoning_effort="none",
             temperature=0.0, model=MODEL_ID, max_tokens=MAX_OUTPUT_TOKENS, timeout=60):
    # temperature=0: OCR and verification want the SAME answer every run. Sampling
    # (temp>0) makes reads of a hard/blurry image vary run-to-run, which the fuzzy
    # matcher then amplifies into different prices. Committee diversity comes from the
    # distinct lens prompts, not from sampling, so 0 is correct there too.
    """One chat completion. Returns (text, meta).

    meta = {"usage", "time_info", "latency_s"}. Raises RuntimeError on HTTP error
    (with the server's message) so failures are loud, not silent.
    """
    key = os.environ.get(API_KEY_ENV)
    if not key:
        raise RuntimeError(f"{API_KEY_ENV} not set (use mock mode offline).")

    body = {
        "model": model,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }
    # Off is the default; only send when actually enabling reasoning ("none" can 400).
    if reasoning_effort in ("low", "medium", "high"):
        body["reasoning_effort"] = reasoning_effort
    if schema is not None:
        body["response_format"] = {
            "type": "json_schema",
            "json_schema": {"name": "verdict", "strict": True, "schema": schema},
        }

    req = urllib.request.Request(
        API_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            # Cloudflare (error 1010) bans the default "Python-urllib/x" UA; set our own.
            "User-Agent": "brand-to-generic-quorum/1.0",
        },
        method="POST",
    )
    t0 = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.load(resp)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:400]
        raise RuntimeError(f"Cerebras HTTP {exc.code}: {detail}") from None
    latency = round(time.monotonic() - t0, 3)

    text = data["choices"][0]["message"]["content"]
    meta = {"usage": data.get("usage"), "time_info": data.get("time_info"),
            "latency_s": latency}
    return text, meta


def extract_json(text):
    """Pull the first JSON object from a reply (tolerates fences / stray prose)."""
    if not text:
        raise ValueError("empty reply")
    # With reasoning on, some models prepend a <think>…</think> block — drop it so
    # a stray '{' in the reasoning can't derail parsing of the real JSON answer.
    if "</think>" in text:
        text = text.rsplit("</think>", 1)[-1]
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end <= start:
        raise ValueError(f"no JSON object in reply: {text[:80]!r}")
    return json.loads(text[start:end + 1])
