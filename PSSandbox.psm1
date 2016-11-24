using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Management.Automation.Runspaces
using namespace Microsoft.PowerShell.Commands

$Script:InSandbox = $false
$Script:PowerShell = $null
$Script:OrigPrompt = Get-Item function:\prompt | % Definition
$Script:HelpCommands = @"
Help Commands:
Type '?' or 'help' to show this help.
Type 'quit' or 'exit' to exit the Sandbox.
"@

## Level directory is hard coded for now
$Script:CurrentLevelDir = Join-Path $PSScriptRoot Level1

function Read-ConsoleHostLine
{
    Microsoft.PowerShell.Core\Set-StrictMode -Off
    $in = [Microsoft.PowerShell.PSConsoleReadLine]::ReadLine($Host.Runspace, $ExecutionContext)
    
    if ($Script:InSandbox)
    {
        $in = "Use-Sandbox '{0}'" -f [CodeGeneration]::EscapeSingleQuotedStringContent($in)
    }

    return $in
}


function Expand-Tab
{
    [CmdletBinding(DefaultParameterSetName = 'ScriptInputSet')]
    Param(
        [Parameter(ParameterSetName = 'ScriptInputSet', Mandatory = $true, Position = 0)]
        [string] $inputScript,
    
        [Parameter(ParameterSetName = 'ScriptInputSet', Mandatory = $true, Position = 1)]
        [int] $cursorColumn,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory = $true, Position = 0)]
        [Ast] $ast,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory = $true, Position = 1)]
        [Token[]] $tokens,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory = $true, Position = 2)]
        [IScriptPosition] $positionOfCursor,
    
        [Parameter(ParameterSetName = 'ScriptInputSet', Position = 2)]
        [Parameter(ParameterSetName = 'AstInputSet', Position = 3)]
        [Hashtable] $options = $null
    )

    if ($Script:InSandbox) {
        Invoke-Script -command "TabExpansion2" -parameters $PSBoundParameters
    } else {
        global:TabExpansion2 @PSBoundParameters
    }
}


function Show-Prompt
{
    if ($Script:InSandbox) {
        Invoke-Script -script $Script:OrigPrompt
    } else {
        global:prompt
    }
}


function Use-Sandbox
{
    param([string]$in)

    Write-Debug "Intercept input: <$in>"

    switch ($in)
    {
        {$_ -eq "?" -or $_ -eq "help"} {
            Write-Host $Script:HelpCommands
            break
        }

        {$_ -eq "quit" -or $_ -eq "exit"}  {
            $Script:InSandbox = $false
            if ($Script:PowerShell)
            {
                $Script:PowerShell.Dispose()
            }

            break
        }
        
        default {
            if ($Script:InSandbox)
            {
                Invoke-Script -script $in
            }
            else
            {
                [scriptblock]::create($in).Invoke()
            }
        }
    }
}


function Start-Game
{
    $Script:InSandbox = $true
    $Script:PowerShell = [powershell]::Create()

    $Script:PowerShell.Runspace = New-CustomizedRunspace
}


function New-CustomizedRunspace
{
    $iss = [initialsessionstate]::CreateDefault()
    $iss.ThrowOnRunspaceOpenError = $true
    
    foreach ($provider in $iss.Providers)
    {
        if ($provider.Name -cne [FileSystemProvider]::ProviderName)
        {
            $provider.Visibility = [SessionStateEntryVisibility]::Private
        }
    }

    ## Import the game init module when opening the runspace
    ## Run startup script to set up game environment
    $iss.ImportPSModule((Join-Path $Script:CurrentLevelDir "Init.psm1"))
    $iss.StartupScripts.Add((Join-Path $Script:CurrentLevelDir "startup.ps1")) > $null
    
    ## Process proxy commands
    $proxyTable = Get-ProxyCommand
    foreach ($proxy in $proxyTable.GetEnumerator())
    {
        $originalCmds = $iss.Commands[$proxy.Key]
        $originalCmds[0].Visibility = [SessionStateEntryVisibility]::Private

        if ($proxy.Value)
        {
            $iss.Commands.Add([SessionStateFunctionEntry]::new($proxy.Key, $proxy.Value))
        }
    }

    $runspace = [runspacefactory]::CreateRunspace($Host, $iss)
    $runspace.Open()

    return $runspace
}


function Get-ProxyCommand
{
    $table = @{"New-PSDrive" = $null }

    $setLocationProxyBody = Get-Content -Raw -Path (Join-Path $Script:CurrentLevelDir "Set-Location.ps1")
    $getPSDriveProxyBody = Get-Content -Raw -Path (Join-Path $Script:CurrentLevelDir "Get-PSDrive.ps1")

    $table["Set-Location"] = $setLocationProxyBody
    $table["Get-PSDrive"] = $getPSDriveProxyBody

    return $table
}


function Invoke-Script
{
    [CmdletBinding(DefaultParameterSetName = "Script")]
    param(
        [Parameter(Position = 0, ParameterSetName = "Script")]
        [string]$script,

        [Parameter(ParameterSetName = "Command")]
        [string]$command,

        [Parameter(ParameterSetName = "Command")]
        [System.Collections.IEnumerable]$parameters
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq "Script") {
            $Script:PowerShell.AddScript($script) > $null
            $Script:PowerShell.Invoke()

            ## TODO: Handle all streams, in a streaming way
            foreach ($err in $Script:PowerShell.Streams.Error) {
                Write-Error -ErrorRecord $err
            }
        } else {
            $Script:PowerShell.AddCommand($command) > $null
            if ($parameters) {
                foreach ($entry in $parameters.GetEnumerator()) {
                    $Script:PowerShell.AddParameter($entry.Key, $entry.Value) > $null
                }
            }
            $Script:PowerShell.Invoke()
        }
    } finally {
        $Script:PowerShell.Commands.Clear()
        $Script:PowerShell.Streams.Error.Clear()
    }
}


Set-Alias -Name PSConsoleHostReadline -Value Read-ConsoleHostLine
Set-Alias -Name TabExpansion2 -Value Expand-Tab
Set-Alias -Name prompt -Value Show-Prompt

Export-ModuleMember -Function Use-Sandbox, Read-ConsoleHostLine, Expand-Tab, Show-Prompt, Start-Game `
                    -Alias PSConsoleHostReadline, TabExpansion2, prompt
