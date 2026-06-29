<h1 align="center">Quorum</h1>

<p align="center"><b>Snap your pharmacy bill. A committee of AI agents finds cheaper generics while retaining your safety by catching the unsafe swaps.</b></p>

<p align="center"><i>Built for the Cerebras × Google DeepMind Gemma 4 Hackathon · powered by Gemma 4 31B on Cerebras.</i></p>

---

## What it is
Indians overpay for medicine every day, even though cheaper generic variants with the exact same active ingredient usually exist. Apps that suggest generic medication already exist; however, they make you type the name of the drug in. Most importantly, they fail to inform you when a swap is unsafe.

**Quorum** reads a photographed pharmaceutical invoice with Gemma 4 vision, matches each medicine to cheaper generic equivalents from an official price catalogue, and then runs a **committee of Gemma 4 agents** that independently verify every substitution, returning the cheaper option with a confidence score and flagging anything dangerous.

## On one real rheumatoid-arthritis bill

- **Read 12 / 12 line items** from a photo in ~1.3s (Gemma 4 vision).
- **₹1,781 in surfaced savings** across the bill.
- **Blocked a dangerous swap** a pregabalin-only line that the matcher had matched to a pregabalin **+ nortriptyline** combination (an extra active ingredient).
- **Flagged methotrexate** as a narrow-therapeutic-index drug needing doctor supervision.

## Why it's different

The price-matcher is deterministic and precise (same salt, strength, and form). On top of it sits a multi-agent verification layer:

- **Four method-diverse Gemma 4 agents** judge each substitution from different angles: **identity** (is the drug correctly read?), **formulation** (route / modified-release / salt form), **clinical** (narrow-therapeutic-index, prescription status), and a **skeptic** critically evaluating the swap.
- **Monotonic constraint:** the committee can only ever add caution. Lower the confidence rating, raise a flag, or say "ask a pharmacist." It can never override the database, invent a drug, or change a price. So a hallucinated caution is a safe failure.
- Verdicts are **reproducible** (temperature 0) and verification only runs where it matters (non-exact matches, prescription-only, or narrow-therapeutic-index drugs).

Running a whole committee *per line item* in real time is only practical because of Cerebras' inference speed.

## Multimodal + speed, on the same model

Gemma 4 31B is multimodal — it reads the receipt image directly (no separate OCR engine). And because the app can route the *same* `gemma-4-31b` model to either provider, the speed difference is purely the hardware:

| Same model, same bill | End-to-end |
|---|---|
| **Gemma 4 31B on Cerebras** (wafer-scale) | **~1.3 s** |
| Gemma 4 31B on Google AI Studio (GPU/TPU) | ~24.1 s |

**Roughly 18× faster with the same model, only the silicon changes.** ([code/bench_hardware.py](code/bench_hardware.py) reproduces it; the app has an in-app engine switch to show it live.)

## Architecture

We capture the bill, with the choice between on device OCR or opt in cloud scanning via Gemma 4's vision. The items given have detailed reasoning on the confidence rating, allowing the user to make informed choices. The backend consists of an SQLite database with strict input validation, read-only DB, and no content logging.

- **Data:** ~248k-row open Indian Medicine Dataset + **official Jan Aushadhi (PMBJP) prices** + OpenStreetMap pharmacies, in SQLite.
- **Safety:** Schedule H / H1 / X classification reconciled against the official Drugs & Cosmetics Rules gazette.
- **Privacy:** by default the photo is OCR'd **on-device** and never uploaded, with only the extracted text being sent. Cloud OCR (Gemma 4 vision) is an explicit opt-in.
- **API:** TLS + HMAC-signed requests, strict input validation, read-only DB, no content logging.

## Tech stack

Flutter (Dart) · Python **standard library only** (no pandas, no heavy deps) · SQLite · Gemma 4 31B on Cerebras (OpenAI-compatible API, structured outputs, `reasoning_effort`) · OpenStreetMap.

## Run it

**Offline demo (no API key):**
```bash
python3 code/quorum_demo.py --mock      # committee on sample cases, fully offline
```

**Live (needs a Cerebras key):**
```bash
export CEREBRAS_API_KEY=...
# Build the catalogue once (open data):
mkdir -p data/raw && curl -L -o data/raw/indian_medicine_data.csv \
  https://raw.githubusercontent.com/junioralive/Indian-Medicine-Dataset/main/DATA/indian_medicine_data.csv
python3 code/ingest.py && python3 code/ingest_janaushadhi.py && \
  python3 code/ingest_pharmacies.py && python3 code/recompute_schedule.py

python3 code/quorum_demo.py             # live committee verdicts
python3 code/scan_demo.py pharm_5       # end-to-end: image → Gemma 4 OCR → matcher → quorum
```

**Backend + app:**
```bash
python3 code/gen_secrets.py             # dev API key + self-signed TLS cert
B2G_HOST=0.0.0.0 python3 code/server.py # HTTPS API on :8443
cd code/app && flutter run \
  --dart-define=B2G_API_URL=https://<your-LAN-ip>:8443 \
  --dart-define=B2G_API_KEY=<keyid> --dart-define=B2G_API_SECRET=<secret>
```

**Hardware speed comparison:**
```bash
export CEREBRAS_API_KEY=... GOOGLE_API_KEY=...
python3 code/bench_hardware.py --no-local    # Cerebras vs Google, same model
```

## Repo layout

```
code/
  b2g/          backend package: matcher, schedule safety, pipeline, cerebras client, quorum, vlm_ocr
  app/          Flutter app (iOS + Android)
  server.py     secure HTTPS API
  *_demo.py     CLI demos (quorum, end-to-end scan, hardware benchmark)
  ocr_bench/    on-device OCR engine benchmark
data/           SQLite catalogue (built from open data; gitignored)
```

## Safety & disclaimer

Quorum is decision **support**, not medical advice. Prices are estimates from public catalogues. Confirm with your pharmacist before purchasing. Substituting a generic is a decision for you and your doctor; the app deliberately flags prescription-only and narrow-therapeutic-index drugs for professional review.

## Credits

Built with **Gemma 4 31B** running on **Cerebras** for the Cerebras × Google DeepMind Gemma 4 Hackathon. Drug data from the open Indian Medicine Dataset and the Government of India's Jan Aushadhi (PMBJP) catalogue; pharmacy locations from OpenStreetMap.

Licensed under the **PolyForm Noncommercial License 1.0.0** — free for noncommercial use (study, research, personal projects); **commercial use requires permission from the author**. See [LICENSE](LICENSE).
