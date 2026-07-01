# 🪟 Windows Debloater

![Windows 11](https://img.shields.io/badge/Windows-11-0078D4?style=for-the-badge&logo=windows11&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Personal Tool](https://img.shields.io/badge/status-personal_tool-7A3EBA?style=for-the-badge)
![Admin Required](https://img.shields.io/badge/admin-required-C62828?style=for-the-badge)

An interactive PowerShell utility for trimming Windows 11 bloat, disabling noisy system features, and applying a practical personal workstation setup.

This project is built primarily for personal use. It favours explicit, understandable actions over a fully reversible enterprise management framework.

## ✨ What It Does

The main script, `Windows 11 Debloater.ps1`, opens a console menu with sections for:

- 🧩 Built-in AppX apps
- 🛠️ Windows capabilities
- 📦 Windows optional features
- ☁️ OneDrive
- 🎛️ Customisation actions for telemetry, PowerShell, WSL, SSH Server, USB wake devices, Terminal settings, and personalisation

## ✅ Requirements

- Windows 11
- PowerShell 5.1 or newer
- Administrator rights
- Internet access for install/restore paths that use tools such as `winget`, `wsl`, or Windows Optional Capabilities

The main script attempts to self-elevate if it is not already running as Administrator.

## 🚀 Running The Main Script

From an elevated PowerShell window:

```powershell
Set-Location "C:\Path\To\windows-debloater"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Windows 11 Debloater.ps1"
```

The script is menu-driven. Use the listed keys to choose sections and actions.

## 🧭 Main Menu Areas

### 🧩 Built-In Apps

Lists, removes, and attempts to restore selected AppX packages.

There are two removal modes:

- `Remove Built-In Apps` removes installed packages for the current context.
- `Remove Built-In Apps (Provisioned)` also removes selected packages from the Windows image so they are not automatically installed for new user profiles.

Provisioned package removal is intentionally a stronger action. If an app has been removed from provisioning, restoring it may require manual retrieval from the Microsoft Store, `winget`, or original package sources. The script does not maintain a package archive.

Windows Terminal is treated as preferred and is kept by default.

### 🛠️ Windows Capabilities

Lists, removes, and restores selected Windows capabilities, such as Internet Explorer components, Steps Recorder, handwriting, OCR, speech, text-to-speech, and Windows Media Player capability packages.

### 📦 Optional Features

Lists, disables, and enables selected Windows optional features, such as media playback, printing features, SMB Direct, Recall, Work Folders, and .NET/WCF components.

### ☁️ OneDrive

Removes or reinstalls OneDrive.

The removal flow protects the current OneDrive user folder from accidental deletion, uninstalls OneDrive, disables related services and policies, removes Explorer/sidebar integration, removes default-user setup hooks, removes scheduled tasks, and restarts Explorer.

The restore flow uses `winget` when available and reapplies the expected OneDrive service and Explorer integration settings. It is intended to set OneDrive up again, not to be a byte-for-byte reversal of every removal step.

## 🎛️ Customisation

Contains telemetry, PowerShell, WSL, SSH Server, USB wake-device, Terminal, and personalisation actions.

### 📡 Telemetry

Imports `RegFiles/Telemetry_Disable.reg` to disable telemetry and related privacy settings.

### 💙 PowerShell

The PowerShell submenu can:

- Install PowerShell 7 using `winget`
- Uninstall PowerShell 7 using `winget`
- Hide Windows PowerShell 5.1 from common UI surfaces
- Restore Windows PowerShell 5.1 UI entries

The PowerShell 7 install action also sets its Windows Terminal profile to run elevated where Terminal settings are available.

Windows PowerShell 5.1 itself is not uninstalled. It is a built-in Windows component and is left available for compatibility.

The hide action removes Start Menu shortcuts, takes ownership of the three protected built-in Windows PowerShell context-menu keys under `HKEY_CLASSES_ROOT`, grants Administrators Full Control, hides those entries, and hides the Windows PowerShell profile in Windows Terminal where possible.

The restore action recreates the basic Windows PowerShell Start Menu shortcuts, removes the context-menu hide marker, attempts to restore TrustedInstaller ownership on those protected context-menu keys, and unhides the Windows Terminal profile where possible.

### 🐧 WSL

The WSL submenu can:

- Install WSL with Debian using `wsl --install --distribution Debian --no-launch`
- Uninstall WSL using `wsl --uninstall`
- Install or uninstall a hidden startup keepalive scheduled task
- Hide or restore WSL/Linux shell context-menu entries such as `Open Linux shell here`

The install option is idempotent. If the `Debian` distribution already exists, it treats that as success and still reapplies the supporting setup.

WSL install ensures `%UserProfile%\.wslconfig` has a `[wsl2]` section with:

```ini
[wsl2]
networkingMode=mirrored
vmIdleTimeout=86400000
```

Existing unrelated `.wslconfig` content is preserved.

The keepalive task runs as the current Windows user at startup:

```text
wsl.exe -d Debian --exec /bin/bash -lc "exec sleep infinity"
```

It is hidden, has no execution time limit, and is intended to keep Debian running in the background for services such as SSH or Docker.

During install, the script also prompts for managed WSL firewall rules. All are selected by default:

| Rule | Port |
| --- | ---: |
| `WSL SSH` | TCP `22` |
| `WSL HTTP` | TCP `80` |
| `WSL HTTPS` | TCP `443` |

Rerunning install treats the selected boxes as the desired WSL firewall rule set. Unticking a managed rule removes it. Selecting none is allowed.

The WSL uninstall option removes the keepalive task and managed WSL firewall rules, but does not call `wsl --unregister`, so it does not intentionally delete Linux distribution files.

### 🔐 SSH Server

The SSH Server submenu manages the Windows host OpenSSH Server, separate from WSL SSH.

It can:

- Install and configure OpenSSH Server
- Open `%ProgramData%\ssh\administrators_authorized_keys` in Notepad
- Restart `sshd`
- Remove OpenSSH Server

Install prompts for:

- SSH port, defaulting to `22`
- PowerShell shell version, `5` or `7`, when PowerShell 7 is available

The install flow:

- Adds the `OpenSSH.Server~~~~0.0.1.0` capability if needed
- Starts and stops `sshd` once so Windows generates the base config
- Updates `sshd_config` with the selected port
- Ensures `PasswordAuthentication no`
- Ensures `PermitEmptyPasswords no`
- Ensures `PubkeyAuthentication yes`
- Ensures the administrators authorized-keys file exists without wiping existing keys
- Applies the expected ACL to `administrators_authorized_keys`
- Sets `HKLM:\SOFTWARE\OpenSSH\DefaultShell`
- Creates or updates the stable firewall rule `Windows-SSH-Server`
- Removes default Windows OpenSSH firewall rules such as `OpenSSH SSH Server (sshd)`

PowerShell 7 detection checks the classic MSI path first, then the Microsoft.PowerShell MSIX package install location, then `Get-Command pwsh.exe -All` while skipping the per-user WindowsApps alias.

Remove cleans up the managed firewall rule, removes the OpenSSH default-shell registry value, and removes the OpenSSH Server capability. Existing SSH config and authorized-keys files are left in place.

### 🔌 USB Wake Devices

The USB wake-device submenu can:

- List devices currently allowed to wake the computer
- Disable wake for those devices

### 🖥️ Terminal Settings

The Terminal settings action updates Windows Terminal settings where available:

- Hides the Command Prompt profile
- Sets `warning.confirmCloseAllTabs` to `false`

### 🎨 Personalisation

The registry actions import presets from `RegFiles`:

- `Apply.reg` applies preferred personalisation, privacy, Explorer, Windows Update, Copilot, Edge, Start menu, taskbar, and context-menu settings.
- `Revert.reg` applies inverse/default-style values where practical.

`Revert.reg` is not a backup of the machine's previous state. It is a best-effort inverse preset.

## ⚠️ Safety Notes

- Review selections before confirming destructive actions.
- Provisioned package removal can require manual app retrieval later.
- Registry presets change both user and machine policy locations.
- Some changes require a reboot.
- SSH and firewall actions affect remote access paths. Keep an active local admin session while changing them.
- The script intentionally has a `$g_NerfScript` switch in the main script for dry-run style development.

## 🧪 Development Checks

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

## 🗂️ Repository Layout

```text
.
|-- Windows 11 Debloater.ps1
|-- README.md
|-- agent.md
`-- RegFiles
    |-- Apply.reg
    |-- Revert.reg
    `-- Telemetry_Disable.reg
```
