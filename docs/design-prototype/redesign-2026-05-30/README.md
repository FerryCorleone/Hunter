# Hunter Redesign Visual Inventory

Date: 2026-05-30

This folder stores the generated visual references and the productized HTML/CSS design artifact for the settings-window and floating-widget redesign pass. The PRD remains the product source of truth; generated images define visual direction only, while `index.html` is the editable review artifact.

## HTML Review Artifact

| File | Purpose | Notes |
| --- | --- | --- |
| `index.html` | Real DOM HTML/CSS prototype for design review | Includes Settings Window tabs, Floating Widget states, shared component board, PRD coverage matrix, and generated image references. Generated PNGs are not used as full-page backgrounds. |

## Generated References

| File | PRD Coverage | Notes |
| --- | --- | --- |
| `design-system-board.png` | Tokens, typography, spacing, settings rows, permission pills, provider anatomy, waveform, orb states | Primary visual source for shared component styling. |
| `asset-sheet.png` | App icon direction, circular avatar, icon set, app glyphs, empty-state art, waveform assets | Asset direction only; app glyphs are placeholders and should be replaced by system/app icons in implementation. |
| `settings-general-watchlist-ai.png` | Settings / General, Watchlist, AI Providers | Full page visual reference for the three highest-priority settings pages. |
| `settings-voice-history-states.png` | Settings / Voice & Language, History, menu bar menu, permission/key/provider/toast states | Full page and state visual reference for secondary settings and system states. |
| `floating-widget-states.png` | Floating Orb, Quick Control Popover, Catch Popover, Focus Toast states | Current primary reference for the desktop widget and popovers. |
| `settings-window-reference.png` | Settings Window / General, sidebar, permissions, shortcut, focus session | Use the layout density, white settings rows, sidebar sizing, and permission simplification. Do not copy the generated character avatar. |
| `floating-widget-reference.png` | Floating Orb, Quick Control Popover, Catch Popover, Focus Toast states | Use circular orb, complete progress ring, solid popovers, blue remaining progress, green listening ring, animated waveform direction. |
| `component-board-reference.png` | Shared components, tokens, provider card, key capture, permission pills, app picker row | Use tokens and reusable component states. Ignore the generated animal mark; Hunter default avatar remains the sunglasses-eye asset. |

## PRD-To-Design Coverage

| PRD Surface | Covered By | Implementation Source |
| --- | --- | --- |
| Floating Orb | `index.html#floating`, `floating-widget-states.png` | `FloatingOverlayView`, `FloatingMascotIcon`, `CountdownBorder` |
| Quick Control Popover | `index.html#floating`, `floating-widget-states.png` | `QuickControlMenu` |
| Catch Popover | `index.html#floating`, `floating-widget-states.png` | `FloatingOverlayView.catchCard` |
| Focus Toast | `index.html#floating`, `floating-widget-states.png` | `FloatingOverlayView.toastView` |
| Settings / General | `index.html#settings`, `settings-general-watchlist-ai.png` | `SettingsView`, `GeneralPanel`, `SettingCard`, `PermissionRow`, `ShortcutCaptureBox` |
| Settings / Watchlist | `index.html#settings`, `settings-general-watchlist-ai.png` | `WatchlistPanel`, `InstalledAppPickerRow` |
| Settings / AI Providers | `index.html#settings`, `settings-general-watchlist-ai.png` | `ProvidersPanel`, `ProviderEditor` |
| Settings / Voice & Language | `index.html#settings`, `settings-voice-history-states.png` | `VoicePanel` |
| Settings / History | `index.html#settings`, `settings-voice-history-states.png` | `HistoryPanel`, `StatPill` |
| Shared components and states | `index.html#components`, `design-system-board.png`, `asset-sheet.png` | Shared SwiftUI row, card, permission, provider, key-capture, and waveform components |

## Design Constraints

- No macOS wallpaper, Dock, or system menu bar is part of the product implementation.
- No square translucent backing behind the floating orb.
- No duplicated permission state indicators. One status pill plus one action button is enough.
- No internal Provider/LLM/TTS status copy inside user-facing catch popovers.
- Any future UI element not represented in `docs/PRD.md` section 2A must update the PRD before design or code changes.
