# 🤖 Agent Notes

This repository contains a personal Windows 11 debloater written primarily as one interactive PowerShell script.

## 🎯 Project Intent

Keep the tool practical, explicit, and understandable. It is not intended to be a fully general enterprise management framework. The primary user is comfortable with deliberate destructive actions when they are clearly labelled and documented.

## 🗂️ Important Files

- `Windows 11 Debloater.ps1`: main interactive menu and all core actions.
- `README.md`: user-facing documentation. Keep it aligned with menu behavior.
- `RegFiles/Apply.reg`: applies preferred registry customisations.
- `RegFiles/Revert.reg`: applies inverse/default-style values where practical. This is not a backup restore.
- `RegFiles/Telemetry_Disable.reg`: focused telemetry/privacy registry preset.

## 🧭 Current Menu Shape

- Main areas: Built-In Apps, Windows Capabilities, Optional Features, OneDrive, Customisation.
- Customisation submenus/actions: Telemetry, PowerShell, WSL, SSH Server, USB Wake Devices, Terminal Settings, Personalisation.
- Keep menu labels clear when actions have stronger side effects, especially provisioned package removal, SSH/firewall setup, and uninstall/remove actions.

## 🧠 Behavioral Decisions

- Removing provisioned AppX packages is intentionally a strong delete-from-image action. Do not treat lack of automatic re-provision restore as a bug unless the user asks for that feature.
- OneDrive restore is allowed to reinstall and set OneDrive up again. It does not need to exactly reverse every removal command.
- Registry reverts should be documented as best-effort inverse presets, not as backups.
- `Apply.reg` disables Game DVR capture flags to prevent `ms-gamingoverlay` prompts after Xbox Game Bar has been removed; `Revert.reg` should carry the inverse values.
- Windows Terminal is the preferred shell host and should remain in the built-in app list with `DefaultRemove = $false`.
- Do not remove Windows PowerShell 5.1 itself. Hiding/restoring shortcuts, context-menu entries, and Windows Terminal profiles is acceptable; deleting the built-in engine is not.

## 💙 PowerShell And Terminal

- PowerShell 7 install/uninstall uses `winget`.
- PowerShell 7 install should set Windows Terminal profile GUID `{574e775e-4f2a-5b96-ac1e-a2962a402336}` `elevate` to `true` where Terminal settings are available.
- Windows Terminal settings are edited in `settings.json`.
- The Terminal settings action hides Command Prompt profile GUID `{0caa0dad-35be-5f56-a8ff-afceeeaa6101}` and sets `warning.confirmCloseAllTabs` to `false`.
- The built-in Windows PowerShell context-menu keys are protected and live at exact `HKEY_CLASSES_ROOT` paths:
  - `HKCR:\Directory\shell\Powershell`
  - `HKCR:\Directory\Background\shell\Powershell`
  - `HKCR:\Drive\shell\Powershell`
- Use the .NET Registry API for ownership/ACL/value changes because PowerShell provider ACL commands can fail against these protected keys.
- Restore should remove this script's `ProgrammaticAccessOnly` marker and make a best-effort attempt to put protected keys back under TrustedInstaller ownership.

## 🐧 WSL

- WSL install targets Debian explicitly via `GetWslDistributionName`, currently `Debian`.
- Install should be idempotent. If Debian already exists, treat it as success and still apply supporting setup.
- WSL install should ensure `%UserProfile%\.wslconfig` contains `[wsl2]`, `networkingMode=mirrored`, and `vmIdleTimeout=86400000` without duplicating settings or removing unrelated config.
- WSL install should create/update the hidden `WindowsDebloater WSL Debian Keepalive` startup scheduled task for the current Windows user.
- Keepalive task command:

```text
wsl.exe -d Debian --exec /bin/bash -lc "exec sleep infinity"
```

- Keepalive task should have no execution time limit.
- WSL install prompts for managed firewall rules, all selected by default:
  - `WSL SSH` on TCP `22`
  - `WSL HTTP` on TCP `80`
  - `WSL HTTPS` on TCP `443`
- Re-running WSL install treats the selected firewall boxes as the desired managed rule set. Unticked managed rules should be removed. Selecting none is allowed.
- WSL uninstall uses `wsl --uninstall`, removes the keepalive task, and removes managed WSL firewall rules.
- Do not call `wsl --unregister` or delete distribution files unless explicitly requested.
- WSL/Linux shell context-menu cleanup should hide or restore shell verbs only.

## 🔐 SSH Server

- SSH Server means the Windows host OpenSSH Server, separate from WSL SSH.
- Install should add `OpenSSH.Server~~~~0.0.1.0` if needed.
- Prefer `Add-WindowsCapability`; fall back to `dism.exe` when the cmdlet fails.
- Install prompts for a port with default `22`.
- Install prompts for PowerShell `5` or `7` only when PowerShell 7 is detected.
- PowerShell 7 detection should check:
  - `C:\Program Files\PowerShell\7\pwsh.exe`
  - `Get-AppxPackage Microsoft.PowerShell` install location
  - `Get-Command pwsh.exe -All`, while skipping the per-user WindowsApps alias
- Install should start and stop `sshd` once so Windows can generate the base config before editing it.
- `sshd_config` should enforce:
  - `Port <selected port>`
  - `PasswordAuthentication no`
  - `PermitEmptyPasswords no`
  - `PubkeyAuthentication yes`
  - `Match Group administrators` with `AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys`
- Preserve existing `administrators_authorized_keys` content. Never recreate it with `-Force` in a way that blanks keys.
- Authorized keys ACL should grant `Administrators:F` and `SYSTEM:F` and disable inheritance.
- Use stable firewall rule name `Windows-SSH-Server`; do not include the port in the rule name.
- Remove default Windows OpenSSH firewall rules matching `OpenSSH SSH*` / `OpenSSH-Server-In-TCP`.
- SSH Server remove should clean up the managed firewall rule, remove the OpenSSH `DefaultShell` registry value, and remove the capability. Leave existing SSH config and authorized keys files in place.

## 🔌 USB Wake Devices

- USB wake-device handling is integrated into the Customisation menu.
- It can list current wake-armed devices and disable wake for those devices.

## 🛠️ Editing Guidelines

- Keep changes scoped and readable.
- Follow the existing function-section layout in `Windows 11 Debloater.ps1`.
- Use PowerShell built-ins and structured objects where practical.
- Use `-LiteralPath` for filesystem paths that may contain spaces or user-controlled values.
- Use well-known SIDs for built-in Windows groups when practical instead of localized group names.
- Avoid silently making destructive behavior broader than the menu label implies.
- Preserve the `$g_NerfScript` development switch.
- If extending `SelectFromList`, preserve existing callers' behavior. The WSL firewall flow intentionally allows an empty selection.

## ✅ Validation

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

Do not run debloating actions on the user's machine as a test unless the user explicitly asks for it.
