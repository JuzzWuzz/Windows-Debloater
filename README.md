# Windows Debloater

An interactive PowerShell utility for removing Windows 11 bloat, disabling noisy system features, and applying a personal set of Windows customisations.

This project is built primarily for personal use. It favours practical, explicit actions over a fully reversible system-management framework.

## What It Does

The main script, `Windows 11 Debloater.ps1`, opens a console menu with sections for:

- Built-in AppX apps
- Windows capabilities
- Windows optional features
- OneDrive
- Telemetry, PowerShell, WSL, USB wake-device, and personalisation settings

## Requirements

- Windows 11
- PowerShell 5.1 or newer
- Administrator rights
- Internet access for install/restore paths that use tools such as `winget` or `wsl`

The main script attempts to self-elevate if it is not already running as Administrator.

## Running The Main Script

From an elevated PowerShell window:

```powershell
Set-Location "C:\Path\To\windows-debloater"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Windows 11 Debloater.ps1"
```

The script is menu-driven. Use the listed keys to choose sections and actions.

## Main Menu Areas

### Built-In Apps

Lists, removes, and attempts to restore selected AppX packages.

There are two removal modes:

- `Remove Built-In Apps` removes installed packages for the current context.
- `Remove Built-In Apps (Provisioned)` also removes selected packages from the Windows image so they are not automatically installed for new user profiles.

Provisioned package removal is intentionally a stronger action. If an app has been removed from provisioning, restoring it may require manual retrieval from the Microsoft Store, `winget`, or original package sources. The script does not try to maintain a package archive.

### Windows Capabilities

Lists, removes, and restores selected Windows capabilities, such as Internet Explorer components, Steps Recorder, handwriting, OCR, speech, text-to-speech, and Windows Media Player capability packages.

### Optional Features

Lists, disables, and enables selected Windows optional features, such as media playback, printing features, SMB Direct, Recall, Work Folders, and .NET/WCF components.

### OneDrive

Removes or reinstalls OneDrive.

The removal flow protects the current OneDrive user folder from accidental deletion, uninstalls OneDrive, disables related services and policies, removes Explorer/sidebar integration, removes default-user setup hooks, removes scheduled tasks, and restarts Explorer.

The restore flow uses `winget` when available and reapplies the expected OneDrive service and Explorer integration settings. It is intended to set OneDrive up again, not to be a byte-for-byte reversal of every removal step.

### Customisation

Contains telemetry, PowerShell, WSL, USB wake-device, and personalisation actions.

The PowerShell submenu can install or uninstall PowerShell 7 using `winget`, and hide or restore Windows PowerShell 5.1 from common UI surfaces. The PowerShell 7 install action also sets its Windows Terminal profile to run elevated where Terminal settings are available. The hide action removes Start Menu shortcuts, takes ownership of the three protected built-in Windows PowerShell context-menu keys under `HKEY_CLASSES_ROOT`, grants Administrators Full Control, hides those entries, and hides the Windows PowerShell profile in Windows Terminal where possible. The restore action recreates the basic Windows PowerShell Start Menu shortcuts, removes the context-menu hide marker, attempts to restore TrustedInstaller ownership on those protected context-menu keys, and unhides the Windows Terminal profile where possible.

Windows PowerShell 5.1 itself is not uninstalled. It is a built-in Windows component and is left available for compatibility.

Windows Terminal is treated as the preferred shell host and is kept by default when removing built-in apps.

The Terminal settings action hides the Command Prompt profile and disables the close-all-tabs confirmation warning.

The WSL submenu can install WSL using `wsl --install --no-launch`, uninstall the WSL package using `wsl --uninstall`, and hide or restore WSL/Linux shell context-menu entries such as `Open Linux shell here`. The uninstall option does not call `wsl --unregister`, so it does not intentionally delete Linux distribution files.

The USB wake-device actions can list devices currently allowed to wake the computer and disable wake for those devices.

The registry actions import presets from `RegFiles`:

- `Telemetry_Disable.reg` disables telemetry and related privacy settings.
- `Apply.reg` applies the preferred personalisation, privacy, Explorer, Windows Update, Copilot, Edge, Start menu, taskbar, and context-menu settings.
- `Revert.reg` applies the inverse/default-style values where practical.

`Revert.reg` is not a backup of the machine's previous state. It is a best-effort inverse preset.

## Safety Notes

- Review selections before confirming destructive actions.
- Provisioned package removal can require manual app retrieval later.
- Registry presets change both user and machine policy locations.
- Some changes require a reboot.
- The script intentionally has a `$g_NerfScript` switch in the main script for dry-run style development.

## Development Checks

PowerShell parser check:

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

Git whitespace check:

```powershell
git diff --check
```

## Repository Layout

```text
.
|-- Windows 11 Debloater.ps1
`-- RegFiles
    |-- Apply.reg
    |-- Revert.reg
    `-- Telemetry_Disable.reg
```
