function New-DynamicParameter {

<#
.SYNOPSIS
    Create a dynamic parameter based on the given options

.EXAMPLE
    $params = @{
        Name = 'PortName'
        Type = [string]
        ValidatedSet = 'AD','DHCP','DNS'
        ParameterSetName = 'PortName'
        Mandatory = $true
    }
    $ParamObj = New-DynamicParameter @params
    # you can then add that to the dictionary like so:
    $Dictionary.Add($Params.Name, $ParamObj)

#>

[CmdletBinding(DefaultParameterSetName='PortName')]
[OutputType('System.Management.Automation.RuntimeDefinedParameter')]
Param(

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Type,

    [Parameter()]
    [string[]]$ValidatedSet,

    [Parameter()]
    [string]$ParameterSetName = '__AllParameterSets',

    [Parameter()]
    [switch]$Mandatory = $false,

    [Parameter()]
    [string]$HelpMessage,

    [Parameter()]
    [switch]$ValueFromPipeLine = $false,

    [Parameter()]
    [switch]$ValidateNotNullorEmpty = $false

)

$SMA       = 'System.Management.Automation'
$AttribCol = New-object System.Collections.ObjectModel.Collection[System.Attribute]
$Attribute = New-Object "$SMA.ParameterAttribute"

if ($PSBoundParameters.ContainsKey('ParameterSetName')) {
    $Attribute.ParameterSetName = $ParameterSetName
}

if ($PSBoundParameters.ContainsKey('ValidatedSet')) {
    $SetValues = New-Object "$SMA.ValidateSetAttribute"($ValidatedSet)
    $AttribCol.Add($SetValues)
}

if ($Mandatory) {
    $Attribute.Mandatory = $true
}

if ($PSBoundParameters.ContainsKey('HelpMessage')) {
    $Attribute.HelpMessage = $HelpMessage
}

if ($ValueFromPipeLine) {
    $Attribute.$ValueFromPipeLine = $true
}

if ($ValidateNotNullorEmpty) {
    $NotNullFlag = New-Object "$SMA.ValidateNotNullOrEmptyAttribute"
    $AttribCol.Add($NotNullFlag)
}

$AttribCol.Add($Attribute)

$ParamObj = New-Object "$SMA.RuntimeDefinedParameter"($Name, $Type, $AttribCol)

Write-Output $ParamObj

}