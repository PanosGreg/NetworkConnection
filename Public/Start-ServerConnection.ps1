function Start-ServerConnection {

<#
.SYNOPSIS
    It starts a network server based on parameters given. This function supports servers based on
    generic TCP or UDP ports, Named Pipes and HTTP.
.EXAMPLE
    ### first we'll set up a new client-server connection, we'll use the TCP transport for this one

    # open 2 powershell sessions, one will be the server and the other one will be the client

    # on the server
    $con = Start-ServerConnection -Transport TCP -PortNumber 1202 -Timeout 30 -Verbose
    # let's say your local IP is 192.168.0.52
    
    # and now on the client
    $con = Start-ClientConnection -ComputerName 192.168.0.52 -Transport TCP -PortNumber 1202 -Verbose

    ### now let's send some data over the connection

    # from either the server or the client
    SendTo-NetworkConnection -Connection $con -Data 'abcd'

    # and then on the other end
    ReceiveFrom-NetworkConnection -Connection $con


    ### finally to close the connection

    # from both the server and the client
    Stop-NetworkConnection -Connection $con -Verbose

.EXAMPLE
    ### another example, using the Names Pipes transport here

    # open 2 powershell sessions, one will be the server and the other one will be the client

    # on the server
    $con = Start-ServerConnection -Transport Pipes -PipeName MyConnection -Timeout 30 -Verbose

    # on the client
    $con = Start-ClientConnection -ComputerName 192.168.0.52 -Transport Pipes -PipeName MyConnection -Verbose

    # from either endpoint (client or server)
    SendTo-NetworkConnection -Connection $con -Data '1234'

    # from the other end
    ReceiveFrom-NetworkConnection -Connection $con

    ### finally close the connection

    # from both the server and the client
    Stop-NetworkConnection -Connection $con -Verbose

.EXAMPLE
    ### an example using the UDP transport

    ## same setup as above, 2 individual PS sessions

    # on the server
    $con = Start-ServerConnection -Transport UDP -PortNumber 1202 -Timeout 30 -Verbose

    # on the client
    $con = Start-ClientConnection -Transport UDP -ComputerName 192.168.0.52 -PortNumber 1202 -Verbose

    # from either endpoint
    SendTo-NetworkConnection -Connection $con -Data test123

    # from the other end
    ReceiveFrom-NetworkConnection -Connection $con

    # from both the server and the client
    Stop-NetworkConnection -Connection $con -Verbose

.EXAMPLE
    ### finally an example using the HTTP transport
    ### the only exception here, is that you need to run the PS Session on the server side elevated
    ### the reason being is that the HTTP Listener requires admin privileges to listen on any IP other than 127.0.0.1

    ## same setup as above, 2 individual PS sessions

    # on the server
    $con = Start-ServerConnection -Transport HTTP -PortNumber 1202 -Timeout 30 -Verbose

    # on the client
    $con = Start-ClientConnection -Transport HTTP -ComputerName 192.168.0.52 -PortNumber 1202 -Verbose

    # from either endpoint
    SendTo-NetworkConnection -Connection $con -Data test123

    # from the other end
    ReceiveFrom-NetworkConnection -Connection $con

    # from the server
    Stop-NetworkConnection -Connection $con -Verbose

    # with HTTP transport, there's no need to stop the connection from the client side
#>

[CmdletBinding(DefaultParameterSetName='PortName')]
Param(

    [Parameter(Position = 0)]
    [ValidateSet('Pipes','TCP','UDP','HTTP')]
    [string]$Transport = 'Pipes',
    [int]$Timeout = 5,    # <-- Timeout in seconds
    [switch]$AllowFirewall
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

    if ($AllowFirewall) {
        [void]$ParamTable.Add(@{Name='RemoteAddress';Type=[string[]]})
        $DefaultValue['RemoteAddress']  = 'Any'
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

    switch ($Transport) {
        {$_ -eq 'Pipes'} {
            $PipeName   = if ($PSBoundParameters.ContainsKey('PipeName')) {$PSBoundParameters['PipeName']}
                        else {$DefaultValue['PipeName']} }
        {$_ -eq 'TCP' -or $_ -eq 'UDP'} {
            $ServerPort = if ($PSBoundParameters.ContainsKey('PortName')) {[PortNumber]::($PSBoundParameters['PortName']).Value__}
                      elseif ($PSBoundParameters.ContainsKey('PortNumber')) {$PSBoundParameters['PortNumber']}
                        else {[PortNumber]::($DefaultValue['PortName']).Value__} }
        {$_ -eq 'HTTP'} {
            $ServerPort = if ($PSBoundParameters.ContainsKey('PortNumber')) {$PSBoundParameters['PortNumber']}
                        else {$DefaultValue['PortNumber']} }
    } #switch
} #begin

Process {

    if ($AllowFirewall) {
        $Chk = Get-NetFirewallRule -Name 'PSRemotingServer' -ErrorAction SilentlyContinue
        try {
            if ([bool]$Chk) { Remove-NetFirewallRule -Name 'PSRemotingServer' -ErrorAction Stop  }
        }
        catch {
            Throw "Couldn't remove existing windows firewall rule to create new one"
        }

        if ($Transport -eq 'Pipes') {
            $LocalPort   = @('135','139','445','1024-5000','49152-65535')
            $Description = "Allow PowerShell Remoting through Named Pipes"
        }
        else {
            $LocalPort   = $ServerPort
            $Description = 'Allow PowerShell Remoting through {0}:{1}' -f $Transport,$ServerPort
        }

        $RemoteAddress = if ($PSBoundParameters.ContainsKey('RemoteAddress')) {$PSBoundParameters['RemoteAddress']}
                       else {$DefaultValue['RemoteAddress']}
        $params = @{
            Name          = 'PSRemotingServer'
            DisplayName   = 'PowerShell Remoting Alternative (Server)'
            Direction     = 'Inbound'
            Description   = $Description
            Enable        = 'True'
            Profile       = 'Any'
            Action        = 'Allow'
            RemoteAddress = $RemoteAddress
            RemotePort    = 'Any'
            LocalAddress  = 'Any'
            LocalPort     = $LocalPort
            Protocol      = if ($Transport -eq 'HTTP' -or $Transport -eq 'Pipes') {'TCP'} else {$Transport}
            Program       = [System.Diagnostics.Process]::GetCurrentProcess().Path
            InterfaceType = 'Any'
        }
        try {
            $Rule = New-NetFirewallRule @params
            Write-Verbose "$(Prefix)Windows Firewall rule has been created"
        }
        catch {Throw "Couldn't create windows firewall rule to allow server connection"}
        $OutputObj.FirewallRule = $Rule
    } #if AllowFirewall

    if ($Transport -eq 'Pipes') {
        $Instances         = [int]1
        $Security          = New-Object System.IO.Pipes.PipeSecurity
        $AccRulIdentity    = 'Everyone'
        $AccRulRights      = 'FullControl'
        $AccRulControlType = 'Allow'
        $AccRulConstructor = @($AccRulIdentity,$AccRulRights,$AccRulControlType)
        $AccessRule        = New-Object System.IO.Pipes.PipeAccessRule($AccRulConstructor)
        $Security.AddAccessRule($AccessRule)
        $Direction         = [System.IO.Pipes.PipeDirection]::InOut
        $TransmissionMode  = [System.IO.Pipes.PipeTransmissionMode]::Message
        $Option            = [System.IO.Pipes.PipeOptions]::Asynchronous
        $InBuffer          = 65536
        $OutBuffer         = 65536
        $Inheritability    = [System.IO.HandleInheritability]::None

        $AssemblyFQDN = [System.IO.Pipes.NamedPipeServerStream].AssemblyQualifiedName
        $Regx = [regex]::Match($AssemblyFQDN,'Version=((\d+\.)+\d+),\s')
        $Ver  = $Regx.Groups[1].Value -as [version]
        if ($Ver.Major -eq 4) {
            $PipeConstructor = $PipeName,$Direction,$Instances,$TransmissionMode,$Option,$InBuffer,$OutBuffer,$Security,$Inheritability
        }
        elseif ($Ver.Major -eq 7) {
            $PipeConstructor = $PipeName,$Direction,$Instances,$TransmissionMode,$Option,$InBuffer,$OutBuffer
        }

        try   { $Stream    = New-Object System.IO.Pipes.NamedPipeServerStream($PipeConstructor)}
        catch { Throw $_ }
        try   { $Connect   = $Stream.BeginWaitForConnection($null, $null)}
        catch { Throw $_ }
        Write-Verbose "$(Prefix)Named Pipes Server has started"

        $Stopwatch         = [Diagnostics.Stopwatch]::StartNew()
        while (-not $Connect.IsCompleted) {
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                $Stream.Dispose()
                $Stopwatch.Stop()
                if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'}
                Throw 'Timeout exceeded'
            }
        }
        $Stopwatch.Stop()
        try   {
            $Stream.EndWaitForConnection($Connect)
            Write-Verbose "$(Prefix)Client connected"
        }
        catch {
            $Stream.Dispose()
            if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'}
            Throw $_
        }

        $EventDetails = Get-ServerInfo $Transport $PipeName
        New-Event -SourceIdentifier 'Server.Started' -Sender "$Transport.Server" -EventArguments $EventDetails | Out-Null        

        try   { $OutputObj.StreamReader  = [System.IO.StreamReader]::new($Stream)
                $OutputObj.StreamWriter  = [System.IO.StreamWriter]::new($Stream)
                $OutputObj.StreamWriter.AutoFlush = $true }
        catch { Throw "Couldn't start the stream reader/writer" }
        $OutputObj.Mode         = [ConnectionMode]::PipesServer
        $OutputObj.PipeServer   = $Stream

    } #if Pipes

    if ($Transport -eq 'TCP') {
        $IPProps         = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
        $IPFilter        = {$_.PrefixLength -le 32 -and $_.Address.IPAddressToString -notmatch '127.0.0.1|169.254.'}
        $ServerIP        = $IPProps.GetUnicastAddresses().where($IPFilter).Address.ToString()    # Alt: (Get-NetIPAddress -AddressFamily IPv4).where({$_.ipaddress -ne '127.0.0.1'}).ipaddress
        if (([array]$ServerIP).Count -gt 1) {
            Write-Warning 'Found more than 1 IP address, please define which one you want to use for the TCP Server'
            return $ServerIP
        }
        $TcpServer       = [System.Net.Sockets.TcpListener]::new($ServerIP,$ServerPort)
        $MaxConnections  = 1
        try   { $TcpServer.Start($MaxConnections) }
        catch { Throw $_ }
        Write-Verbose "TCP Server has started and listening on $($ServerIP):$ServerPort"

        try   { $Connect = $TcpServer.BeginAcceptTcpClient($null,$null) }
        catch { if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'} ; Throw $_}

        $Stopwatch       = [Diagnostics.Stopwatch]::StartNew()
        while (-not $Connect.IsCompleted) {
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                $TcpServer.Stop()
                $Stopwatch.Stop()
                if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'}
                Throw 'Timeout exceeded'
            }
        }
        $Stopwatch.Stop()
        try   {
            $TcpConnection = $TcpServer.EndAcceptTcpClient($Connect)
            $TcpConnection.Client.ReceiveTimeout = $Timeout * 1000
            $TcpServer.Stop()  # <-- at this stage the client has connected so we can stop the server from listening for anyone else
            Write-Verbose "$(Prefix)Client connected"
        }
        catch {
            $TcpServer.Stop()
            if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'}
            Throw $_
        }

        $Stream            = $TcpConnection.GetStream()
        $EventDetails = Get-ServerInfo $Transport $ServerPort
        New-Event -SourceIdentifier 'Server.Started' -Sender "$Transport.Server" -EventArguments $EventDetails | Out-Null
        
        try   { $OutputObj.StreamReader  = [System.IO.StreamReader]::new($Stream)
                $OutputObj.StreamWriter  = [System.IO.StreamWriter]::new($Stream)
                $OutputObj.StreamWriter.AutoFlush = $true }
        catch { Throw "Couldn't start the stream reader/writer" }
        $OutputObj.Mode         = [ConnectionMode]::TcpServer
        $OutputObj.TcpClient    = $TcpConnection
        $OutputObj.TcpStream    = $Stream

    } #if TCP

    if ($Transport -eq 'UDP') {
        $ThisIPAddr      = [System.Net.DNS]::GetHostAddresses($null).where({$_.AddressFamily -eq 'InterNetwork'})
        $ServerIP        = $ThisIPAddr.Address # <-- I'm using the [Int64] here and not the [IPAddress]
        $ReceiveEndpoint = [System.Net.IPEndPoint]::new($ServerIP,$ServerPort)                                            #     cause the constructor has an issue with the IP, but works with the long
        $UdpServer       = [System.Net.Sockets.UdpClient]::new($ReceiveEndpoint)
        $UdpServer.Client.ReceiveTimeout = $Timeout*1000
        Write-Verbose "UDP Server started and listening on $($ThisIPAddr.IPAddressToString):$ServerPort"
    
        try   { $Connect = $UdpServer.BeginReceive($null,$null)}
        catch { if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'} ; Throw $_}

        $Stopwatch       = [Diagnostics.Stopwatch]::StartNew()
        while (-not $Connect.IsCompleted) {
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                $UdpServer.Dispose()
                $Stopwatch.Stop()
                if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'}
                Throw 'Timeout exceeded'
            }
        }
        $Stopwatch.Stop()
        try   {
            $Data = $UdpServer.EndReceive($Connect,[ref]$ReceiveEndpoint)
            Write-Verbose "$(Prefix)Client connected"
        }
        catch {
            $UdpServer.Dispose()
            if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'}
            Throw $_
        }

        $ClientIP     = [Text.Encoding]::ASCII.GetString($Data).Split(',')[0]
        $ClientPort   = [Text.Encoding]::ASCII.GetString($Data).Split(',')[1]
        $SendEndPoint = [System.Net.IPEndPoint]::new([System.Net.IPAddress]$ClientIP,$ClientPort)
        $UdpServer.Connect($SendEndpoint)
        [void]$UdpServer.Send([Text.Encoding]::ASCII.GetBytes('OK'),2)

        $EventDetails = Get-ServerInfo $Transport $ServerPort
        New-Event -SourceIdentifier 'Server.Started' -Sender "$Transport.Server" -EventArguments $EventDetails | Out-Null

        $OutputObj.Mode               = [ConnectionMode]::UdpServer
        $OutputObj.UDP                = $UdpServer
        $OutputObj.UdpSendEndpoint    = $UdpServer.Client.RemoteEndPoint
        $OutputObj.UdpReceiveEndpoint = $UdpServer.Client.LocalEndPoint

    } #if UDP

    if ($Transport -eq 'HTTP') {
        $HttpServer = [System.Net.HttpListener]::new()
        $URL        = "http://+:$ServerPort"
        $HttpServer.Prefixes.Add("$URL/")
        $HttpServer.Prefixes.Add("$URL/Exit/")
        $HttpServer.Prefixes.Add("$URL/Results/")
        $HttpServer.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Anonymous

        try   { $HttpServer.Start() }  # this requires local admin rights
        catch { if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'} ; Throw $_ }
        Write-Verbose "HTTP Server started and listening on port $ServerPort"

        try   { $Connect = $HttpServer.BeginGetContext($null,$null) }
        catch { if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'} ; Throw $_}

        $Stopwatch       = [Diagnostics.Stopwatch]::StartNew()
        while (-not $Connect.IsCompleted) {
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                $HttpServer.Close()
                $Stopwatch.Stop()
                if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'}
                Throw 'Timeout exceeded'
            }
        }
        $Stopwatch.Stop()
        try   {
            $Context = $HttpServer.EndGetContext($Connect)
            Write-Verbose "$(Prefix)Client connected"
            $Context.Response.Close()
        }
        catch {
            $HttpServer.Close()
            if ($AllowFirewall) {Remove-NetFirewallRule -Name 'PSRemotingServer'}
            Throw $_
        }

        $EventDetails = Get-ServerInfo $Transport $ServerPort
        New-Event -SourceIdentifier 'Server.Started' -Sender "$Transport.Server" -EventArguments $EventDetails | Out-Null

        $OutputObj.Mode        = [ConnectionMode]::HttpServer
        $OutputObj.HttpServer  = $HttpServer

    } #if HTTP

} #process

End {

    $OutputObj.ServerInfo   = $EventDetails
    Write-Output $OutputObj

}

}