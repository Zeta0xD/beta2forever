# beta2forever: copies addons and settings from the WoW Forever beta client (_classic_beta_)
# to the Forever stress test client (_forever_). See README.md.
param(
    [string]$WowDir,
    [string]$From = '_classic_beta_',
    [string]$To = '_forever_',
    # Test hooks: scripted answers in prompt order, comma-separated, and no check for a running game.
    [string]$Answers,
    [switch]$SkipProcessCheck
)
$ErrorActionPreference = 'Stop'
$Queue = if ($Answers) { @($Answers -split ',') } else { $null }

$AccountFiles = 'bindings-cache.wtf', 'macros-cache.txt', 'config-cache.wtf', 'chat-frontend-cache.txt',
    'edit-mode-cache-account.txt', 'tts-cache-account.txt'
$CharFiles = 'AddOns.txt', 'bindings-cache.wtf', 'macros-cache.txt', 'config-cache.wtf', 'chat-cache.txt',
    'click-bindings-cache.txt', 'cooldownmanager.txt', 'edit-mode-cache-character.txt', 'layout-local.txt',
    'tts-cache-character.txt'

function Stop-Run($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

function Ask($q) {
    if ($null -ne $script:Queue) {
        if ($script:Queue.Count -eq 0) { Stop-Run "no scripted answer for: $q" }
        $a = $script:Queue[0]; $script:Queue = @($script:Queue | Select-Object -Skip 1)
        Write-Host "$q $a"; return $a
    }
    Read-Host $q
}

function Ask-YesNo($q) { (Ask "$q [y/n]") -match '^\s*y' }

function Pick($what, $items) {
    $items = @($items)
    if ($items.Count -eq 0) { Stop-Run "no $what found" }
    if ($items.Count -eq 1) { Write-Host "$what`: $($items[0])"; return $items[0] }
    Write-Host "Choose the $what`:"
    for ($i = 0; $i -lt $items.Count; $i++) { Write-Host "  $($i + 1)) $($items[$i])" }
    while ($true) {
        $n = 0
        if ([int]::TryParse((Ask 'Number:'), [ref]$n) -and $n -ge 1 -and $n -le $items.Count) { return $items[$n - 1] }
        if ($null -ne $script:Queue) { Stop-Run "bad scripted answer for $what" }
        Write-Host 'Enter one of the numbers above.'
    }
}

function Find-WowDir {
    $c = @()
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
                   'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft') {
        $p = (Get-ItemProperty $k -ErrorAction SilentlyContinue).InstallPath
        if ($p) { $c += (Split-Path ($p.TrimEnd('\'))) }
    }
    $c += "${env:ProgramFiles(x86)}\World of Warcraft", "$env:ProgramFiles\World of Warcraft"
    foreach ($d in (Get-PSDrive -PSProvider FileSystem).Root) { $c += "${d}World of Warcraft", "${d}Games\World of Warcraft" }
    foreach ($d in $c) { if ($d -and (Test-Path "$d\$From") -and (Test-Path "$d\$To")) { return $d } }
    $null
}

# Account folders, then realm\character folders, as relative names.
function Accounts($wtf) {
    @(Get-ChildItem "$wtf\Account" -Directory -ErrorAction SilentlyContinue |
        Where-Object Name -ne 'SavedVariables' | ForEach-Object Name | Sort-Object)
}
function Characters($acct) {
    @(Get-ChildItem $acct -Directory -ErrorAction SilentlyContinue | Where-Object Name -ne 'SavedVariables' |
        ForEach-Object { $r = $_.Name; Get-ChildItem $_.FullName -Directory | ForEach-Object { "$r\$($_.Name)" } } |
        Sort-Object)
}

# --- Locate both clients ---
if (-not $WowDir) { $WowDir = Find-WowDir }
if (-not $WowDir) { $WowDir = Ask "World of Warcraft folder (the one holding $From and $To):" }
$WowDir = $WowDir.Trim().Trim('"').TrimEnd('\')
$src = "$WowDir\$From"; $dst = "$WowDir\$To"
foreach ($p in $src, $dst) { if (-not (Test-Path "$p\WTF")) { Stop-Run "no WTF folder in $p" } }
Write-Host "From: $src`nTo:   $dst`n"

if (-not $SkipProcessCheck) {
    $running = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '^Wow' -or ($_.Path -and $_.Path.StartsWith($WowDir, 'OrdinalIgnoreCase')) }
    if ($running) { Stop-Run "the game is running ($(($running.Name | Sort-Object -Unique) -join ', ')). Quit it fully, then run this again." }
}

# --- Choose what to copy ---
$doAddons = Ask-YesNo 'Copy addons (Interface\AddOns)?'
$doConfig = Ask-YesNo 'Copy install-wide settings (graphics, sound: WTF\Config.wtf)?'
$doAccount = Ask-YesNo 'Copy account settings (keybinds, macros, options, addon settings)?'
$doChars = Ask-YesNo 'Copy character settings from one character to another?'
if (-not ($doAddons -or $doConfig -or $doAccount -or $doChars)) { Stop-Run 'nothing chosen' }

$pairs = @()   # character copies: source dir -> target dir
if ($doAccount -or $doChars) {
    $sa = Pick "$From account" (Accounts "$src\WTF")
    $tAccounts = Accounts "$dst\WTF"
    if ($tAccounts.Count -eq 0) { Stop-Run "no account in $dst\WTF\Account. Log in once on $To, quit, and run this again." }
    $ta = Pick "$To account" $tAccounts
    $sAcct = "$src\WTF\Account\$sa"; $tAcct = "$dst\WTF\Account\$ta"
    if ($doChars) {
        $sc = @(Characters $sAcct); $tc = @(Characters $tAcct)
        if ($tc.Count -eq 0) { Stop-Run "no characters in $tAcct. Log in once on $To with the character, quit, and run this again." }
        do {
            $from = Pick "$From character to copy from" $sc
            $to = Pick "$To character to copy to" $tc
            $pairs += , @("$sAcct\$from", "$tAcct\$to")
        } while (Ask-YesNo 'Copy another character?')
    }
}

Write-Host "`nWill copy:"
if ($doAddons) { Write-Host '  addons (same-named addon folders are replaced; other addons stay)' }
if ($doConfig) { Write-Host '  WTF\Config.wtf' }
if ($doAccount) { Write-Host "  account $sa -> $ta" }
foreach ($p in $pairs) { Write-Host "  character $(Split-Path $p[0] -Leaf) -> $(Split-Path $p[1] -Leaf)" }
if (-not (Ask-YesNo 'Go ahead?')) { Stop-Run 'cancelled; nothing changed' }

# --- Back up what will change ---
$bk = "$WowDir\beta2forever-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
New-Item -ItemType Directory $bk | Out-Null
Copy-Item -Recurse "$dst\WTF" "$bk\WTF"
if ($doAddons -and (Test-Path "$dst\Interface\AddOns")) {
    New-Item -ItemType Directory "$bk\Interface" | Out-Null
    Copy-Item -Recurse "$dst\Interface\AddOns" "$bk\Interface\AddOns"
}
Write-Host "Backup: $bk"

# --- Copy, recording every file for the check ---
$copied = New-Object System.Collections.ArrayList
function Copy-One($from, $to) {
    New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
    Copy-Item -LiteralPath $from -Destination $to -Force
    [void]$copied.Add(@($from, $to))
}
function Copy-Named($fromDir, $toDir, $names) {
    foreach ($n in $names) { if (Test-Path -LiteralPath "$fromDir\$n") { Copy-One "$fromDir\$n" "$toDir\$n" } }
    Get-ChildItem "$fromDir\SavedVariables" -Filter '*.lua' -File -ErrorAction SilentlyContinue |
        ForEach-Object { Copy-One $_.FullName "$toDir\SavedVariables\$($_.Name)" }
}

if ($doAddons) {
    foreach ($a in Get-ChildItem "$src\Interface\AddOns" -Directory) {
        $t = "$dst\Interface\AddOns\$($a.Name)"
        if (Test-Path -LiteralPath $t) { Remove-Item -LiteralPath $t -Recurse -Force }
        foreach ($f in Get-ChildItem -LiteralPath $a.FullName -Recurse -File) {
            Copy-One $f.FullName ($t + $f.FullName.Substring($a.FullName.Length))
        }
    }
}
if ($doConfig -and (Test-Path "$src\WTF\Config.wtf")) { Copy-One "$src\WTF\Config.wtf" "$dst\WTF\Config.wtf" }
if ($doAccount) { Copy-Named $sAcct $tAcct $AccountFiles }
foreach ($p in $pairs) { Copy-Named $p[0] $p[1] $CharFiles }

# --- Check every copy matches its source ---
$bad = @($copied | Where-Object { (Get-FileHash -LiteralPath $_[0]).Hash -ne (Get-FileHash -LiteralPath $_[1]).Hash })
foreach ($b in $bad) { Write-Host "MISMATCH: $($b[1])" -ForegroundColor Red }
Write-Host "`nCopied $($copied.Count) files, $($bad.Count) mismatched."
if ($bad) { Stop-Run "some copies differ from their source; restore from $bk if the game misbehaves" }
Write-Host 'Done. Start the game and log in.' -ForegroundColor Green
exit 0
