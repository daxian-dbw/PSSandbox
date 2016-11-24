
$GameRoot = Join-Path ([System.IO.Path]::GetTempPath()) "PSGame"
if (Test-Path $GameRoot -PathType Container) {
    Remove-Item $GameRoot -Recurse -Force
}

New-Item -Path $GameRoot -ItemType Directory -Force > $null
New-PSDrive -Name Lab-43 -PSProvider FileSystem -Root $GameRoot -Scope Global -Description "Secret Bio-Research Lab"
Set-Location -Path Lab-43:\
New-Item -Path Lab-43:\Floor-1, Lab-43:\Floor-2, Lab-43:\Floor-3 -ItemType Directory -Force
New-Item -Path Lab-43:\Floor-1\Room-101, Lab-43:\Floor-1\Room-105, Lab-43:\Floor-1\Hallway -ItemType Directory -Force

## TODO: Should remove the GameRoot fodler when the runspace is exiting, but seems not working
Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PSEngineEvent]::Exiting) `
                     -Action ([scriptblock]::Create("Remove-Item $GameRoot -Recurse -Force"))
