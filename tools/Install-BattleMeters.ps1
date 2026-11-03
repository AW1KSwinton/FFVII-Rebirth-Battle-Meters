[CmdletBinding(SupportsShouldProcess)]
param(
    # Install or Uninstall copy the UE4SS mod into, or out of, the game. Status shows what's there.
    [ValidateSet('Install', 'Uninstall', 'Status')]
    [string]$Mode = 'Status',
    # The game's install folder.
    [string]$GameRoot = 'C:\Program Files (x86)\Steam\steamapps\common\FINAL FANTASY VII REBIRTH'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$ModRoot = Split-Path $PSScriptRoot -Parent
$Ue4ssMods = Join-Path $GameRoot 'End\Binaries\Win64\ue4ss\Mods'
$Source = Join-Path $ModRoot 'ue4ss\BattleMeters'
$Target = Join-Path $Ue4ssMods 'BattleMeters'
$ModsTxt = Join-Path $Ue4ssMods 'mods.txt'
if (-not (Test-Path -LiteralPath $ModsTxt)) { throw "UE4SS not found: $ModsTxt is missing. Install UE4SS first, or pass -GameRoot." }

function Set-ModsTxtEntry([bool]$Enabled) {
    $lines = @(Get-Content -LiteralPath $ModsTxt | Where-Object { $_ -notmatch '^\s*BattleMeters\s*:' })
    if ($Enabled) {
        # Keep the built-in Keybinds line last, as UE4SS expects.
        $at = [Array]::FindIndex([string[]]$lines, [Predicate[string]]{ param($l) $l -match '^\s*Keybinds\s*:' })
        if ($at -lt 0) { $lines += 'BattleMeters : 1' }
        else { $lines = @($lines[0..($at - 1)]) + 'BattleMeters : 1' + @($lines[$at..($lines.Count - 1)]) }
    }
    Copy-Item -LiteralPath $ModsTxt -Destination "$ModsTxt.backup-BattleMeters-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Set-Content -LiteralPath $ModsTxt -Value $lines -Encoding ascii
}

function Assert-GameClosed {
    if (Get-Process -Name 'ff7rebirth_' -ErrorAction SilentlyContinue) { throw 'Close the game first.' }
}

switch ($Mode) {
    'Install' {
        Assert-GameClosed
        if ($PSCmdlet.ShouldProcess($Target, 'Install the BattleMeters UE4SS mod')) {
            # settings.txt holds what the player switched off, so it survives an update.
            $kept = Join-Path $Target 'settings.txt'
            $settings = if (Test-Path -LiteralPath $kept) { Get-Content -LiteralPath $kept -Raw } else { $null }
            if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Recurse -Force }
            Copy-Item -LiteralPath $Source -Destination $Target -Recurse
            if ($settings) { Set-Content -LiteralPath $kept -Value $settings -NoNewline -Encoding ascii }
            Set-ModsTxtEntry $true
            Write-Host "Installed to $Target"
        }
    }
    'Uninstall' {
        Assert-GameClosed
        if ($PSCmdlet.ShouldProcess($Target, 'Remove the BattleMeters UE4SS mod')) {
            if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Recurse -Force }
            Set-ModsTxtEntry $false
            Write-Host 'Uninstalled.'
        }
    }
    'Status' {
        $main = Join-Path $Target 'Scripts\main.lua'
        if (Test-Path -LiteralPath $main) { "main.lua: " + (Get-FileHash -LiteralPath $main -Algorithm SHA256).Hash } else { 'not installed' }
        Select-String -LiteralPath $ModsTxt -Pattern '^\s*BattleMeters' | ForEach-Object { "mods.txt: $($_.Line)" }
    }
}
