# DESIGN.md — brand_to_generic app

**Date:** 2026-06-25 · The authoritative design spec for the Flutter app. The scaffolding
session should implement this verbatim (and may copy it to `code/app/DESIGN.md`).

## Design read (register)
A health **utility** for cost-conscious Indian patients: scan a pharmacy receipt → see cheaper
generics + prescription/abuse safety flags + nearby pharmacies. **Product register** — design
serves the task, calm/clinical/trustworthy, not a brand showcase. Reference aesthetic: shadcn/ui
(neutral, precise) with **one** restrained brand accent.

## Decisions (locked 2026-06-25)
- **Aesthetic:** neutral surfaces + **one brand accent (indigo)**; color otherwise = meaning only.
- **Theme:** **light default, full dark support.**
- **Latin type:** **Geist** (OFL) — bundled as an asset (offline; no runtime font fetch). Closest
  free match to Claude desktop's Anthropic Sans.
- **Devanagari type (Hindi, later):** **Noto Sans Devanagari** (OFL) — bundled.
- **Flutter UI kit:** **`shadcn_ui`** (pub.dev). `forui` is the fallback.
- **App location:** `code/app/`.

## Color tokens (implement as the single source of truth in `theme/`)
Surfaces are a near-neutral off-white — **NOT** the AI cream/beige (impeccable ban). Warmth comes
from type + accent, not the background. Hex is ARGB-ready for Flutter `Color(0xFF……)`.

| Role | Light | Dark | Use |
|------|-------|------|-----|
| surface-0 (page) | `#FBFBFA` | `#161618` | app background |
| surface-1 (inset/section) | `#F4F4F2` | `#1D1D20` | grouped sections, summary strip |
| surface-2 (card) | `#FFFFFF` | `#232327` | cards, sheets |
| text-primary (ink) | `#1B1B1A` | `#F3F3F1` | headings, values |
| text-secondary | `#5C5C57` | `#A6A6A0` | composition, supporting |
| text-muted | `#8E8E88` | `#76766F` | captions, hints |
| border | `#E7E7E3` | `#2D2D30` | 0.5px hairlines, row dividers |
| border-strong | `#D5D5D0` | `#3A3A3E` | secondary button, emphasis |
| **primary (indigo)** | `#4F46E5` | `#6366F1` | primary action, links, active |
| primary-hover | `#4338CA` | `#818CF8` | pressed/hover |
| on-primary | `#FFFFFF` | `#FFFFFF` | text on primary |
| primary-tint (bg) | `#EEEFFB` | `#25254A` | brand chips, selected rows |
| primary-on-tint | `#3730A3` | `#A5B4FC` | text on primary-tint |
| **success (savings)** text/bg/solid | `#3B6D11` / `#EAF3DE` / `#5C8A1E` | `#A7D17A` / `#1E2A12` / `#7FB23C` | savings %, Jan Aushadhi |
| **warning (Rx · H · H1)** text/bg/solid | `#8A5108` / `#FAEEDA` / `#BA7517` | `#E6B26A` / `#2E2410` / `#D79A3C` | prescription-only |
| **danger (Schedule X · strict)** text/bg/solid | `#A32D2D` / `#FBEBEB` / `#DC4B4B` | `#F08F8F` / `#2E1414` / `#E24B4A` | strictest + safety callout |

Contrast: body ≥4.5:1, large ≥3:1. Text on a colored chip uses that family's dark stop (never black/gray).

## Typography
- **Geist** (Latin) + **Noto Sans Devanagari** as fallback family, weights **400 / 500 / 600** only.
- Tighten display/title with `letter-spacing: -0.01em`. Sentence case everywhere; no ALL CAPS.
- Scale (Flutter `TextTheme`): savings figure 34–36/600 · screen title 16–17/500 · body 15/400 ·
  supporting 13/400 · caption 11–12/400. Body line-height ~1.4–1.5.

## Components & patterns
- **List rows, not cards.** Receipt line items are dense **bordered rows** (0.5px top divider,
  ~14×16 padding), never one card per item, never nested cards.
- **Badge family** (radius 6–7): `Rx only` (warning), `Schedule X` (danger), `save NN%` (success),
  `Jan Aushadhi` (success + check), brand chip (primary-tint).
- **Safety callout** (H1/X): tinted block (warning/danger bg), icon + 2 lines, with a "confirm you
  hold a prescription" action. A first-class element, never a side-stripe border.
- **Buttons:** primary = indigo fill + on-primary; secondary = surface-2 + border-strong; ghost =
  transparent. Radius ~10. One primary per view.
- **Cards** only to group a section (e.g. nearby pharmacies): surface-2, 12px radius, 0.5px border.
- **Not-found item** = quiet, honest ("couldn't identify — check manually"), never a wrong guess.

## Motion
Intentional, ease-out (quart/expo), 150–250ms. List items may stagger on first load. **Honor
`prefers-reduced-motion`** (crossfade/instant fallback). No bounce/elastic, no gratuitous loops.

## Absolute bans (from impeccable — do not ship these)
Gradients, gradient text, glassmorphism-as-default, side-stripe borders, hero-metric template,
identical card grids, tiny uppercase tracked eyebrows, numbered section scaffolding (01/02/03),
AI cream/beige body bg, text that overflows its container. **AI-slop test:** if it reads as
"an AI made this," rework it.

## Screen inventory (scaffold these)
1. **Capture** — camera + "Scan receipt" (primary). Privacy line: image stays on device.
2. **Analyzing** — on-device OCR running (skeleton/spinner).
3. **Results** — the mockup: savings summary → bordered item rows (composition, savings, Rx/safety
   badges, cheaper option + Jan Aushadhi anchor) → safety callouts → nearby pharmacies → "Scan
   another". Disclaimer footer.
4. **Item detail** — full alternatives list, Jan Aushadhi price, nearby for that item.
5. **Nearby pharmacies** — distance-ranked list (+ map later).
6. **Settings** — language (English/Hindi later), privacy, about.

## Prerequisites (checked 2026-06-25)
- **Flutter SDK is NOT installed** — the scaffolding session must install it first:
  `brew install --cask flutter` (then `flutter doctor`), or https://docs.flutter.dev/get-started/install/macos.
- **Xcode 27.0 present** (iOS builds OK). Test devices: iPhone 13 + 15; Android device TBD.
  Free Apple ID is enough for on-device testing; paid Developer account only for TestFlight/App Store.

## Flutter implementation notes
- `code/app/` Flutter project. `pubspec.yaml`: `shadcn_ui`, `google_mlkit_text_recognition`
  (on-device OCR), `crypto` (HMAC for the API client), `http`, `camera`/`image_picker`,
  `geolocator` (nearby), `flutter_riverpod` or `provider` for state.
- **Fonts as assets:** bundle Geist (Regular/Medium/SemiBold) + NotoSansDevanagari under
  `assets/fonts/`; declare in `pubspec.yaml`; set `fontFamily: 'Geist'` with NotoSansDevanagari
  fallback. (No `google_fonts` runtime fetch — keep offline.)
- **Theme:** map the tokens above into `ShadThemeData` (shadcn_ui) light + dark color schemes.
  One file (`theme/tokens.dart` + `theme/app_theme.dart`) is the source of truth.
- **API client** (`services/api.dart`): port `code/client_example.py` HMAC signing —
  `HMAC-SHA256(secret, "POST\n/v1/analyze\n<ts>\n<nonce>\n<sha256(body)>")`, headers
  `X-Api-Key / X-Timestamp / X-Nonce / X-Signature`; verify the real TLS cert in prod.
- **Privacy:** receipt image is OCR'd on-device; only extracted text is sent. Never upload the image.
- Build mock-data-first (use the benchmark fixtures / a sample result), then wire OCR → API.

## Design assets / skills installed (this session)
- `impeccable` (`/impeccable`) and `taste-skill`'s sub-skills (`/minimalist-ui`, `/soft-skill`,
  `redesign`, `brandkit`, …) installed at `~/.claude/skills/`. **Web-oriented** (the *principles*
  transfer to Flutter; the code-gen/hooks don't). The impeccable per-edit hook was **disabled** for
  this repo (`.claude/settings.local.json`) — re-enable with `npx impeccable install --scope=project`.
- Reference mockups were rendered in-chat this session (receipt-results screen + style tile +
  accent/Hindi comparison); reproduce their look in Flutter.
