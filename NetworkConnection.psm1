#Get public and private function definition files.
    $Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
    $Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
    Foreach($import in @($Public+$Private))
    {
        Try
        {
            . $import.fullname
        }
        Catch
        {
            Write-Error -Message "Failed to import function $($import.fullname): $_"
        }
    }

#Load Enumerations
    $EnumFile = "$PSScriptRoot\Private\Enum.ps1"
    if (Test-Path $EnumFile) {
        #$Enum = Get-Content -Path $EnumFile -Raw
        Write-Verbose 'Loading Enumerations'
        #Invoke-Expression -Command $Enum
        . $EnumFile
    }