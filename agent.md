# Agent Notes

This repository contains a personal Windows 11 debloater written primarily as one interactive PowerShell script.

## Project Intent

Keep the tool practical, explicit, and understandable. It is not intended to be a fully general enterprise management framework. The primary user is comfortable with deliberate destructive actions when they are clearly labelled and documented.

## Important Files

- `Windows 11 Debloater.ps1`: main interactive menu and all core actions.
- `RegFiles/Apply.reg`: applies the preferred registry customisations.
- `RegFiles/Revert.reg`: applies inverse/default-style values where practical. This is not a backup restore.
- `RegFiles/Telemetry_Disable.reg`: focused telemetry/privacy registry preset.
- `Disable-Wake-Devices.ps1`: standalone helper for disabling wake-armed devices. Do not assume it is integrated into the main menu yet.

## Behavioral Decisions

- Removing provisioned AppX packages is intentionally a strong delete-from-image action. Do not treat lack of automatic re-provision restore as a bug unless the user asks for that feature.
- OneDrive restore is allowed to reinstall and set OneDrive up again. It does not need to exactly reverse every removal command.
- Registry reverts should be documented as best-effort inverse presets, not as backups.
- Prefer clear menu labels for actions that have stronger side effects, especially provisioned package removal.

## Editing Guidelines

- Keep changes scoped and readable.
- Follow the existing function-section layout in `Windows 11 Debloater.ps1`.
- Use PowerShell built-ins and structured objects where practical.
- Use `-LiteralPath` for filesystem paths that may contain spaces or user-controlled values.
- Use well-known SIDs for built-in Windows groups when possible instead of localized group names.
- Avoid silently making destructive behavior broader than the menu label implies.
- Preserve the `$g_NerfScript` development switch.

## Validation

At minimum, run a parser check after editing PowerShell:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    ".\Windows 11 Debloater.ps1",
    [ref]$tokens,
    [ref]$errors
) | Out-Null
$errors
```

Also run:

```powershell
git diff --check
```

Do not run the debloating actions on the user's machine as a test unless the user explicitly asks for it.

## Known Repo State

The main script and registry files are the core tracked project. `Disable-Wake-Devices.ps1` may be worked on separately before it is integrated or committed.
