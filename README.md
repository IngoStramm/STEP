# STEP — Skill Training & Evolution Panel

STEP is a World of Warcraft Anniversary / Burning Crusade Classic addon for tracking learned weapon and profession skill progress in a compact, configurable panel.

The project is currently in **Phase 0**, focused on validating the game APIs and events required for accurate combat, crafting, gathering, and fishing activity tracking. The final user interface is not implemented yet.

## Planned features

- Compact and expanded progress views.
- Per-skill visibility, logging, and notification settings.
- Weapon, Defense, Unarmed, primary profession, and secondary profession tracking.
- Active-time and online-time history per skill gain.
- Discreet, exaggerated, or disabled skill-up notifications.
- Summary and detailed history sharing through game chat.
- Native AddOns settings and a synchronized movable configuration window.

## Development commands

- `/step help` — List Phase 0 commands.
- `/step status` — Show diagnostic state.
- `/step scan` — Scan learned skills.
- `/step debug on|off` — Enable or disable event capture.
- `/step debug snapshot` — Print recognized and unknown skill lines.
- `/step debug equipment` — Print resolved weapon slots.
- `/step debug events` — Print the latest captured events.
- `/step debug combat on|off` — Toggle live combat output.
- `/step debug casts on|off` — Toggle live spellcast output.

## Compatibility

- World of Warcraft Anniversary / Burning Crusade Classic 2.5.6.
- Interface `20506`.
- English and Brazilian Portuguese are the canonical development locales.

## Installation

Download `STEP.zip` from the latest GitHub Release and extract it into:

```text
World of Warcraft/_anniversary_/Interface/AddOns/
```

After extraction, the addon folder should be:

```text
World of Warcraft/_anniversary_/Interface/AddOns/STEP/
```

Restart the game or reload the UI.

Do not use GitHub's green **Code > Download ZIP** button for installation. That downloads the source repository snapshot, not the packaged addon.

## Documentation

- `docs/PRD.md` — Approved product requirements.
- `docs/TECHNICAL_ARCHITECTURE.md` — Approved technical architecture.
- `docs/PHASE0_TEST_PLAN.md` — In-game API validation procedure.
- `docs/PHASE0_VALIDATION_LOG.md` — Evidence and results from in-game validation rounds.

## Package validation

From PowerShell, run:

```powershell
.\scripts\validate-package.ps1
```

The script builds a temporary `STEP.zip`, verifies its single top-level `STEP/` folder and removes the temporary files afterward.
