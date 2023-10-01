function Stop-NetworkConnection {

<#



#>

[CmdletBinding()]
Param(

    [Parameter(Position=0,Mandatory,ValueFromPipeline)]
    [ValidateNotNull()]
    [PSTypeName('PSRemoting.Network.Connection')]$Connection
)

Begin {

    if ($Connection.Mode -like '*Server') {
        $EventCreator = "$($Connection.ServerInfo.ServerType).Server"
    }
}

Process {

    function Stop-Streams {
        try   {$Connection.StreamReader.Dispose()}
        catch {$Connection.StreamReader.Close()}
        try   {$Connection.StreamWriter.Dispose()}
        catch {$Connection.StreamWriter.Close()}
        Write-Verbose "$(Prefix)Stream Reader and Writer have been disposed"
    }
    function Stop-PipeServer {
        try   {$Connection.PipeServer.Dispose()}
        catch {Write-Verbose $($_.Exception.Message)}
        New-Event -SourceIdentifier 'Server.Stopped' -Sender $EventCreator -EventArguments $Connection.ServerInfo | Out-Null
        Write-Verbose "$(Prefix)Named Pipes Server has stopped"
    }
    function Stop-PipeClient {
        try   {$Connection.PipeClient.Dispose()}
        catch {Write-Verbose $($_.Exception.Message)}
        Write-Verbose "$(Prefix)Named Pipes Client has stopped"
    }

    function Stop-TcpConnection {   # <-- this works for both TCP client or server
        try   {$Connection.TcpStream.Dispose()}
        catch {Write-Verbose $($_.Exception.Message)}
        try   {$Connection.TcpClient.Client.Dispose() ; $Connection.TcpClient.Dispose()}
        catch {Write-Verbose $($_.Exception.Message)}
        if ($Connection.Mode -eq 'TcpServer') {
            New-Event -SourceIdentifier 'Server.Stopped' -Sender $EventCreator -EventArguments $Connection.ServerInfo | Out-Null
            Write-Verbose "$(Prefix)TCP Server has stopped"
        }
        elseif ($Connection.Mode -eq 'TcpClient') {Write-Verbose "$(Prefix)TCP Client has stopped"}
    }

    function Stop-UdpConnection {
        try   {$Connection.UDP.Client.Dispose() ; $Connection.UDP.Dispose() }
        catch {Write-Verbose $($_.Exception.Message)}
        if ($Connection.Mode -eq 'UdpServer') {
            New-Event -SourceIdentifier 'Server.Stopped' -Sender $EventCreator -EventArguments $Connection.ServerInfo | Out-Null
            Write-Verbose "$(Prefix)UDP Server has stopped"
        }
        elseif ($Connection.Mode -eq 'UdpClient') {Write-Verbose "$(Prefix)UDP Client has stopped"}        
    }

    function Stop-HttpServer {
        try   {$Connection.HttpServer.Stop()}
        catch {Write-Verbose $($_.Exception.Message)}
        try   {$Connection.HttpServer.Close()}
        catch {Write-Verbose $($_.Exception.Message)}
        New-Event -SourceIdentifier 'Server.Stopped' -Sender $EventCreator -EventArguments $Connection.ServerInfo | Out-Null
        Write-Verbose "$(Prefix)HTTP Server has stopped"
    }

    function Remove-FirewallRule {
        if ([bool]$Connection.FirewallRule) {
            try   {$Connection.FirewallRule | Remove-NetFirewallRule -ErrorAction Stop
                   Write-Verbose "$(Prefix)Windows Firewall rule has been deleted"}
            catch {Write-Verbose $($_.Exception.Message)}
        }
        else {return}
    }

    switch ($Connection.Mode) {
        'PipesServer' {Stop-PipeServer;Stop-Streams;Remove-FirewallRule}
        'PipesClient' {Stop-PipeClient;Stop-Streams}
        'TcpServer'   {Stop-TcpConnection;Stop-Streams;Remove-FirewallRule}
        'TcpClient'   {Stop-TcpConnection;Stop-Streams}
        'UdpServer'   {Stop-UdpConnection;Remove-FirewallRule}
        'UdpClient'   {Stop-UdpConnection}
        'HttpServer'  {Stop-HttpServer;Remove-FirewallRule}
        'HttpClient'  {Write-Verbose 'Nothing to stop in HTTP Client mode'}
        default       {}
    }
}

End {}

}