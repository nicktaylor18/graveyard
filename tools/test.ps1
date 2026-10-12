param([string]$Godot = 'C:\Program Files\Godot\Godot.exe', [switch]$UserData)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $Godot)) {
    $Godot = (Get-Command godot -ErrorAction Stop).Source
}
$testArgs = @('--headless', '--path', ('"{0}"' -f $projectRoot), '--log-file', 'tests.log', '--script', 'tests/run_tests.gd')
if ($UserData) { $testArgs += @('--', '--user-data') }
$testProcess = Start-Process -FilePath $Godot -ArgumentList $testArgs -PassThru -Wait -WindowStyle Hidden
$testLog = Get-Content -LiteralPath (Join-Path $projectRoot 'tests.log') -Raw
Write-Output $testLog
if ($testProcess.ExitCode -ne 0 -or $testLog -notmatch 'RESULT / \d+ checks / 0 failures' -or $testLog -match 'SCRIPT ERROR') {
    exit 1
}
exit 0
