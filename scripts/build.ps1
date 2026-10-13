param(
    [ValidateSet('Win32', 'Win64', 'All')]
    [string]$Platform = 'All',
    [string]$DelphiBin = '',
    [string]$OutputRoot = 'build',
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = if ([IO.Path]::IsPathRooted($OutputRoot)) { $OutputRoot } else {
    Join-Path $projectRoot $OutputRoot
}

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
    $outputDir = Join-Path $buildRoot $target
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    $common = @('-B', '-Q', "-E$outputDir", "-N0$outputDir", "-U$outputDir")
    $packageOptions = $common + @("-LN$outputDir", "-LE$outputDir")
    Invoke-Compiler $compiler (Join-Path $projectRoot 'packages') ($packageOptions + 'SkyLogRuntime.dpk')
    $delphiRoot = Split-Path -Parent (Split-Path -Parent $compiler)
    $designPackage = Join-Path $delphiRoot "lib\$target\release\designide.dcp"
    if ($target -eq 'Win64' -and -not (Test-Path -LiteralPath $designPackage)) {
        Write-Host 'IDE desta instalacao e Win32: pacote de design compilado somente em Win32.'
    }
    else {
        Invoke-Compiler $compiler (Join-Path $projectRoot 'packages') ($packageOptions + 'SkyLogDesign.dpk')
    }
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
Write-Host "Compilacao concluida. Saidas em $buildRoot (Win32 e/ou Win64)."
