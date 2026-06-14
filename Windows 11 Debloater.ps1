################################################################################
# Script Globals
################################################################################


# Main variables
$varTitle="Windows 11 Customisation"
$varScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$varTempFile="$env:TEMP\~$($varTitle -Replace "\s",'').tmp"
$Host.UI.RawUI.WindowTitle = $varTitle
Clear

# This disables all the actual effects. It only says its doing stuff but doesn't alter things
$g_NerfScript = $false

# If true, built-in app removal also removes provisioned packages from the Windows image.
# This prevents selected apps being installed automatically for new user profiles.
$g_RemoveProvisionedAppxPackages = $false

# Track if the script has done something to know to ask user to reboot
$g_HasMadeChanges = $false

# The minimum size of the block (80 - 10 - 2)
$g_MinBlockWidth = 68

# Get the current users SID used for some stuff
$g_UserSID = (Get-WmiObject Win32_UserAccount -Filter "Name = '$env:USERNAME'").sid

# Map 'HKCR' to be HKEY_CLASSES_ROOT like PS already defines HKCU and HKLM
if (!(Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
}


################################################################################
################################################################################
################################################################################



################################################################################
# Class Definitions (Fake Classes)
################################################################################


Function Menu {
    param(
        [String] $menuName
    )

    $newMenu = New-Object -TypeName psobject
    $newMenu | Add-Member -MemberType NoteProperty -Name menuName -Value $menuName
    $newMenu | Add-Member -MemberType NoteProperty -Name menuItems -Value ([System.Collections.ArrayList]@())
    $newMenu | Add-Member -MemberType NoteProperty -Name invalidOption -Value $false
    $newMenu | Add-Member -MemberType ScriptMethod -Name "AddMenuItem" -Value {
        param(
            [psobject] $menuItem
        )
        [void]$this.menuItems.Add($menuItem)
    }
    $newMenu | Add-Member -MemberType ScriptMethod -Name "PrintMenu" -Value {
        $longestMenuItem = (($this.menuItems | foreach { $_.DisplayName() } | Measure-Object -Maximum -Property Length).Maximum) + 4 # Add 2 padding on either side
        $menuWidth = Longest @($Global:g_MinBlockWidth, $longestMenuItem, $this.menuName.Length)

        $longestMenuItem = $longestMenuItem + ($longestMenuItem % 2) + 10
        $menuWidth = $menuWidth + ($menuWidth % 2) + 10

        while($true) {
            ClearScreen

            $mainRow = "+" + (FillChars "-" $menuWidth) + "+"
            $blankRow = "|" + (FillChars " " $menuWidth) + "|"
            $heading = "|" + (CenterString $this.menuName " " $menuWidth) + "|"

            if ($Global:g_HasMadeChanges) {
                PrintRestartBlock
            }
            Write-Host $mainRow
            Write-Host $heading
            Write-Host $mainRow
            Write-Host $blankRow
            $this.menuItems | foreach { "|" + (CenterString ((" " * 2 + $_.DisplayName()).PadRight($longestMenuItem, " ")) " " $menuWidth) + "|" } | Write-Host
            Write-Host $blankRow
            Write-Host $mainRow
            Write-Host `r

            $option = Read-Host -Prompt $(if ($this.invalidOption) { "Invalid option, try again" } else { "Input option" })
            $menuItem = $this.menuItems | Where-Object { $_.key -eq $option }

            if ($menuItem) {
                $this.invalidOption = $false
                try {
                    Invoke-Command $menuItem.function
                } catch {
                    Write-Host `r
                    Write-Host "An error has occurred" -ForegroundColor Red
                    Write-Host $Error[0].Exception.ToString() -ForegroundColor Red
                    Pause
                }
            } else {
                $this.invalidOption = $true
            }
        }
    }

    return $newMenu
}
Function MenuItem {
    param(
        [Char]          $key,
        [String]        $name,
        [ScriptBlock]   $function
    )

    $newMenuItem = New-Object -TypeName psobject
    $newMenuItem | Add-Member -MemberType NoteProperty -Name key -Value $key
    $newMenuItem | Add-Member -MemberType NoteProperty -Name name -Value $name
    $newMenuItem | Add-Member -MemberType NoteProperty -Name function -Value $function
    $newMenuItem | Add-Member -MemberType ScriptMethod -Name "DisplayName" -Value {
        return $this.key +". " + $this.name
    }
    $newMenuItem | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
        return $this.DisplayName()
    }

    return $newMenuItem
}


################################################################################
################################################################################
################################################################################



################################################################################
# Utility Functions
################################################################################


Function CheckAdmin {
    # Check if running the script as Administrator
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
        Write-Host "  ERROR: This script needs to be run as an Administrator to do what it needs to."
        Write-Host "  It will self elevate in..." -NoNewline
        Start-Sleep 1
        Write-Host "3..." -NoNewline
        Start-Sleep 1
        Write-Host "2..." -NoNewline
        Start-Sleep 1
        Write-Host "1..." -NoNewline
        Start-Sleep 1

        ReloadScript
    } else {
        if (Test-Path $varTempFile) {
            Set-Location -LiteralPath (Get-Content $varTempFile -Raw).Trim()
            Remove-Item $varTempFile
            $varScriptDir = $pwd.path
        }
    }
}

Function ReloadScript {
    param(
        [Bool]  $showReason = $false
    )
    if ($showReason) {
        PrintBlock "Script will reload cause this CMDLet fucks stuff up!" -isolateBlock $true
        Pause
    }

    # Write current directory to a temp file so the elevated process can switch back.
    $pwd.path | Out-File $varTempFile

    # Start the script again as Admin.
    $newProcess = New-Object System.Diagnostics.ProcessStartInfo
    $newProcess.FileName = (Get-Process -Id $PID).Path
    $newProcess.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($script:MyInvocation.MyCommand.Path)`""
    $newProcess.Verb = "RunAs"
    [System.Diagnostics.Process]::Start($newProcess) | Out-Null
    exit
}

Function Longest {
    param(
        [Array] $values
    )

    return ($values | Measure-Object -Maximum).Maximum
}

Function FillChars {
    param(
        [Char]  $char,
        [Int]   $length
    )

    return $char.ToString() * $length
}

Function CenterString {
    param(
        [String]    $text,
        [Char]      $fillChar,
        [Int]       $totalLength
    )

    return ($fillChar.ToString() * ([Int](($totalLength - $text.Length) / 2)) + $text).PadRight($totalLength, $fillChar)
}

Function ClearScreen {
    try {
        [Console]::Clear()
    } catch [Exception] {
        Clear-Host
    }
}

Function PrintBlock {
    param(
        [String]    $message,
        [Int]       $blockWidth = -1,
        [Bool]      $internalBlanks = $false,
        [Bool]      $printLastRow = $true,
        [Bool]      $isolateBlock = $false,
        [Bool]      $clearScreen = $false
    )

    $menuWidth = $this.longestName + ($this.longestName % 2) + 10
    if ($blockWidth -eq -1) {
        $blockWidth = Longest @($g_MinBlockWidth, $message.Length)
        $blockWidth = $blockWidth + ($blockWidth % 2) + 10
    }
    $mainRow = "+" + (FillChars "-" $blockWidth) + "+"
    $blankRow = "|" + (FillChars " " $blockWidth) + "|"

    if ($clearScreen) {
        ClearScreen
    }
    if ($isolateBlock -and !$clearScreen) {
        Write-Host `r
    }
    Write-Host $mainRow
    if ($internalBlanks) {
        Write-Host $blankRow
    }
    Write-Host ("|" + (CenterString $message " " $blockWidth) + "|")
    if ($internalBlanks) {
        Write-Host $blankRow
    }
    if ($printLastRow) {
        Write-Host $mainRow
        if ($isolateBlock) {
            Write-Host `r
        }
    }
}

Function PrintRestartBlock {
    param(
        [Int]       $blockWidth = -1
    )

    $message = "Changes have been made, don't forget to reboot your computer"
    if ($blockWidth -eq -1) {
        $blockWidth = Longest @($g_MinBlockWidth, $message.Length)
        $blockWidth = $blockWidth + ($blockWidth % 2) + 10
    }

    PrintBlock $message -blockWidth $blockWidth -internalBlanks $true -printLastRow $false
}

Function AwaitKeyPress {
    param(
        [Char]      $key        = "q",
        [String]    $message    = "Operation completed, press '$key' to return",
        [Bool]      $asBlock    = $true,
        [Bool]      $immediate  = $true
    )

    CheckInput @($key) $message $asBlock $immediate
}

Function GetUserConfirmation {
    param(
        [String]    $message    = "Would you like to proceed? Y/N",
        [Bool]      $asBlock    = $true,
        [Bool]      $immediate  = $true
    )

    $result = CheckInput @("y", "n") $message $asBlock $immediate
    return $($result -eq "y")
}

Function CheckInput {
    param (
        [Char[]]    $keys,
        [String]    $message,
        [Bool]      $asBlock,
        [Bool]      $immediate
    )

    if ($asBlock) {
        PrintBlock $message -isolateBlock $true
    } else {
        Write-Host $message
    }

    try {
        $Host.UI.RawUI.FlushInputBuffer()
        $prompt = $null
        do {
            if ($immediate) {
                $userInput = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").character
            } else {
                $userInput = Read-Host -Prompt $prompt
                $prompt = "Invalid option, try again"
            }
        } while ($userInput -notin $keys)
    } catch [Exception] {
        Pause
    }

    return $userInput
}

Function SelectFromList {
    param(
        [Parameter(Position = 0, Mandatory)]
        [String] $title,

        [Parameter(Position = 1, Mandatory)]
        [String[]] $items,

        [Parameter(Position = 2)]
        [String] $actionName = "continue",

        [Parameter(Position = 3)]
        $defaultSelected = $null
    )

    $selected = New-Object 'bool[]' $items.Count
    if ($null -ne $defaultSelected -and $defaultSelected.Count -gt 0) {
        for ($i = 0; $i -lt $items.Count -and $i -lt $defaultSelected.Count; $i++) {
            $selected[$i] = [Bool]$defaultSelected[$i]
        }
    }
    $cursorIndex = 0
    $invalidOption = $false

    ClearScreen
    PrintBlock $title -internalBlanks $true

    $listTop = $Host.UI.RawUI.CursorPosition.Y
    $bufferWidth = [Math]::Max(1, $Host.UI.RawUI.BufferSize.Width - 1)
    $statusTop = $listTop + $items.Count + 1

    $fitLine = {
        param(
            [String] $line
        )

        if ($line.Length -gt $bufferWidth) {
            return $line.Substring(0, $bufferWidth)
        }

        return $line.PadRight($bufferWidth)
    }

    $formatRow = {
        param(
            [Int] $index
        )

        $checkbox = if ($selected[$index]) { "[x]" } else { "[ ]" }
        $cursor = if ($index -eq $cursorIndex) { ">" } else { " " }
        return ("{0} {1} {2,2}. {3}" -f $cursor, $checkbox, ($index + 1), $items[$index])
    }

    $drawRow = {
        param(
            [Int] $index
        )

        $position = $Host.UI.RawUI.CursorPosition
        $position.X = 0
        $position.Y = $listTop + $index
        $Host.UI.RawUI.CursorPosition = $position

        $row = & $fitLine (& $formatRow $index)
        if ($index -eq $cursorIndex) {
            Write-Host $row -ForegroundColor Black -BackgroundColor Gray -NoNewline
        } else {
            Write-Host $row -NoNewline
        }
    }

    $drawStatus = {
        param(
            [Bool] $showInvalid
        )

        $position = $Host.UI.RawUI.CursorPosition
        $position.X = 0
        $position.Y = $statusTop
        $Host.UI.RawUI.CursorPosition = $position
        Write-Host (& $fitLine "Up/Down = move, Space = toggle, Enter/R = $actionName selected, A = all, N = none, B/Q/Esc = back") -NoNewline

        $position.Y = $statusTop + 1
        $Host.UI.RawUI.CursorPosition = $position
        if ($showInvalid) {
            Write-Host (& $fitLine "Invalid option, try again") -ForegroundColor Red -NoNewline
        } else {
            Write-Host (& $fitLine "") -NoNewline
        }
    }

    for ($i = 0; $i -lt $items.Count; $i++) {
        & $drawRow $i
    }
    & $drawStatus $invalidOption

    while ($true) {
        try {
            $key = [Console]::ReadKey($true)
        } catch [Exception] {
            Pause
            return $null
        }

        $invalidOption = $false
        & $drawStatus $invalidOption

        if ($key.Key -eq [ConsoleKey]::Spacebar -or $key.KeyChar -eq [Char]32) {
            $selected[$cursorIndex] = !$selected[$cursorIndex]
            & $drawRow $cursorIndex
            Continue
        }

        switch ($key.Key.ToString()) {
            "Enter" {
                $selectedItems = @()
                for ($i = 0; $i -lt $items.Count; $i++) {
                    if ($selected[$i]) {
                        $selectedItems += $items[$i]
                    }
                }

                if ($selectedItems.Count -eq 0) {
                    $invalidOption = $true
                    & $drawStatus $invalidOption
                    Continue
                }

                return $selectedItems
            }
            "Escape" {
                return $null
            }
            "UpArrow" {
                $previousCursorIndex = $cursorIndex
                if ($cursorIndex -gt 0) {
                    $cursorIndex--
                } else {
                    $cursorIndex = $items.Count - 1
                }
                & $drawRow $previousCursorIndex
                & $drawRow $cursorIndex
                Continue
            }
            "DownArrow" {
                $previousCursorIndex = $cursorIndex
                if ($cursorIndex -lt ($items.Count - 1)) {
                    $cursorIndex++
                } else {
                    $cursorIndex = 0
                }
                & $drawRow $previousCursorIndex
                & $drawRow $cursorIndex
                Continue
            }
        }

        if ([Char]::IsControl($key.KeyChar)) {
            Continue
        }

        switch ($key.KeyChar.ToString().ToUpper()) {
            "A" {
                for ($i = 0; $i -lt $selected.Count; $i++) {
                    $selected[$i] = $true
                    & $drawRow $i
                }
                Continue
            }
            "N" {
                for ($i = 0; $i -lt $selected.Count; $i++) {
                    $selected[$i] = $false
                    & $drawRow $i
                }
                Continue
            }
            "R" {
                $selectedItems = @()
                for ($i = 0; $i -lt $items.Count; $i++) {
                    if ($selected[$i]) {
                        $selectedItems += $items[$i]
                    }
                }

                if ($selectedItems.Count -eq 0) {
                    $invalidOption = $true
                    & $drawStatus $invalidOption
                    Continue
                }

                return $selectedItems
            }
            "B" {
                return $null
            }
            "Q" {
                return $null
            }
            default {
                $invalidOption = $true
                & $drawStatus $invalidOption
            }
        }
    }
}


################################################################################
################################################################################
################################################################################



################################################################################
# Built-In Apps
################################################################################


# The list of apps that can be removed. Keep this ordered as it should appear in menus.
$g_Apps = @(
    [pscustomobject]@{ Name = "Clipchamp.Clipchamp"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.BingNews"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.BingSearch"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.BingWeather"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.GetHelp"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.MicrosoftOfficeHub"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.MicrosoftSolitaireCollection"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.MicrosoftStickyNotes"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.OutlookForWindows"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.Paint"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.PowerAutomateDesktop"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.Todos"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.WidgetsPlatformRuntime"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.Windows.DevHome"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.Windows.Photos"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.WindowsAlarms"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.WindowsCamera"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.WindowsFeedbackHub"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.WindowsSoundRecorder"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.WindowsTerminal"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.YourPhone"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.ZuneMusic"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "MicrosoftCorporationII.QuickAssist"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "MicrosoftWindows.Client.WebExperience"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "MicrosoftWindows.CrossDevice"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "MSTeams"; DefaultRemove = $true }
    # Generally I like to keep
    [pscustomobject]@{ Name = "Microsoft.ScreenSketch"; DefaultRemove = $false }
    [pscustomobject]@{ Name = "Microsoft.StorePurchaseApp"; DefaultRemove = $false }
    [pscustomobject]@{ Name = "Microsoft.WindowsCalculator"; DefaultRemove = $false }
    [pscustomobject]@{ Name = "Microsoft.WindowsNotepad"; DefaultRemove = $false }
    [pscustomobject]@{ Name = "Microsoft.WindowsStore"; DefaultRemove = $false }
    # Xbox stuff is sometimes nice to keep
    [pscustomobject]@{ Name = "Microsoft.GamingApp"; DefaultRemove = $false }
    [pscustomobject]@{ Name = "Microsoft.Xbox.TCUI"; DefaultRemove = $false }
    [pscustomobject]@{ Name = "Microsoft.XboxGamingOverlay"; DefaultRemove = $false }
    [pscustomobject]@{ Name = "Microsoft.XboxIdentityProvider"; DefaultRemove = $false }
    [pscustomobject]@{ Name = "Microsoft.XboxSpeechToTextOverlay"; DefaultRemove = $false }
    [pscustomobject]@{ Name = "Microsoft.XboxGameCallableUI"; DefaultRemove = $false }
)

$g_AppsList = @($g_Apps | ForEach-Object { $_.Name })

Function BuiltInAppsList {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)]
        [Bool] $allUsers
    )

    Process {
        PrintBlock ("Built-In Apps " + $(if ($allUsers) { "(All)" } else { "(Installed)" })) -isolateBlock $true -clearScreen $true

        if ($allUsers) {
            $results = Get-AppxPackage -AllUsers | Where-Object { $_.NonRemovable -eq $false } | Select Name, PackageFullName
        } else {
            $results = Get-AppxPackage | Where-Object { $_.NonRemovable -eq $false } | Select Name, PackageFullName
        }

        $results | Sort-Object -Property @{ Expression = { $_.Name}; Descending = $false } | Format-Table | Out-Host

        AwaitKeyPress
    }
}

Function BuiltInAppsRemove {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [Bool] $removeProvisioned = $g_RemoveProvisionedAppxPackages
    )

    Process {
        $selectedApps = SelectFromList "Remove Built-In Apps" $g_AppsList "remove" @($g_Apps | ForEach-Object { $_.DefaultRemove })
        if ($null -eq $selectedApps) {
            return
        }
        $selectedApps = @($selectedApps)

        PrintBlock ("Removing Built-In Apps" + $(if ($removeProvisioned) { " + Provisioned Packages" } else { "" })) -isolateBlock $true -clearScreen $true

        $oldProgressPreference = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        try {
            ForEach ($builtInApp in $selectedApps) {
                $installedPackages = Get-AppxPackage -Name $builtInApp
                $provisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $builtInApp

                If (!($installedPackages -or ($removeProvisioned -and $provisionedPackages))) {
                    Write-Host $("Removing: $builtInApp failed, already removed or not found")
                    Continue
                }

                Write-Host $("Removing: $builtInApp")
                if (!$g_NerfScript) {
                    $installedPackages | ForEach-Object {
                        Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue | Out-Null
                    }

                    if ($removeProvisioned) {
                        $provisionedPackages | ForEach-Object {
                            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
                        }
                    }

                    if ($installedPackages -or ($removeProvisioned -and $provisionedPackages)) {
                        $Global:g_HasMadeChanges = $true
                    }
                }
            }
        } finally {
            $ProgressPreference = $oldProgressPreference
        }

        AwaitKeyPress
    }
}

Function BuiltInAppsRestore {
    [CmdletBinding()]
    param()

    Process {
        $selectedApps = SelectFromList "Restore Built-In Apps" $g_AppsList "restore" @($g_Apps | ForEach-Object { !$_.DefaultRemove })
        if ($null -eq $selectedApps) {
            return
        }
        $selectedApps = @($selectedApps)

        PrintBlock "Restoring Built-In Apps" -isolateBlock $true -clearScreen $true

        $oldProgressPreference = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        try {
            ForEach ($builtInApp in $selectedApps) {
                Write-Host $("Restoring: $builtInApp")
                if (!$g_NerfScript) {
                    Get-AppxPackage -AllUsers -Name $builtInApp | ForEach-Object {
                        Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue | Out-Null
                    }
                    $Global:g_HasMadeChanges = $true
                }
            }
        } finally {
            $ProgressPreference = $oldProgressPreference
        }

        AwaitKeyPress
    }
}


################################################################################
################################################################################
################################################################################



################################################################################
# Capabilities
################################################################################


# The list of capabilities that can be removed. Keep this ordered as it should appear in menus.
$g_Capabilities = @(
    [pscustomobject]@{ Name = "App.StepsRecorder*"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Browser.InternetExplorer*"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Hello.Face.*"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "MathRecognizer*"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Media.WindowsMediaPlayer*"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.Wallpapers.Extended*"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Microsoft.Windows.PowerShell.ISE*"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Print.Management.Console*"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Language.Handwriting*"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Language.OCR*"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Language.Speech*"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Language.TextToSpeech*"; DefaultRemove = $true }
)

$g_CapabilitiesList = @($g_Capabilities | ForEach-Object { $_.Name })

Function CapabilitiesList {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)]
        [Bool] $allUsers
    )

    Process {
        PrintBlock $("Windows Capabilities " + $(if ($allUsers) { "(All)" } else { "(Installed)" })) -isolateBlock $true -clearScreen $true

        $results = Get-WindowsCapability -Online | Where-Object { if ($allUsers) { $_.State -ne $null } else { $_.State -eq "Installed" } } | Select-Object Name, State
        $results | Sort-Object -Property @{ Expression = { $_.State }; Descending = $true }, @{ Expression = "Name"; Descending = $false } | Format-Table | Out-Host

        AwaitKeyPress
    }
}

Function CapabilitiesRemove {
    [CmdletBinding()]
    param()

    Process {
        $selectedCapabilities = SelectFromList "Remove Windows Capabilities" $g_CapabilitiesList "remove" @($g_Capabilities | ForEach-Object { $_.DefaultRemove })
        if ($null -eq $selectedCapabilities) {
            return
        }
        $selectedCapabilities = @($selectedCapabilities)

        PrintBlock "Removing Windows Capabilities" -isolateBlock $true -clearScreen $true

        ForEach ($capability in $selectedCapabilities) {
            If (!(Get-WindowsCapability -Online -Name $capability).Name) {
                Write-Host $("Removing: $capability failed, capability not found")
                Continue
            }

            Write-Host $("Removing: $capability")
            if (!$g_NerfScript) {
                Get-WindowsCapability -Online -Name "$capability" | Where-Object State -eq "Installed" | Remove-WindowsCapability -Online
                $Global:g_HasMadeChanges = $true
            }
        }

        AwaitKeyPress
    }
}

Function CapabilitiesRestore {
    [CmdletBinding()]
    param()

    Process {
        $selectedCapabilities = SelectFromList "Restore Windows Capabilities" $g_CapabilitiesList "restore" @($g_Capabilities | ForEach-Object { !$_.DefaultRemove })
        if ($null -eq $selectedCapabilities) {
            return
        }
        $selectedCapabilities = @($selectedCapabilities)

        PrintBlock "Restoring Windows Capabilities" -isolateBlock $true -clearScreen $true

        ForEach ($capability in $selectedCapabilities) {
            If (!(Get-WindowsCapability -Online -Name $capability).Name) {
                Write-Host $("Restoring: $capability failed, capability not found")
                Continue
            }

            Write-Host $("Restoring: $capability")
            if (!$g_NerfScript) {
                Get-WindowsCapability -Online -Name "$capability" | Where-Object State -eq "NotPresent" | Add-WindowsCapability -Online
                $Global:g_HasMadeChanges = $true
            }
        }

        AwaitKeyPress
    }
}


################################################################################
################################################################################
################################################################################



################################################################################
# Optional Features
################################################################################


# The list of optional features that can be disabled. Keep this ordered as it should appear in menus.
$g_OptionalFeatures = @(
    [pscustomobject]@{ Name = "MediaPlayback"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "MSRDC-Infrastructure"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "NetFx3"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Printing-Foundation-Features"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Printing-Foundation-InternetPrinting-Client"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Printing-PrintToPDFServices-Features"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "Recall"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "SmbDirect"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "WorkFolders-Client"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "WCF-TCP-PortSharing45"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "WCF-Services45"; DefaultRemove = $true }
    [pscustomobject]@{ Name = "NetFx4-AdvSrvs"; DefaultRemove = $true }
)

$g_OptionalFeaturesList = @($g_OptionalFeatures | ForEach-Object { $_.Name })

Function OptionalFeaturesList {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)]
        [Bool] $allUsers
    )

    Process {
        PrintBlock $("Optional Features " + $(if ($allUsers) { "(All)" } else { "(Enabled)" })) -isolateBlock $true -clearScreen $true

        $results = Get-WindowsOptionalFeature -Online | Where-Object { if ($allUsers) { $_.State -ne $null } else { $_.State -eq "Enabled" } } | Select-Object FeatureName, State
        $results | Sort-Object -Property @{ Expression = { $_.State }; Descending = $true }, @{ Expression = "FeatureName"; Descending = $false } | Format-Table | Out-Host

        AwaitKeyPress
    }
}


Function OptionalFeaturesDisable {
    [CmdletBinding()]
    param()

    Process {
        $selectedOptionalFeatures = SelectFromList "Disable Optional Features" $g_OptionalFeaturesList "disable" @($g_OptionalFeatures | ForEach-Object { $_.DefaultRemove })
        if ($null -eq $selectedOptionalFeatures) {
            return
        }
        $selectedOptionalFeatures = @($selectedOptionalFeatures)

        PrintBlock "Disabling Optional Features" -isolateBlock $true -clearScreen $true

        ForEach ($optionalFeature in $selectedOptionalFeatures) {
            If (!(Get-WindowsOptionalFeature -Online -FeatureName $optionalFeature).FeatureName) {
                Write-Host $("Disabling: $optionalFeature failed, feature not found")
                Continue
            }

            Write-Host $("Disabling: $optionalFeature")
            if (!$g_NerfScript) {
                Get-WindowsOptionalFeature -Online -FeatureName "$optionalFeature" | Where-Object State -eq "Enabled" | Disable-WindowsOptionalFeature -Online -NoRestart -WarningAction SilentlyContinue
                $Global:g_HasMadeChanges = $true
            }
        }

        AwaitKeyPress
    }
}


Function OptionalFeaturesEnable {
    [CmdletBinding()]
    param()

    Process {
        $selectedOptionalFeatures = SelectFromList "Enable Optional Features" $g_OptionalFeaturesList "enable" @($g_OptionalFeatures | ForEach-Object { !$_.DefaultRemove })
        if ($null -eq $selectedOptionalFeatures) {
            return
        }
        $selectedOptionalFeatures = @($selectedOptionalFeatures)

        PrintBlock "Enabling Optional Features" -isolateBlock $true -clearScreen $true

        ForEach ($optionalFeature in $selectedOptionalFeatures) {
            If (!(Get-WindowsOptionalFeature -Online -FeatureName $optionalFeature).FeatureName) {
                Write-Host $("Enabling: $optionalFeature failed, feature not found")
                Continue
            }

            Write-Host $("Enabling: $optionalFeature")
            if (!$g_NerfScript) {
                Get-WindowsOptionalFeature -Online -FeatureName "$optionalFeature" | Where-Object State -eq "Disabled" | Enable-WindowsOptionalFeature -Online -NoRestart -WarningAction SilentlyContinue
                $Global:g_HasMadeChanges = $true
            }
        }

        AwaitKeyPress
    }
}


################################################################################
################################################################################
################################################################################



################################################################################
# OneDrive
################################################################################


Function OneDriveRemove {
    [CmdletBinding()]
    param ()
    Process {
        PrintBlock "OneDrive Uninstallation" -isolateBlock $true -clearScreen $true

        if ($g_NerfScript) {
            Write-Host "Script is nerfed, skipping"
        } else {
            $oneDriveUserFolder = $Env:OneDrive
            $deniedOneDriveDeletion = $false

            try {
                if ($oneDriveUserFolder -and (Test-Path -LiteralPath $oneDriveUserFolder)) {
                    Write-Host "Protecting OneDrive user files..."
                    icacls $oneDriveUserFolder /deny "Administrators:(D,DC)" | Out-Null
                    $deniedOneDriveDeletion = $true
                }

                $oneDriveSetup = "$env:systemroot\System32\OneDriveSetup.exe"
                if (!(Test-Path -LiteralPath $oneDriveSetup)) {
                    $oneDriveSetup = "$env:systemroot\SysWOW64\OneDriveSetup.exe"
                }

                if (Test-Path -LiteralPath $oneDriveSetup) {
                    Write-Host "Uninstalling OneDrive..."
                    Start-Process $oneDriveSetup -ArgumentList "/uninstall" -Wait
                } else {
                    Write-Host "OneDrive uninstaller not found"
                }

                Write-Host "Stopping OneDrive related processes..."
                Stop-Process -Name OneDrive,FileCoAuth,Explorer -Force -ErrorAction SilentlyContinue

                Write-Host "Removing leftover OneDrive files..."
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:localappdata\Microsoft\OneDrive"
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:programdata\Microsoft OneDrive"
            } finally {
                if ($deniedOneDriveDeletion -and $oneDriveUserFolder -and (Test-Path -LiteralPath $oneDriveUserFolder)) {
                    Write-Host "Restoring OneDrive user folder permissions..."
                    icacls $oneDriveUserFolder /grant "Administrators:(D,DC)" | Out-Null
                }
            }

            if ($oneDriveUserFolder -and (Test-Path -LiteralPath $oneDriveUserFolder)) {
                if (-not (Get-ChildItem -LiteralPath $oneDriveUserFolder -Force -ErrorAction SilentlyContinue)) {
                    Remove-Item -LiteralPath $oneDriveUserFolder -Recurse -Force -ErrorAction SilentlyContinue
                    [Environment]::SetEnvironmentVariable("OneDrive", $null, "User")
                } else {
                    Write-Host "Cannot remove `"$oneDriveUserFolder`" as it is not empty"
                }
            }

            Write-Host "Disabling OneSync service..."
            Get-Service -Name "OneSyncSvc*" -ErrorAction SilentlyContinue | ForEach-Object {
                Set-Service -Name $_.Name -StartupType Disabled -ErrorAction SilentlyContinue
                Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
            }

            Write-Host "Disable OneDrive via Group Policies..."
            mkdir -Force "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive" | Out-Null
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Type DWord -Value 1

            Write-Host "Remove OneDrive from Explorer sidebar..."
            if (!(Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
                New-PSDrive -PSProvider "Registry" -Root "HKEY_CLASSES_ROOT" -Scope Global -Name "HKCR" | Out-Null
            }
            mkdir -Force "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" | Out-Null
            Set-ItemProperty -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Type DWord -Value 0
            mkdir -Force "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" | Out-Null
            Set-ItemProperty -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Type DWord -Value 0

            Write-Host "Removing run hook for new users..."
            reg load "HKU\Default" "C:\Users\Default\NTUSER.DAT" | Out-Null
            reg delete "HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f | Out-Null
            reg unload "HKU\Default" | Out-Null

            Write-Host "Removing startmenu entry..."
            Remove-Item -Force -ErrorAction SilentlyContinue "$env:userprofile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"

            Write-Host "Removing scheduled task..."
            Get-ScheduledTask -TaskPath '\' -TaskName 'OneDrive*' -ea SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

            Write-Host "Restarting explorer..."
            Start-Process "explorer.exe"
            Start-Sleep 5

            Write-Host "OneDrive Uninstalled" -ForegroundColor "Green"

            $Global:g_HasMadeChanges = $true
        }

        AwaitKeyPress
    }
}

Function OneDriveRestore {
    [CmdletBinding()]
    param ()
    Process {
        PrintBlock "OneDrive Installation" -isolateBlock $true -clearScreen $true

        if ($g_NerfScript) {
            Write-Host "Script is nerfed, skipping"
        } else {
            $winget = Get-Command winget -ErrorAction SilentlyContinue
            if ($winget) {
                Write-Host "Installing OneDrive..."
                winget install Microsoft.OneDrive --source winget --accept-package-agreements --accept-source-agreements
            } else {
                Write-Host "winget not found, cannot install OneDrive automatically" -ForegroundColor Red
            }

            Write-Host "Enabling OneSync service..."
            Get-Service -Name "OneSyncSvc*" -ErrorAction SilentlyContinue | ForEach-Object {
                Set-Service -Name $_.Name -StartupType Automatic -ErrorAction SilentlyContinue
                Start-Service -Name $_.Name -ErrorAction SilentlyContinue
            }

            Write-Host "Enable OneDrive via Group Policies..."
            if (Test-Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive") {
                Remove-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -ErrorAction SilentlyContinue
            }

            Write-Host "Restore OneDrive in Explorer sidebar..."
            if (!(Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
                New-PSDrive -PSProvider "Registry" -Root "HKEY_CLASSES_ROOT" -Scope Global -Name "HKCR" | Out-Null
            }
            mkdir -Force "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" | Out-Null
            Set-ItemProperty -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Type DWord -Value 1
            mkdir -Force "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" | Out-Null
            Set-ItemProperty -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Type DWord -Value 1

            Write-Host "Restarting explorer..."
            Stop-Process -Name Explorer -Force -ErrorAction SilentlyContinue
            Start-Process "explorer.exe"
            Start-Sleep 5

            Write-Host "OneDrive Installed" -ForegroundColor "Green"

            $Global:g_HasMadeChanges = $true
        }

        AwaitKeyPress
    }
}


################################################################################
################################################################################
################################################################################



################################################################################
# Customisation
################################################################################


Function DisableTelemetry {
    [CmdletBinding()]
    param ()
    Process {
        PrintBlock "Windows Telemetry" -isolateBlock $true -clearScreen $true

        if ($g_NerfScript) {
            Write-Host "Script is nerfed, skipping"
        } else {
            reg import "$PSScriptRoot/RegFiles/Telemetry_Disable.reg"
            Write-Host "Telemetry Disabled" -ForegroundColor "Green"
            $Global:g_HasMadeChanges = $true
        }

        AwaitKeyPress
    }
}

Function Personalisation {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory)]
        [Bool] $disable
    )
    Process {
        PrintBlock $("Personalisation: " + $(if ($disable) { "Apply" } else { "Revert" })) -isolateBlock $true -clearScreen $true

        if ($g_NerfScript) {
            Write-Host "Script is nerfed, skipping"
        } else {
            If ($disable) {
                reg import "$PSScriptRoot/RegFiles/Apply.reg"
                Write-Host "Registry settings applied" -ForegroundColor "Green"
            } else {
                reg import "$PSScriptRoot/RegFiles/Revert.reg"
                Write-Host "Registry settings reverted" -ForegroundColor "Green"
            }

            Write-Host "Restarting explorer..."
            taskkill.exe /F /IM "explorer.exe"
            Start-Process "explorer.exe"
            Start-Sleep 5

            $Global:g_HasMadeChanges = $true
        }

        AwaitKeyPress
    }
}


################################################################################
################################################################################
################################################################################



################################################################################
# GUI Controls
################################################################################


# Menus
$m_MainMenu                 = Menu "Main Menu"
$m_BuiltInAppsMenu          = Menu "Built-In Apps Menu"
$m_WindowsCapabilitiesMenu  = Menu "Windows Capabilities Menu"
$m_OptionalFeaturesMenu     = Menu "Optional Features Menu"
$m_OneDriveMenu             = Menu "OneDrive Menu"
$m_CustomisationMenu        = Menu "Customisation Menu"

# Main Menu
$m_MainMenu.AddMenuItem((MenuItem "1" "Built-In Apps"           { $m_BuiltInAppsMenu.PrintMenu() }))
$m_MainMenu.AddMenuItem((MenuItem "2" "Windows Capabilities"    { $m_WindowsCapabilitiesMenu.PrintMenu() }))
$m_MainMenu.AddMenuItem((MenuItem "3" "Optional Features"       { $m_OptionalFeaturesMenu.PrintMenu() }))
$m_MainMenu.AddMenuItem((MenuItem "4" "OneDrive"                { $m_OneDriveMenu.PrintMenu() }))
$m_MainMenu.AddMenuItem((MenuItem "5" "Customisation"           { $m_CustomisationMenu.PrintMenu() }))
$m_MainMenu.AddMenuItem((MenuItem "Q" "Quit"                    { Break }))

# Built-In Apps Menu
$m_BuiltInAppsMenu.AddMenuItem((MenuItem "1" "List Built-In Apps (All)"             { BuiltInAppsList $true }))
$m_BuiltInAppsMenu.AddMenuItem((MenuItem "2" "List Built-In Apps (Installed)"       { BuiltInAppsList $false }))
$m_BuiltInAppsMenu.AddMenuItem((MenuItem "3" "Remove Built-In Apps"                 { BuiltInAppsRemove }))
$m_BuiltInAppsMenu.AddMenuItem((MenuItem "4" "Remove Built-In Apps (Provisioned)"   { BuiltInAppsRemove $true }))
$m_BuiltInAppsMenu.AddMenuItem((MenuItem "5" "Restore Built-In Apps"                { BuiltInAppsRestore }))
$m_BuiltInAppsMenu.AddMenuItem((MenuItem "B" "Return to Main Menu"                  { Break }))

# Windows Capabilities Menu
$m_WindowsCapabilitiesMenu.AddMenuItem((MenuItem "1" "List Windows Capabilities (All)"          { CapabilitiesList $true }))
$m_WindowsCapabilitiesMenu.AddMenuItem((MenuItem "2" "List Windows Capabilities (Installed)"    { CapabilitiesList $false }))
$m_WindowsCapabilitiesMenu.AddMenuItem((MenuItem "3" "Remove Windows Capabilities"              { CapabilitiesRemove }))
$m_WindowsCapabilitiesMenu.AddMenuItem((MenuItem "4" "Restore Windows Capabilities"             { CapabilitiesRestore }))
$m_WindowsCapabilitiesMenu.AddMenuItem((MenuItem "B" "Return to Main Menu"                      { Break }))

# Optional Features Menu
$m_OptionalFeaturesMenu.AddMenuItem((MenuItem "1" "List Optional Features (All)"        { OptionalFeaturesList $true }))
$m_OptionalFeaturesMenu.AddMenuItem((MenuItem "2" "List Optional Features (Enabled)"    { OptionalFeaturesList $false }))
$m_OptionalFeaturesMenu.AddMenuItem((MenuItem "3" "Disable Optional Features"           { OptionalFeaturesDisable }))
$m_OptionalFeaturesMenu.AddMenuItem((MenuItem "4" "Enable Optional Features"            { OptionalFeaturesEnable }))
$m_OptionalFeaturesMenu.AddMenuItem((MenuItem "B" "Return to Main Menu"                 { Break }))

# OneDrive Menu
$m_OneDriveMenu.AddMenuItem((MenuItem "1" "Remove OneDrive"     { OneDriveRemove }))
$m_OneDriveMenu.AddMenuItem((MenuItem "2" "Restore OneDrive"    { OneDriveRestore }))
$m_OneDriveMenu.AddMenuItem((MenuItem "B" "Return to Main Menu" { Break }))

# Customisation Menu
$m_CustomisationMenu.AddMenuItem((MenuItem "1" "Disable Telemetry"          { DisableTelemetry }))
$m_CustomisationMenu.AddMenuItem((MenuItem "2" "Apply Personalisation"      { Personalisation $true }))
$m_CustomisationMenu.AddMenuItem((MenuItem "3" "Revert Personalisation"     { Personalisation $false }))
$m_CustomisationMenu.AddMenuItem((MenuItem "B" "Return to Main Menu"        { Break }))


################################################################################
################################################################################
################################################################################



# Execution Pipeline


CheckAdmin
$m_MainMenu.PrintMenu()

if (!$g_NerfScript -and $g_HasMadeChanges) {
    PrintBlock "Changes were made, you need to reboot your computer" -internalBlanks $true -clearScreen $true

    if (GetUserConfirmation "Restart now? Y/N" -asBlock $false) {
        Write-Host "Rebooting in 10s..."
        shutdown.exe -r -t 10
    }
}
