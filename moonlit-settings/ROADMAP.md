# 🌙 Moonlit Settings — Roadmap

Planned work for **next sessions**. This is the agreed scope — build these, nothing more, until it's revisited.

> **Signature idea for this batch:** a **vertical side bar** — the top bar can live on the left/right edge instead of the top, with every widget/button reflowed to fit, in *both* the islands and classic styles.

---

## ✅ Where things stand now (done)

- **Config layer** — `~/.config/moonlit/config.json` is the single source of truth. Shell reads it live via `services/Config.qml` (Quickshell `pragma Singleton`, `FileView` + `JsonAdapter`, `watchChanges`). Bind themeable values to `Config.<key>` — never hardcode.
- **Bar** — floating pill **islands** *or* **classic** solid topbar, switchable via `Config.barStyle`. Both layouts live in `bar/Bar.qml` behind a `Loader`.
- **Accent** — moonlight mauve, live from `Config.accent`. **Bar follows it; panels + `Workspaces.qml` do NOT yet** (still hardcoded).
- **Settings app** (`moonlit-settings/`, Go + Fyne, single binary) — Catppuccin-themed, frosted (Hyprland windowrule: float + center + opacity, matched by title), tabs: Theme (accent + bar style, live) / Hyprland (rounding, opacity — Apply + at-your-own-risk) / Keys (rebind curated set — Apply). Every screen has **Reset to defaults**. Headless `moonlit-settings apply`.
- **Change model** — *live* changes → `config.json` (safe, instant). *Hard* changes → `~/.config/hypr/moonlit.conf` (sourced last) + `hyprctl reload`, behind **Apply** + ⚠ banner.

---

## 🧭 The batch (build all of these)

### 1. ⭐ Vertical side bar — top / left / right *(the headline; hardest)*
Let the bar live on the **top, left, or right** edge. New config key: `barPosition: "top" | "left" | "right"`.
- **Window/anchors** — left/right = anchor top+bottom+edge, fixed width (~44px), `exclusiveZone = width`; content becomes a `ColumnLayout` (vertical) instead of `RowLayout`.
- **Islands (vertical)** — three stacked pill islands (top / center / bottom) instead of left / center / right.
- **Classic (vertical)** — full-height solid slab on the side.
- **Widget reflow** — the hard part: horizontal widgets like `RAM 3.7G` don't fit a narrow vertical bar. Reflow to **icon-only** (value hidden or shown stacked/on hover), workspaces stack vertically, the moon-clock capsule goes vertical (stacked `21` / `47` or rotated). Every button/widget needs a vertical variant.
- **Panels follow the bar** — panels currently anchor top+right/center. They must read `barPosition` and open along the correct edge (e.g. left bar → panels slide out from the left). This touches every panel's anchoring + the OSD/toast placement.
- **Settings UI** — a top/left/right selector in the Theme tab; islands/classic still applies on top of it.

### 2. Whole-shell accent
Migrate **all panels + `Workspaces.qml`** from their hardcoded accent to `Config.accent` (add `import "../services"`, swap literals). Then the picker recolors the *entire* shell, not just the bar. *(Low risk, high payoff — do early.)*

### 3. Palette switcher
Mocha / Macchiato / Frappé / Latte (+ custom). Needs a small palette layer in `Config` (not just one accent — bg/surfaces/text too) that the shell binds to. The "theme abstraction" from the rice roadmap.

### 4. Bar knobs (live)
Bar opacity, height, island gap, corner rounding, 12/24-hour clock.

### 5. Widget toggles (live)
Show/hide: update count, CPU temp, battery %, recording dot, (per-widget visibility). Config booleans the bar reads.

### 6–10. More Hyprland knobs (Apply + at-your-own-risk)
All rendered into `moonlit.conf`, same pattern as rounding/opacity:
- **6. Gaps** — inner / outer
- **7. Border** — size + **active/inactive border color** (color pickers)
- **8. Blur** — on/off + size (+ maybe passes)
- **9. Animations** — enable/disable + speed
- **10. Shadow** — on/off (+ range)

### 11. Keybind upgrade
"**Press keys to bind**" capture UI (instead of typing `SUPER, Q`), more actions, and **conflict detection** (warn if a combo is already used).

### 12. Import / export config
Export `config.json` (+ `moonlit.conf`) to a file; import to restore. Pairs well with an **auto-backup before Apply**.

### 13. About tab
Version, repo link, credits, "made with 🌙".

### 14. Make it shippable
- Install binary → `~/.local/bin/moonlit-settings`
- `.desktop` entry so it appears in rofi/launchers
- Keybind to open (e.g. `Super+,`)
- Build folded into `install.sh`; maybe an **AUR** package
- README section + a screenshot in `assets/screenshots/`

### 15. Notification center overhaul (SwayNC)
- Replace custom ToastStack with SwayNC for history, grouping, search
- Catppuccin CSS theme + config toggle in settings
- SwayNC is a pacman package, well tested in JaKooLit + ML4W dots
- **Status: optional / future** — calendar panel already covers notification history

### 16. Rofi modes expansion
- Emoji picker · Calculator · Clipboard history · Keybinds cheatsheet
- Each is a standalone rofi script mode, ~30 min each
- **Status: quick wins, pick up anytime**

### 17. Window overview / task switcher
- Live window previews like macOS Mission Control / end-4's "waffle"
- Quickshell window thumbnails + grid layout
- **Status: large feature, high visual impact**

---

## 🔧 Notes for whoever builds this
- **JSON, not TOML** (QML reads JSON natively).
- Quickshell singletons must live in a **subfolder** and be imported by relative path (`import "../services"`). Importing the config root fails. Check errors with `qs log`.
- Never `Write`/`Edit` raw nerd-font glyphs (they corrupt) — inject via `python3` using `chr(0xXXXX)`, or reuse existing bytes.
- **Commit freely in small chunks; never push until asked.**
- Sync live → repo per file (avoid `cp -a` of dirs that contain a nested `.git`).
- Suggested order: **2 → 4/5 → 3 → 1 → 6–10 → 11 → 12 → 13 → 14** (quick wins first; the vertical bar is the big one).
