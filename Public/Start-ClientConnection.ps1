function Start-ClientConnection {

<#



#>

[CmdletBinding(DefaultParameterSetName='PortName')]
Param(

    [Parameter(Position=0,Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [Alias('CN')]
    [string]$ComputerName,

    [Parameter(Position = 1)]
    [ValidateSet('Pipes','TCP','UDP','HTTP')]
    [string]$Transport = 'Pipes',
    [int]$Timeout = 5

)

DynamicParam {
    $DynamicParam = $true
    $ParamTable   = [System.Collections.ArrayList]@()
    $DefaultValue = @{}
    switch ($Transport) {
        'Pipes' { 
            $DefValue  = '{0}.PSRemoting.{1}' -f $Env:COMPUTERNAME,[guid]::NewGuid().guid.substring(30)
            [void]$ParamTable.Add(@{Name='PipeName';Type=[string];ParameterSetName='PortName'}) 
            $DefaultValue['PipeName']=$DefValue }
        'TCP' {
            $SetValues = 'RDP,SCCM,Sophos,Lync,AD,LDAP,SCOM,Random'.Split(',')
            [void]$ParamTable.Add(@{Name='PortName';Type=[string];ValidatedSet=$SetValues;ParameterSetName='PortName'})
            [void]$ParamTable.Add(@{Name='PortNumber';Type=[int];ParameterSetName='PortNumber'})
            $DefaultValue['PortName']   = 'Sophos'
            $DefaultValue['PortNumber'] = 9999 }
        'UDP' {
            $SetValues = 'DHCP,DNS,Random'.Split(',')
            [void]$ParamTable.Add(@{Name='PortName';type=[string];ValidatedSet=$SetValues;ParameterSetName='PortName'})
            [void]$ParamTable.Add(@{Name='PortNumber';Type=[int];ParameterSetName='PortNumber'})
            $DefaultValue['PortName']   = 'DNS'
            $DefaultValue['PortNumber'] = 9999 }
        'HTTP' {
            [void]$ParamTable.Add(@{Name='PortNumber';Type=[int]})
            $DefaultValue['PortNumber'] = 80 }
        default {$DynamicParam = $false}
    }

    if ($DynamicParam) {
        $SMA        = 'System.Management.Automation'
        $Dictionary = New-Object "$SMA.RuntimeDefinedParameterDictionary"

        foreach ($p in $ParamTable) {
            $ParamObj = New-DynamicParameter @p
            $Dictionary.Add($p.Name,$ParamObj)
        }

        return $Dictionary
    }
    else {return}
} # DynamicParam

Begin {
    $OutputObj = Get-ConnectionObject
} #begin

Process {

    if ($Transport -eq 'Pipes') {
        $PipeName     = if ($PSBoundParameters.ContainsKey('PipeName')) {$PSBoundParameters['PipeName']}
                        else {$DefaultValue['PipeName']}
        $PipeDir      = [System.IO.Pipes.PipeDirection]::InOut
        $PipeOpt      = [System.IO.Pipes.PipeOptions]::None
        $PipeLvl      = [System.Security.Principal.TokenImpersonationLevel]::Impersonation
        $Constructor  = $ComputerName, $PipeName, $PipeDir, $PipeOpt, $PipeLvl
        try  {$Stream = New-Object System.IO.Pipes.NamedPipeClientStream($Constructor)}
        catch{Throw $_ }
        try  {$Stream.Connect(($Timeout*1000))}
        catch{
            $Stream.Dispose()
            Throw "Pipe client connection failed. $($_.Exception.Message)"
        }
        if ($Stream.NumberOfServerInstances -ge 1) {
            $msg = "$(Prefix)There is/are currently {0} pipe server instance(s) open" -f $Stream.NumberOfServerInstances
            Write-Verbose $msg
        }
        else { Throw 'There is no open server instance' }

        try   { $OutputObj.StreamReader  = [System.IO.StreamReader]::new($Stream)
                $OutputObj.StreamWriter  = [System.IO.StreamWriter]::new($Stream)
                $OutputObj.StreamWriter.AutoFlush = $true }
        catch { Throw "Couldn't start the stream reader/writer" }
        $OutputObj.Mode         = [ConnectionMode]::PipesClient
        $OutputObj.PipeClient   = $Stream

    } #if Pipes

    if ($Transport -eq 'TCP') {
        $ServerPort      = if ($PSBoundParameters.ContainsKey('PortName')) {[PortNumber]::($PSBoundParameters['PortName']).Value__}
                           elseif ($PSBoundParameters.ContainsKey('PortNumber')) {$PSBoundParameters['PortNumber']}
                           else {[PortNumber]::($DefaultValue['PortName']).Value__}
        $TcpClient       = New-Object System.Net.Sockets.TcpClient
        $TcpClient.Client.ReceiveTimeout = $Timeout * 1000

        $Stopwatch       = [Diagnostics.Stopwatch]::StartNew()
        while ($true) {
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                $TcpClient.Dispose()
                $Stopwatch.Stop()
                Throw "Timeout exceeded`n$ConnectionError"
            }
            else {
                try {
                    $TcpClient.Connect($ComputerName,$ServerPort) # <-- this blocks until it connects or fails (which fails in about ~1sec)
                    $Stopwatch.Stop()
                    Write-Verbose "$(Prefix)Connected to server $($ComputerName):$($ServerPort)"
                    Break
                }
                catch {$ConnectionError = $_}
            }
        }
        # NOTE: I'm not using the Begin/End Connect() methods, because that way you always had to
        #       start the server first and then the client in order for the connection to work.
        #       but now you can start either one and it will still connect, within the timeout limit.
        $Stream              = $TcpClient.GetStream()

        try   { $OutputObj.StreamReader  = [System.IO.StreamReader]::new($Stream)
                $OutputObj.StreamWriter  = [System.IO.StreamWriter]::new($Stream)
                $OutputObj.StreamWriter.AutoFlush = $true }
        catch { Throw "Couldn't start the stream reader/writer" }
        $OutputObj.Mode      = [ConnectionMode]::TcpClient
        $OutputObj.TcpClient = $TcpClient
        $OutputObj.TcpStream = $Stream

    } #if TCP

    if ($Transport -eq 'UDP') {
        $ServerPort   = if ($PSBoundParameters.ContainsKey('PortName')) {[PortNumber]::($PSBoundParameters['PortName']).Value__}
                        elseif ($PSBoundParameters.ContainsKey('PortNumber')) {$PSBoundParameters['PortNumber']}
                        else {[PortNumber]::($DefaultValue['PortName']).Value__}
        
        # check if the ComputerName given by the user is an IP or a Name (no matter Netbios Name or FQDN)
        if ([ipaddress]::TryParse($ComputerName,[ref]$null)) {
            $ServerIP = ([System.Net.IPAddress]$ComputerName).Address   # <-- we need the int64 and not the IP string
        }
        else {
            $AllIPs   = [System.Net.DNS]::GetHostEntry($ComputerName).AddressList
            $ServerIP = $AllIPs.where({$_.AddressFamily -eq 'InterNetwork'})[0].Address
        }

        $SendEndpoint = [System.Net.IPEndPoint]::new($ServerIP,$ServerPort)
        $UdpClient    = [System.Net.Sockets.UdpClient]::new()
        $UdpClient.Connect($SendEndpoint)

        $ClientIP     = $UdpClient.Client.LocalEndPoint.Address.ToString()
        $ClientPort   = $UdpClient.Client.LocalEndPoint.Port
        $RecvEndPoint = [System.Net.IPEndPoint]::new([System.Net.IPAddress]$ClientIP,$ClientPort)
        $Data         = [Text.Encoding]::ASCII.GetBytes("$ClientIP,$ClientPort")
        
        $UdpClient.Client.ReceiveTimeout = 10
        $Stopwatch    = [Diagnostics.Stopwatch]::StartNew()
        while ($true) {
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                $UdpClient.Dispose()
                $Stopwatch.Stop()
                Throw 'Timeout exceeded'
            }            
            $in = try {[Text.Encoding]::ASCII.GetString($UdpClient.Receive([ref]$RecvEndPoint))}
                  catch {$null}
            if ($in -eq 'OK') {Break}
            [void]$UdpClient.Send($Data,$Data.Length)
        }
        # NOTE: I'm not using .Begin/EndSend() and the corresponding $Connect (IAsyncResult) variable
        #       cause EndSend() does NOT block, even though MSDN says it does
        $Stopwatch.Stop()
        Write-Verbose "$(Prefix)Connected to server $($ComputerName):$($ServerPort)"
        $UdpClient.Client.ReceiveTimeout = $Timeout*1000

        $OutputObj.Mode               = [ConnectionMode]::UdpClient
        $OutputObj.UDP                = $UdpClient
        $OutputObj.UdpSendEndpoint    = $UdpClient.Client.RemoteEndPoint
        $OutputObj.UdpReceiveEndpoint = $UdpClient.Client.LocalEndPoint

    } #if UDP

    if ($Transport -eq 'HTTP') {
        $ServerPort   = if ($PSBoundParameters.ContainsKey('PortNumber')) {$PSBoundParameters['PortNumber']}
                        else {$DefaultValue['PortNumber']}
        $URL                = 'Http://{0}:{1}/' -f $ComputerName,$ServerPort
        $HttpClient         = [System.Net.HttpWebRequest]::Create($URL)
        $HttpClient.Method  = 'GET'
        $HttpClient.Timeout = $Timeout*1000

        try   { $Connect = $HttpClient.BeginGetResponse($null,$null) }
        catch { Throw $_}
        $Stopwatch       = [Diagnostics.Stopwatch]::StartNew()
        while (-not $Connect.IsCompleted) {
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                $HttpClient.Abort()
                $Stopwatch.Stop()
                Throw 'Timeout exceeded'
            }
        }
        $Stopwatch.Stop()
        try   {
            $Response = $HttpClient.EndGetResponse($Connect)
            Write-Verbose "$(Prefix)Connected to server $($ComputerName):$($ServerPort)"
            $Response.Close()
        }
        catch {
            $HttpClient.Abort()
            Throw $_
        }

        $OutputObj.Mode        = [ConnectionMode]::HttpClient
        $OutputObj.HttpClient  = $HttpClient

    } #if HTTP

} #process

End {

    Write-Output $OutputObj
    
}

} #function