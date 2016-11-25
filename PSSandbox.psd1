@{
RootModule = 'PSSandbox.psm1'
ModuleVersion = '0.1'
GUID = '46bead82-42c5-4b2b-bdff-1c680125e4ae'
Description = 'Module to setup a local PowerShell sandbox session'
PowerShellVersion = '5.0'
RequiredModules = @('PSReadline')
AliasesToExport = @('PSConsoleHostReadline', 'TabExpansion2', 'prompt')
FunctionsToExport = @('Use-Sandbox', 'Read-ConsoleHostLine', 'Expand-Tab', 'Show-Prompt', 'Start-Sandbox')
CmdletsToExport = @()
}
