# STEP — Skill Training & Evolution Panel

STEP is a World of Warcraft Anniversary / Burning Crusade Classic addon for tracking learned weapon and profession skill progress in a compact, configurable panel.

The Phase 1 data core is implemented and validated in game. **Phase 2** now includes the pure `ViewModel`, the validated main panel, and the first configuration slice. Native game options and a synchronized movable window expose general panel behavior plus per-skill visibility, logging, and notification participation.

## Planned features

- Compact and expanded progress views.
- Per-skill visibility, logging, and notification settings.
- Weapon, Defense, Unarmed, primary profession, and secondary profession tracking.
- Active-time and online-time history per skill gain.
- Discreet, exaggerated, or disabled skill-up notifications.
- Summary and detailed history sharing through game chat.
- Native AddOns settings and a synchronized movable configuration window.

## Development commands

- `/step` — Show or hide the progress panel.
- `/step expand|compact|toggle` — Change compact/expanded state.
- `/step show|hide|lock|reset` — Control visibility, movement lock, and position.
- `/step config` — Open the movable standalone configuration window.
- `/step options` — Open STEP in the game's AddOns settings.
- `/step help` — List commands.
- `/step status` — Show diagnostic state.
- `/step scan` — Scan learned skills.
- `/step debug on|off` — Enable or disable event capture.
- `/step debug snapshot` — Print recognized and unknown skill lines.
- `/step debug equipment` — Print resolved weapon slots.
- `/step debug events` — Print the latest captured events.
- `/step debug combat on|off` — Toggle live combat output.
- `/step debug casts on|off` — Toggle live spellcast output.
- `/step debug database` — Show schema, migration, session, and persisted-state status.
- `/step debug bus` — Show the internal listener count.
- `/step debug config <skillKey>` — Show the canonical preferences for one skill.

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
- `docs/PHASE1_TEST_PLAN.md` — In-game validation procedure for the data core and schema migration.
- `docs/PHASE1_VALIDATION_LOG.md` — Evidence and results from the Phase 1 in-game validation.
- `docs/PHASE2_VALIDATION_LOG.md` — Incremental visual and functional validation of the main panel.

## Automated tests

Install the development dependencies and run:

```powershell
npm ci
npm test
```

The test command reads the real `STEP.toc`, validates every runtime file with the Lua 5.1 grammar, and loads that exact order in the pure core suite with mocked WoW APIs. GitHub Actions repeats the suite with a native Lua 5.1 interpreter and validates the installable package.

## Package validation

From PowerShell, run:

```powershell
.\scripts\validate-package.ps1
```

The script derives the package contents from `STEP.toc`, builds a temporary `STEP.zip`, verifies its single top-level `STEP/` folder and removes the temporary files afterward. Pass `-OutputPath STEP.zip` to keep the validated artifact.
