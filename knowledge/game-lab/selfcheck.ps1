# game-lab workspace selfcheck — data + scripts + skills + tools.
# Run before a game research session.
$fail = 0
function Ok($cond, $msg) {
    if ($cond) { "[OK] $msg" } else { "[FAIL] $msg"; $script:fail++ }
}

$ks = @('game-engine-detection','game-memory-lab','game-modding-lab','anti-cheat-architecture','game-research-tool-discovery')
foreach ($n in $ks) {
    Ok (Test-Path "$env:USERPROFILE\.agents\skills\$n\SKILL.md") "own skill $n present"
}
Ok ((Get-ChildItem "$env:USERPROFILE\.agents\skills" | Where-Object { $_.LinkType -eq 'Junction' }).Count -ge 20) 'junctioned external skills >=20'
Ok (Test-Path 'D:\opencode\game-lab\knowledge\DISCOVERY_SHEET.md') 'DISCOVERY_SHEET present'
Ok (Test-Path 'D:\opencode\game-lab\knowledge\ac_stack_map_50games.md') 'AC stack map present'
Ok (Test-Path 'D:\opencode\game-lab\knowledge\games_registry\registry.json') '50-game research registry present'

py -3 -m py_compile 'D:\opencode\game-lab\scripts\engine_fingerprint.py'
Ok ($LASTEXITCODE -eq 0) 'engine_fingerprint.py compiles'
py -3 'D:\opencode\game-lab\scripts\game_registry.py' --validate
Ok ($LASTEXITCODE -eq 0) 'games registry validates (50 rows, tags, schema)'

Ok (Test-Path 'C:\Program Files\Cheat Engine\cheatengine-x86_64.exe') 'Cheat Engine installed (C:\Program Files)'
Ok (Test-Path 'D:\Tools\x64dbg\release\x64\x64dbg.exe') 'x64dbg present'
Ok (Test-Path 'D:\Tools\ReClass.NET\x64') 'ReClass.NET x64 binaries present'
Ok (Test-Path 'D:\Tools\Il2CppDumper\Il2CppDumper.exe') 'Il2CppDumper present'
Ok (Test-Path 'D:\Tools\Cpp2IL\Cpp2IL.exe') 'Cpp2IL present'
Ok (Test-Path 'D:\Tools\dnSpy\dnSpy.exe') 'dnSpy present'
Ok (Test-Path 'D:\Tools\ghidra_12.1.4_PUBLIC\support\analyzeHeadless.bat') 'Ghidra headless available'
Ok (Test-Path 'C:\Program Files\RenderDoc\qrenderdoc.exe') 'RenderDoc GUI present'
Ok (Test-Path 'D:\Tools\ghidra-mcp') 'local ghidra-mcp fork present (backup path)'

if ($fail -eq 0) { exit 0 } else { exit 1 }
