param(
    [ValidateSet('Win32', 'Win64', 'All')]
    [string]$Platform = 'All',
    [string]$DelphiBin = '',
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Compiler {
    param([string]$Compiler, [string]$WorkingDirectory, [string[]]$Arguments)
    Push-Location $WorkingDirectory
    try {
        & $Compiler @Arguments
        if ($LASTEXITCODE -ne 0) { throw "Falha do compilador (codigo $LASTEXITCODE)." }
    }
    finally { Pop-Location }
}

$targets = if ($Platform -eq 'All') { @('Win32', 'Win64') } else { @($Platform) }
foreach ($target in $targets) {
    $compilerName = if ($target -eq 'Win32') { 'dcc32.exe' } else { 'dcc64.exe' }
    $compiler = if ($DelphiBin) { Join-Path $DelphiBin $compilerName } else {
        (Get-Command $compilerName -ErrorAction Stop).Source
    }
    $outputDir = Join-Path $projectRoot "build\$target"
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    $common = @('-B', '-Q', "-E$outputDir", "-N0$outputDir", "-U$outputDir")
    $packageOptions = $common + @("-LN$outputDir", "-LE$outputDir")
    Invoke-Compiler $compiler (Join-Path $projectRoot 'packages') ($packageOptions + 'SkyLogRuntime.dpk')
    Invoke-Compiler $compiler (Join-Path $projectRoot 'packages') ($packageOptions + 'SkyLogDesign.dpk')
    Invoke-Compiler $compiler (Join-Path $projectRoot 'tests') ($common + 'SkyLog.Tests.dpr')
    Invoke-Compiler $compiler (Join-Path $projectRoot 'examples') ($common + 'SkyLogDemo.dpr')
    if (-not $SkipTests) {
        & (Join-Path $outputDir 'SkyLog.Tests.exe')
        if ($LASTEXITCODE -ne 0) { throw "Testes falharam em $target." }
        $smoke = Start-Process -FilePath (Join-Path $outputDir 'SkyLogDemo.exe') -ArgumentList '-smoke' -WindowStyle Hidden -PassThru
        if (-not $smoke.WaitForExit(15000)) {
            Stop-Process -Id $smoke.Id
            throw "Demo nao terminou em 15 segundos ($target)."
        }
        if ($smoke.ExitCode -ne 0) { throw "Demo falhou em $target." }
    }
}
Write-Host 'Compilacao concluida. Saidas em build\Win32 e/ou build\Win64.'
