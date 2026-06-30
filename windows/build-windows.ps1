param(
  [string]$Configuration = "Release",
  [string]$Runtime = "win-x64",
  [string]$Output = "artifacts/Hunter-Windows"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $PSScriptRoot "Hunter.Windows/Hunter.Windows.csproj"
$Tests = Join-Path $PSScriptRoot "Hunter.Windows.Tests/Hunter.Windows.Tests.csproj"
$PublishDir = Join-Path $Root $Output

dotnet restore $Project
dotnet build $Project -c $Configuration --no-restore
dotnet run --project $Tests -c $Configuration
dotnet publish $Project -c $Configuration -r $Runtime --self-contained true -p:PublishSingleFile=false -o $PublishDir

$Exe = Join-Path $PublishDir "Hunter.Windows.exe"
& $Exe --smoke-core
& $Exe --smoke-voice-control "监督我接下来的 40 分钟"
& $Exe --smoke-package-info

$ZipPath = Join-Path (Split-Path -Parent $PublishDir) "Hunter-Windows-$Runtime.zip"
if (Test-Path $ZipPath) {
  Remove-Item $ZipPath -Force
}
Compress-Archive -Path (Join-Path $PublishDir "*") -DestinationPath $ZipPath
Write-Host "WINDOWS_PACKAGE=$ZipPath"
