# Widgetario Design System — Tokens

Design tokens for the Widgetario **v3 ("Tools for builders")** home page, authored in the
[W3C Design Tokens Community Group format, **2025.10 stable**](https://www.designtokens.org/tr/2025.10/format/).

Everything is derived directly from the v3 design comp: a neo-brutalist look built on chunky
ink outlines, hard offset shadows (no blur), and a warm yellow/cream palette.

## Files

| File | Purpose |
|------|---------|
| `widgetario.tokens.json` | The design system. The single source of truth. |
| `widgetario.tokens.css`  | A generated reference build (CSS custom properties) showing how the tokens compile. |

## Structure — three tiers

Tokens are layered so a change ripples in one direction (primitive → semantic → component):

1. **`primitive`** — raw, context-free values (the palette, spacing scale, radii, border
   widths, type ramp, shadows). Never reference these directly in product code.
2. **`semantic`** — intent-based aliases (`background.page`, `text.secondary`,
   `status.out-of-stock`, `elevation.raised`). This is the layer most code should consume.
3. **`component`** — component-scoped tokens (`card`, `badge`, `header`, `product-icon`,
   `footer`). Restyle one component without disturbing the rest.

Lower tiers reference higher ones with DTCG aliases, e.g. `"$value": "{primitive.color.ink}"`.

## Format notes (2025.10)

- **Colors** use the structured object form, e.g.
  `{ "colorSpace": "srgb", "components": [0.9882, 0.9255, 0.498], "hex": "#fcec7f" }`.
  The `hex` field is kept for tool/legacy convenience.
- **Dimensions** use `{ "value": 16, "unit": "px" }` (px for borders/radii, rem for
  spacing and type).
- **Composite types** used: `typography`, `shadow`, `border`.

## The palette (sampled from the comp)

| Token | Hex | Role |
|-------|-----|------|
| `yellow`    | `#FCEC7F` | Page background |
| `cream`     | `#FEF9D8` | Header / soft surfaces |
| `white`     | `#FFFFFF` | Cards |
| `ink`       | `#1A1A1A` | Borders, text, footer |
| `ink-soft`  | `#5A5A5A` | Secondary text, prices |
| `pink`      | `#EC6AA1` | Logo, "sold out" |
| `pink-soft` | `#F3B2D0` | Alternate product-icon tile |
| `orange`    | `#ED974F` | Product-icon tiles, "few left" |

### Stock-status mapping

| Status | Background | Text |
|--------|-----------|------|
| In stock     | `ink`    | `yellow` |
| Few left     | `orange` | `ink` |
| Sold out     | `pink`   | `ink` |

## Consuming the tokens

The file is plain DTCG JSON, so any spec-aware tool reads it directly. With
[Style Dictionary](https://styledictionary.com) (v4+ supports DTCG natively):

```js
// config.js
export default {
  source: ["widgetario.tokens.json"],
  platforms: {
    css: { transformGroup: "css", files: [{ destination: "tokens.css", format: "css/variables" }] },
    ios: { transformGroup: "ios-swift", files: [{ destination: "Tokens.swift", format: "ios-swift/class.swift" }] }
  }
};
```

Or use the included `widgetario.tokens.css` as-is. Variable names mirror the token path,
e.g. `semantic.color.background.page` → `--semantic-color-background-page`.

## Notes / things to confirm

- **Typeface**: the comp uses a heavy geometric grotesque. `primitive.typography.family.sans`
  ships a stack (`Archivo, Hanken Grotesk, Inter, system-ui`) as an approximation — swap the
  first entry for the licensed face if you have one.
- **Stroke weight & radii** were read off the comp and snapped to a tidy scale (3px signature
  border; 8/12/16/20px radii). Adjust the primitives if you have exact spec values.
