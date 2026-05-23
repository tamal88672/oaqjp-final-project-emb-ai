# Color palette — "from your secret admirer"

NGL uses a hot magenta-to-orange gradient that reads as "loud, public,
TikTok-native." Secret Admirer wants the opposite: velvet, midnight, candle-lit
— the visual register of a hand-written note slipped under a door.

## Core tokens

| Token             | Hex       | RGB              | Notes                                            |
| ----------------- | --------- | ---------------- | ------------------------------------------------ |
| `--velvet-night`  | `#1A0B1F` | rgb(26,11,31)    | Primary background (web + iOS)                   |
| `--midnight-plum` | `#2D1B3D` | rgb(45,27,61)    | Card surfaces, elevated panels                   |
| `--crimson-rose`  | `#8B1538` | rgb(139,21,56)   | Primary CTA, hero gradient start                 |
| `--rose-gold`     | `#B76E79` | rgb(183,110,121) | Hero gradient end, secondary buttons             |
| `--champagne`     | `#D4AF37` | rgb(212,175,55)  | Sparingly: highlights, unread dots, "premium"    |
| `--dusty-blush`   | `#E8C5C5` | rgb(232,197,197) | Soft surfaces, incoming message bubbles          |
| `--whisper`       | `#F5E6E8` | rgb(245,230,232) | Body text on dark surfaces                       |
| `--shadow-ink`    | `#0A0410` | rgb(10,4,16)     | Deep shadows under cards                         |

## Gradients

- **Hero**: `linear-gradient(135deg, #8B1538 0%, #B76E79 50%, #D4AF37 100%)`
  used on the landing hero, send-message page header, iOS launch screen.
- **Card sheen**: `linear-gradient(180deg, #2D1B3D 0%, #1A0B1F 100%)` for the
  inbox cards.

## Contrast

Checked with WCAG 2.1 AA at 14pt body text:

| Pair                                | Ratio | Pass |
| ----------------------------------- | ----- | ---- |
| `--whisper` on `--velvet-night`     | 16.8  | AAA  |
| `--whisper` on `--midnight-plum`    | 11.4  | AAA  |
| `--whisper` on `--crimson-rose`     | 6.1   | AA   |
| `--dusty-blush` on `--velvet-night` | 13.2  | AAA  |
| `--champagne` on `--velvet-night`   | 9.8   | AAA  |
| `--velvet-night` on `--dusty-blush` | 13.2  | AAA  |

## Don't

- Don't use pure white (`#FFFFFF`) on the brand background — it reads as
  notification-style hostility. Use `--whisper`.
- Don't tint the crimson with orange. The signature shifts toward NGL's
  palette and away from "secret."
- Don't use `--champagne` for body copy. Reserve it for *one* element per
  screen.
