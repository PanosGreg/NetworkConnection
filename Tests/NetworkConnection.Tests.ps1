<#
.SYNOPSIS
    This is an integration testing script for the NetworkConnection module.

    This will test the functions if they actually work. It won't run unit tests against
    the function's internal code. It will run integration tests against the function's results.

.DESCRIPTION
    This will automate the testing of the following scenarios:
    - connect with each transport method (pipes, tcp,udp,http)
        - connect using a user provided port number
        - connect using a random port number
    - try to connect with and without creating a firewall rule
    - send and receive data with each transport method
    - make sure timeout works

.EXAMPLE
    Invoke-Pester -Script @{
        Path       = 'D:\Code\NetworkConnection\Module\Tests\NetworkConnection.Tests.ps1'
        Parameters = @{
            ComputerName = 'dr-its-man5'
        }
    } -Tag 'tcp'

.EXAMPLE
    $Server = 'dr-its-man5'
    $Script = 'D:\Code\NetworkConnection\Module\Tests\NetworkConnection.Tests.ps1'
    $OutXml = 'D:\temp3\TestReports\Results.xml'
    $OutHtm = 'D:\temp3\TestReports\Results\'
    $Params = @{Path=$Script;Parameters=@{ComputerName=$Server}}
    Invoke-Pester -Script $Params -OutputFormat NUnitXml -OutputFile $OutXml -Show None
    D:\temp3\TestReports\extent.exe -i  $OutXml -o $OutHtm
    start chrome (Join-Path $OutHtm dashboard.html)

    # NOTE: the extent.exe can be downloaded from here:
    #       https://github.com/extent-framework/extentreports-dotnet-cli/raw/master/dist/extent.exe

.NOTES
    This function requires admin rights to run.
    There are 2 things that need elevated access:
    - The -AllowFirewall parameter on the Start-ServerConnection function, creates a new rule in the Windows Firewall
      which allows PowerShell.exe to communicate over the specified port
    - The 'HTTP' option in the -Transport parameter of the Start-ServerConnection function, starts an HTTP server
      that listens on any IP (not just the loopback)
#>

#Requires -RunAsAdministrator

Param(

    [Parameter(Position=0,ValueFromPipeline)]
    [ValidateNotNullorEmpty()]
    [string]$ComputerName= 'dr-its-man5'
)

#region --------------------------------------------------- Variables
$here = $PSScriptRoot              # <-- \Module\Tests\
$root = Split-Path -Parent $here   # <-- \Module\
$psd1 = (Get-ChildItem -Path $root -Filter *.psd1).FullName
$sut  = (Get-ChildItem -Path $root -Filter *.psd1).BaseName
$srv  = $env:COMPUTERNAME
if (-not (Test-Path -Path $psd1)) {Throw 'Could not find .psd1 file'}
#endregion

#region --------------------------------------------------- Preparation
try {
    if (-not (Test-Path \\$ComputerName\c$\Temp)) {New-Item -Path \\$ComputerName\c$\Temp -ErrorAction Stop}
    Copy-Item -Path $root -Destination \\$ComputerName\c$\Temp -Recurse -Force -ErrorAction Stop
}
catch {Throw $_ }
try   {$sess = New-PSSession -ComputerName $ComputerName -Verbose:$false}
catch {Throw $_}
#endregion

Describe '- Load module' -Tag 'TCP','UDP', 'HTTP', 'Pipes' {
    It "It imports the module $sut" {
        $module = Import-Module $psd1 -DisableNameChecking -PassThru
        $module.Name | Should -Be $sut
    }

    It "It imports the module on the remote $ComputerName" {
        Start-Sleep -Milliseconds 500
        $RemoteModule = Invoke-Command -Session $sess -ScriptBlock {
            $folder = Split-Path $using:root -Leaf
            Import-Module "C:\Temp\$folder\$using:Sut" -DisableNameChecking -PassThru
        }
        $RemoteModule.Name | Should -Be $sut
    }
}

$list = Get-ChildItem -Path $here -Filter Test*.ps1
$list | Get-Random -Count $list.count | foreach {
    $Text = Get-Content -Path $_.FullName -Raw
    Invoke-Expression -Command $Text
}

#region --------------------------------------------------- Clean up
$sess | Remove-Pssession 
Remove-Module $sut,NetSecurity -ErrorAction SilentlyContinue
Remove-Item -Path \\$ComputerName\c$\Temp\$(Split-Path $root -Leaf) -Recurse -Force
#endregion