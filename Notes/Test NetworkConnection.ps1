
## Test the NetworkConnection module

# Process: first run the server part on the server,
#          and then the client part on the client


#region Load module
    # On the Server
    Remove-Module NetworkConnection -ErrorAction SilentlyContinue
    Import-Module D:\Code\NetworkConnection\Module\NetworkConnection.psd1 -DisableNameChecking

    # On the Client
    Remove-Module NetworkConnection -ErrorAction SilentlyContinue
    Import-Module D:\temp9\NetworkConnection\NetworkConnection.psd1 -DisableNameChecking
#rendregion


#region Test Pipes
    #on the Server
    $conP = Start-ServerConnection -Transport Pipes -PipeName MyPipe
    SendTo-NetworkConnection -Connection $conP -Data 'This is from the SERVER'
    ReceiveFrom-NetworkConnection -Connection $conP
    $conP | Stop-NetworkConnection

    #on the Client
    $conP = Start-ClientConnection -ComputerName dr-its-fsmgmt -Transport Pipes -PipeName MyPipe
    ReceiveFrom-NetworkConnection -Connection $conP
    SendTo-NetworkConnection -Connection $conP -Data 'This is from the CLIENT'
    $conP | Stop-NetworkConnection
#endregion


#region Test TCP
    #on the Server
    $conT = Start-ServerConnection -Transport TCP -TcpPort Sophos
    SendTo-NetworkConnection -Connection $conT -Data 'This is from the SERVER'
    ReceiveFrom-NetworkConnection -Connection $conT
    $conT | Stop-NetworkConnection

    #on the Client
    $conT = Start-ClientConnection -ComputerName dr-its-fsmgmt -Transport TCP -TcpPort Sophos
    ReceiveFrom-NetworkConnection -Connection $conT
    SendTo-NetworkConnection -Connection $conT -Data 'This is from the CLIENT'
    $conT | Stop-NetworkConnection
#endregion


#region Test UDP
    #on the Server
    $conU = Start-ServerConnection -Transport UDP -UdpPort DNS
    SendTo-NetworkConnection -Connection $conU -Data 'This is from the SERVER'
    ReceiveFrom-NetworkConnection -Connection $conU
    $conU | Stop-NetworkConnection

    #on the Client
    $conU = Start-ClientConnection -ComputerName dr-its-fsmgmt -Transport UDP -UdpPort DNS
    ReceiveFrom-NetworkConnection -Connection $conU
    SendTo-NetworkConnection -Connection $conU -Data 'This is from the CLIENT'
    $conU | Stop-NetworkConnection
#endregion


#region Test HTTP
    #on the Server
    $conH = Start-ServerConnection -Transport HTTP -HttpPort 15000
    SendTo-NetworkConnection -Connection $conH -Data 'This is from the SERVER'
    ReceiveFrom-NetworkConnection -Connection $conH
    $conH | Stop-NetworkConnection

    #on the Client
    $conH = Start-ClientConnection -ComputerName dr-its-fsmgmt -Transport Pipes -PipeName MyPipe
    ReceiveFrom-NetworkConnection -Connection $conH
    SendTo-NetworkConnection -Connection $conH -Data 'This is from the CLIENT'
    $conH | Stop-NetworkConnection
#endregion