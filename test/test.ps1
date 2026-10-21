# Acceptance test: builds a fake install in TEMP, runs beta2forever.ps1 with scripted answers, checks the result.
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File test\test.ps1   (exit 0 = pass)
# Not 'Stop': in PowerShell 5.1 a child's stderr under 2>&1 would end the test.
$ErrorActionPreference = 'Continue'
$script = Join-Path $PSScriptRoot '..\beta2forever.ps1'
$root = Join-Path $env:TEMP "b2f-test-$PID"
$fails = @()
function Check($cond, $msg) { if (-not $cond) { $script:fails += $msg } }
function Put($path, $text) { New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null; [IO.File]::WriteAllText($path, $text) }

function Build {
    if (Test-Path $root) { Remove-Item -Recurse -Force $root }
    $s = "$root\_classic_beta_"; $d = "$root\_forever_"
    Put "$s\Interface\AddOns\Shared\Shared.toc" 'beta'
    Put "$s\Interface\AddOns\BetaOnly\BetaOnly.toc" 'b'
    Put "$s\WTF\Config.wtf" "SET a `"beta`"`r`nSET portal `"test`"`r`nSET agentUID `"wow_classic_beta`"`r`nSET accountName `"me@example.com`"`r`n"
    Put "$s\WTF\Account\ACC1\bindings-cache.wtf" 'beta binds'
    Put "$s\WTF\Account\ACC1\macros-cache.txt" 'beta macros'
    Put "$s\WTF\Account\ACC1\cache.md5" 'md5'
    Put "$s\WTF\Account\ACC1\SavedVariables\Addon.lua" 'X = 1'
    Put "$s\WTF\Account\ACC1\SavedVariables\Addon.lua.bak" 'old'
    Put "$s\WTF\Account\ACC1\70\Alpha\config-cache.wtf" 'alpha'
    Put "$s\WTF\Account\ACC1\70\Second-Base\config-cache.wtf" 'second'
    Put "$s\WTF\Account\ACC1\70\Second-Base\SavedVariables\Char.lua" 'C = 2'
    Put "$s\WTF\Account\SavedVariables\Global.lua" 'g'
    Put "$d\Interface\AddOns\Shared\Shared.toc" 'forever'
    Put "$d\Interface\AddOns\Shared\Stale.lua" 'stale'
    Put "$d\Interface\AddOns\ForeverOnly\ForeverOnly.toc" 'f'
    Put "$d\WTF\Config.wtf" "SET a `"forever`"`r`nSET portal `"US`"`r`nSET agentUID `"wowf`"`r`n"
    Put "$d\WTF\Account\ACC1\bindings-cache.wtf" 'copied acc'
    Put "$d\WTF\Account\NEW\bindings-cache.wtf" 'default binds'
    Put "$d\WTF\Account\NEW\91\Zeta-Test\AddOns.txt" 'x'
}

# Case 1: every part, target account NEW (2nd), source character Second-Base (2nd), target auto.
Build
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -WowDir $root -SkipProcessCheck -Answers 'y,y,y,y,2,2,n,y' 2>&1
Check ($LASTEXITCODE -eq 0) "case1 exit $LASTEXITCODE`n$($out -join "`n")"
$d = "$root\_forever_"
function Text($p) { if (Test-Path $p) { [IO.File]::ReadAllText($p) } }
Check ((Text "$d\Interface\AddOns\Shared\Shared.toc") -eq 'beta') 'shared addon not replaced'
Check (-not (Test-Path "$d\Interface\AddOns\Shared\Stale.lua")) 'stale file in replaced addon kept'
Check (Test-Path "$d\Interface\AddOns\BetaOnly\BetaOnly.toc") 'beta-only addon not copied'
Check (Test-Path "$d\Interface\AddOns\ForeverOnly\ForeverOnly.toc") 'forever-only addon removed'
# Config.wtf: beta settings, but Forever's own login and client lines.
$cfg = ((Text "$d\WTF\Config.wtf") -split "`r?`n" | Where-Object { $_ } | Sort-Object) -join '|'
Check ($cfg -eq 'SET a "beta"|SET agentUID "wowf"|SET portal "US"') "Config.wtf merge wrong: $cfg"
Check ((Text "$d\WTF\Account\NEW\bindings-cache.wtf") -eq 'beta binds') 'account binds not copied'
Check ((Text "$d\WTF\Account\NEW\macros-cache.txt") -eq 'beta macros') 'account macros not copied'
Check (-not (Test-Path "$d\WTF\Account\NEW\cache.md5")) 'cache.md5 copied'
Check ((Text "$d\WTF\Account\NEW\SavedVariables\Addon.lua") -eq 'X = 1') 'account SavedVariables not copied'
Check (-not (Test-Path "$d\WTF\Account\NEW\SavedVariables\Addon.lua.bak")) '.bak copied'
Check ((Text "$d\WTF\Account\ACC1\bindings-cache.wtf") -eq 'copied acc') 'unselected account changed'
Check ((Text "$d\WTF\Account\NEW\91\Zeta-Test\config-cache.wtf") -eq 'second') 'character settings from wrong source'
Check ((Text "$d\WTF\Account\NEW\91\Zeta-Test\SavedVariables\Char.lua") -eq 'C = 2') 'character SavedVariables not copied'
Check (-not (Test-Path "$d\WTF\Account\SavedVariables\Global.lua")) 'global SavedVariables copied'
$bk = Get-ChildItem $root -Directory -Filter 'beta2forever-backup-*' | Select-Object -First 1
Check ($null -ne $bk) 'no backup folder'
if ($bk) {
    Check ((Text "$($bk.FullName)\WTF\Config.wtf") -like 'SET a "forever"*') 'backup lacks old Config.wtf'
    Check ((Text "$($bk.FullName)\Interface\AddOns\Shared\Stale.lua") -eq 'stale') 'backup lacks old addon'
}

# Case 2: answering no at the final prompt changes nothing.
Build
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -WowDir $root -SkipProcessCheck -Answers 'y,y,y,n,2,n' 2>&1
Check ($LASTEXITCODE -ne 0) 'case2 declined run exited 0'
Check ((Text "$root\_forever_\WTF\Config.wtf") -like 'SET a "forever"*') 'case2 declined run changed files'

# Case 3: a missing target client stops with an error.
Build
Remove-Item -Recurse -Force "$root\_forever_"
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -WowDir $root -SkipProcessCheck -Answers 'y' 2>&1
Check ($LASTEXITCODE -ne 0) 'case3 missing client exited 0'

# Case 4: a locked target file stops the copy and names the backup.
Build
# Shared for reading, so the backup can read it but the copy cannot write it.
$lock = [IO.File]::Open("$root\_forever_\WTF\Account\NEW\bindings-cache.wtf", 'Open', 'Read', 'Read')
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -WowDir $root -SkipProcessCheck -Answers 'n,n,y,n,2,y' 2>&1
$lock.Close()
Check ($LASTEXITCODE -ne 0) 'case4 locked file exited 0'
Check (($out -join "`n") -match 'beta2forever-backup-') "case4 no backup path in message`n$($out -join "`n")"

# Case 5: a file the backup cannot read stops before anything changes, and leaves no backup folder.
Build
$lock = [IO.File]::Open("$root\_forever_\WTF\Account\NEW\bindings-cache.wtf", 'Open', 'Read', 'None')
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -WowDir $root -SkipProcessCheck -Answers 'y,y,y,n,2,y' 2>&1
$lock.Close()
Check ($LASTEXITCODE -ne 0) 'case5 unreadable file exited 0'
Check (($out -join "`n") -match 'Nothing was changed') "case5 message`n$($out -join "`n")"
Check ((Text "$root\_forever_\WTF\Config.wtf") -like 'SET a "forever"*') 'case5 changed files'
Check (-not (Get-ChildItem $root -Directory -Filter 'beta2forever-backup-*')) 'case5 left a backup folder'

Remove-Item -Recurse -Force $root
if ($fails) { $fails | ForEach-Object { "FAIL: $_" }; exit 1 }
'PASS'
