"""Opt-in cloud OCR: read a pharmacy receipt image with Gemma 4 vision on Cerebras.

This is the MULTIMODAL, opt-in path. The product's DEFAULT remains on-device OCR
(privacy: image never leaves the phone). This cloud path is offered explicitly for
high accuracy / low-end devices, and powers the hackathon end-to-end demo.

Output matches the on-device parser: a list of {"name", "qty"} line items, fed
straight into the existing matcher/pipeline. Stdlib only (via b2g.cerebras).
"""

import json
from pathlib import Path

from . import cerebras

CODE_DIR = Path(__file__).resolve().parent.parent
OCR_SAMPLES = CODE_DIR / "ocr_samples"

RECEIPT_SCHEMA = {
    "type": "object",
    "properties": {
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "qty": {"type": "integer"},
                },
                "required": ["name", "qty"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["items"],
    "additionalProperties": False,
}

OCR_SYSTEM = (
    "You read photographed Indian pharmacy receipts. Extract ONLY medication line items. "
    "For each, return the product name exactly as printed (brand + strength + form, e.g. "
    "'Glycomet 500 SR Tablet') and the quantity. IGNORE non-medicine lines: totals, taxes, "
    "discounts, consultation/delivery charges, batch/expiry/HSN columns, headers and footers. "
    "If quantity is unclear, use 1. Return ONLY JSON: {\"items\":[{\"name\":...,\"qty\":...}]}."
)


def _ocr(image_part, complete=None):
    """Run Gemma 4 vision over an image content part. Returns (items, meta)."""
    complete = complete or (lambda m, schema: cerebras.complete(m, schema=schema))
    messages = cerebras.build_messages(
        OCR_SYSTEM, "Extract the medication line items from this receipt.", image_part)
    text, meta = complete(messages, RECEIPT_SCHEMA)
    return cerebras.extract_json(text).get("items", []), meta


def ocr_receipt(image_path, complete=None):
    """Live: read a local image file with Gemma 4 vision. Returns (items, meta)."""
    return _ocr(cerebras.encode_image(str(image_path)), complete)


def ocr_receipt_b64(b64, mime="image/jpeg", provider="cerebras"):
    """Read a base64 image with Gemma 4 vision on the chosen provider.

    provider 'cerebras' (default) or 'google' (same gemma-4-31b model, different
    hardware) — powers the in-app speed switch. Returns (items, meta) with
    meta['provider'] and meta['latency_s'].
    """
    part = cerebras.image_part(b64, mime)
    messages = cerebras.build_messages(
        OCR_SYSTEM, "Extract the medication line items from this receipt.", part)
    if provider == "google":
        key = cerebras.google_key()
        if not key:
            raise RuntimeError("GOOGLE_API_KEY not set")
        # Gemini's OpenAI-compat layer is flaky with strict json_schema, so use the
        # looser json_object mode (the prompt already asks for a JSON object).
        text, meta = cerebras.complete(messages, schema=None, json_object=True,
                                       base_url=cerebras.GOOGLE_BASE_URL, api_key=key,
                                       model=cerebras.GOOGLE_MODEL, max_tokens=2048)
    else:
        text, meta = cerebras.complete(messages, schema=RECEIPT_SCHEMA, max_tokens=2048)
    meta = dict(meta or {})
    meta["provider"] = provider
    return cerebras.extract_json(text).get("items", []), meta


def gold_items(receipt_id):
    """Human-verified line items for a sample receipt (offline mock / accuracy check)."""
    path = OCR_SAMPLES / f"{receipt_id}.json"
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    return [{"name": it["name"], "qty": it.get("qty", 1)} for it in data.get("items", [])]
