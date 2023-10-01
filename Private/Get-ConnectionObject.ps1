function Get-ConnectionObject {

<#
.DESCRIPTION
    The object produced by this function will be used by other functions.
    The properties that this custom object has are based on the facts that we need to be able to do
    the following things:
    - Close the connection once we're done
    - Send data to the connection
    - Receive data from the connection

#>    
    $OutputObj = [pscustomobject] @{  # <-- the datatypes are here more for documentation purposes to show what the output should consist of
        PSTypeName         = 'PSRemoting.Network.Connection'
        Mode               = [ConnectionMode]::Undefined
        TcpStream          = [System.Net.Sockets.NetworkStream]$null
        TcpClient          = [System.Net.Sockets.TcpClient]$null
        UDP                = [System.Net.Sockets.UdpClient]$null
        UdpSendEndpoint    = [System.Net.IPEndPoint]$null
        UdpReceiveEndpoint = [System.Net.IPEndPoint]$null
        PipeServer         = [System.IO.Pipes.NamedPipeServerStream]$null
        PipeClient         = [System.IO.Pipes.NamedPipeClientStream]$null
        HttpServer         = [System.Net.HttpListener]$null
        HttpClient         = [System.Net.HttpWebRequest]$null
        StreamReader       = [System.IO.StreamReader]$null
        StreamWriter       = [System.IO.StreamWriter]$null
        ServerInfo         = [System.Collections.Hashtable]$null
        FirewallRule       = [WMICLASS]'root\standardcimv2:MSFT_NetFirewallRule'>$null
    }

    Write-Output $OutputObj

}

#         Socket            = [System.Net.Sockets.Socket]$null