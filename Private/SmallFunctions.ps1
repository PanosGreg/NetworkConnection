function Prefix {
    "[$([datetime]::Now.ToString('dd/MM/yy HH:mm:ss'))]::"
}

function Get-ServerInfo ($Transport,$Port) {
    $Output = @{
        ServerDate     = [System.DateTime]::Now
        ServerUser     = $env:USERNAME
        ServerType     = $Transport
        ServerName     = $env:COMPUTERNAME
        ServerPort     = $Port
        ServerFullName = switch ($Transport) {
                                'Pipes' {"\\$Env:COMPUTERNAME\pipe\$Port"}
                                'TCP'   {'TCP\{0}:{1}' -f [Net.Dns]::GetHostAddresses("").where({$_.AddressFamily -eq 'InterNetwork'}).IPAddressToString,$Port}
                                'UDP'   {'UDP\{0}:{1}' -f [Net.Dns]::GetHostAddresses("").where({$_.AddressFamily -eq 'InterNetwork'}).IPAddressToString,$Port}
                                'HTTP'  {'HTTP://{0}:{1}' -f $Env:COMPUTERNAME,$Port}
                                default {} }
    }
    Write-Output $Output
}