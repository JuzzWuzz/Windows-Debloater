# Agent Notes

This repository contains a personal Windows 11 debloater written primarily as one interactive PowerShell script.

## Project Intent

Keep the tool practical, explicit, and understandable. It is not intended to be a fully general enterprise management framework. The primary user is comfortable with deliberate destructive actions when they are clearly labelled and documented.

## Important Files

- `Windows 11 Debloater.ps1`: main interactive menu and all core actions.
- `RegFiles/Apply.reg`: applies the preferred registry customisations.
- `RegFiles/Revert.reg`: applies inverse/default-style values where practical. This is not a backup restore.
- `RegFiles/Telemetry_Disable.reg`: focused telemetry/privacy registry preset.

## Behavioral Decisions

- Removing provisioned AppX packages is intentionally a strong delete-from-image action. Do not treat lack of automatic re-provision restore as a bug unless the user asks for that feature.
- OneDrive restore is allowed to reinstall and set OneDrive up again. It does not need to exactly reverse every removal command.
- Registry reverts should be documented as best-effort inverse presets, not as backups.
- Do not remove Windows PowerShell 5.1 itself. Hiding/restoring shortcuts, context-menu entries, and Windows Terminal profiles is acceptable; deleting the built-in engine is not. The built-in PowerShell context-menu keys are protected and live at exact `HKEY_CLASSES_ROOT` paths; use the .NET Registry API for ownership/ACL/value changes because PowerShell provider ACL commands can fail against these keys. Restore should remove this script's `ProgrammaticAccessOnly` marker and make a best-effort attempt to put those protected keys back under TrustedInstaller ownership.
- Windows Terminal is the preferred shell host and should remain in the built-in app list with `DefaultRemove = $false`.
- Windows Terminal settings are edited in `settings.json`. The Terminal settings action hides Command Prompt profile GUID `{0caa0dad-35be-5f56-a8ff-afceeeaa6101}` and sets `warning.confirmCloseAllTabs` to `false`. PowerShell 7 install should set profile GUID `{574e775e-4f2a-5b96-ac1e-a2962a402336}` `elevate` to `true` where Terminal settings are available.
- WSL/Linux shell context-menu cleanup should hide or restore shell verbs only. The WSL uninstall action uses `wsl --uninstall`; do not call `wsl --unregister` or delete distribution files unless explicitly requested.
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

The main script and registry files are the core tracked project. USB wake-device handling is integrated into the Customisation menu.
