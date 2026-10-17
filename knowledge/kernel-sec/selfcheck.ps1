# kernel-sec workspace selfcheck — passive verification of data + scripts + tools.
# Run before any driver research session: powershell -File selfcheck.ps1
$fail = 0
function Ok($cond, $msg) {
    if ($cond) { "[OK] $msg" } else { "[FAIL] $msg"; $script:fail++ }
}

$feed = 'D:\opencode\kernel-sec\knowledge\lol_drivers.json'
Ok ((Test-Path $feed) -and ((Get-Item $feed).Length -gt 1MB)) 'LOLDrivers feed cached (>1MB)'

py -3 -m py_compile 'D:\opencode\kernel-sec\scripts\driver_triage.py'
Ok ($LASTEXITCODE -eq 0) 'driver_triage.py compiles'
py -3 -m py_compile 'D:\opencode\kernel-sec\scripts\feed_query.py'
Ok ($LASTEXITCODE -eq 0) 'feed_query.py compiles'

$out = py -3 'D:\opencode\kernel-sec\scripts\driver_triage.py' 'C:\Windows\System32\drivers\acpi.sys' 2>&1 | Out-String
Ok ($out -match 'feed ok') 'canary triage (acpi.sys) reaches the feed'

Ok (Test-Path 'D:\Tools\ghidra_12.1.4_PUBLIC\support\analyzeHeadless.bat') 'Ghidra headless available'
Ok (Test-Path 'D:\Windows Kits\10\Debuggers\x64\windbg.exe') 'WinDbg available'
Ok (Test-Path 'C:\Windows\System32\CodeIntegrity\driver.stl') 'MS vulnerable-driver blocklist store present'
Ok (Test-Path 'D:\opencode\kernel-sec\knowledge\ms_blocklist_rules.html') 'MS blocklist rules page cached'
Ok (Test-Path "$env:USERPROFILE\.config\opencode\agents\ksec-validator.md") 'ksec-validator agent file present'
Ok (Test-Path "$env:USERPROFILE\.agents\skills\windows-driver-security\SKILL.md") 'windows-driver-security skill file present'
Ok (Test-Path 'D:\opencode\kernel-sec\knowledge\README.md') 'evidence sheets README present'

if ($fail -eq 0) { exit 0 } else { exit 1 }
