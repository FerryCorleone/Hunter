# Hunter Redesign Visual Inventory

Date: 2026-05-30

This folder stores the generated visual references for the settings-window redesign pass. The PRD remains the product source of truth; these images define visual direction only.

## Generated References

| File | PRD Coverage | Notes |
| --- | --- | --- |
| `settings-window-reference.png` | Settings Window / General, sidebar, permissions, shortcut, focus session | Use the layout density, white settings rows, sidebar sizing, and permission simplification. Do not copy the generated character avatar. |
| `floating-widget-reference.png` | Floating Orb, Quick Control Popover, Catch Popover, Focus Toast states | Use circular orb, complete progress ring, solid popovers, blue remaining progress, green listening ring, animated waveform direction. |
| `component-board-reference.png` | Shared components, tokens, provider card, key capture, permission pills, app picker row | Use tokens and reusable component states. Ignore the generated animal mark; Hunter default avatar remains the sunglasses-eye asset. |

## PRD-To-Design Coverage

| PRD Surface | Covered By | Implementation Source |
| --- | --- | --- |
| Floating Orb | `floating-widget-reference.png` | `FloatingOverlayView`, `FloatingMascotIcon`, `CountdownBorder` |
| Quick Control Popover | `floating-widget-reference.png` | `QuickControlMenu` |
| Catch Popover | `floating-widget-reference.png` | `FloatingOverlayView.catchCard` |
| Focus Toast | `floating-widget-reference.png` | `FloatingOverlayView.toastView` |
| Settings / General | `settings-window-reference.png`, `component-board-reference.png` | `SettingsView`, `GeneralPanel`, `SettingCard`, `PermissionRow`, `ShortcutCaptureBox` |
| Settings / Watchlist | `component-board-reference.png` | `WatchlistPanel`, `InstalledAppPickerRow` |
| Settings / AI Providers | `component-board-reference.png` | `ProvidersPanel`, `ProviderEditor` |
| Settings / Voice & Language | `settings-window-reference.png`, `component-board-reference.png` | `VoicePanel` |
| Settings / History | PRD 2A structure and shared row tokens | `HistoryPanel`, `StatPill` |

## Design Constraints

- No macOS wallpaper, Dock, or system menu bar is part of the product implementation.
- No square translucent backing behind the floating orb.
- No duplicated permission state indicators. One status pill plus one action button is enough.
- No internal Provider/LLM/TTS status copy inside user-facing catch popovers.
- Any future UI element not represented in `docs/PRD.md` section 2A must update the PRD before design or code changes.
