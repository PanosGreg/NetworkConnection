## UDP Communication

# Implementation with 1 socket
# Same socket for send and receive


## On SERVER

# Start the UDP Server Receive Endpoint
$ServerPort      = 15000
$ServerIP        = [System.Net.DNS]::GetHostAddresses($null).where({$_.AddressFamily -eq 'InterNetwork'}).Address
$ReceiveEndpoint = [System.Net.IPEndPoint]::new($ServerIP,$ServerPort)
$UdpServer       = [System.Net.Sockets.UdpClient]::new($ReceiveEndpoint)
$UdpServer.Client.ReceiveTimeout = 5000

# Receive the Client IP and the Port to Send-To from Client
$Data        = $UdpServer.Receive([ref]$ReceiveEndpoint)
$ClientIP    = [Text.Encoding]::ASCII.GetString($Data).Split(',')[0]
$ClientPort  = [Text.Encoding]::ASCII.GetString($Data).Split(',')[1]

# Connect to the UDP Client
$SendEndPoint    = [System.Net.IPEndPoint]::new([System.Net.IPAddress]$ClientIP,$ClientPort)
$UdpServer.Connect($SendEndpoint)

# Send Message to Client
$Message    = 'this is a message'
$ByteArray  = [Text.Encoding]::ASCII.GetBytes($Message)
[void]$UdpServer.Send($ByteArray,$ByteArray.Length)

# Clean up
$UdpServer.Client.Dispose()
$UdpServer.Dispose()



## On CLIENT

# Start the UDP Client and set the Send-Endpoint
$ServerName   = 'dr-its-fsmgmt'
$ServerPort   = 15000
$UdpClient    = [System.Net.Sockets.UdpClient]::new()
$ServerIP     = [System.Net.DNS]::GetHostEntry($ServerName).AddressList[0]
$SendEndPoint = [System.Net.IPEndPoint]::new($ServerIP,$ServerPort)
$UdpClient.Connect($SendEndpoint)

# Send the Receive Endpoint (comprises of the IP and Port) to the Server
$ClientPort   = $UdpClient.Client.LocalEndPoint.Port
$ClientIP     = $UdpClient.Client.LocalEndPoint.Address.ToString()
$ByteArray    = [Text.Encoding]::ASCII.GetBytes("$ClientIP,$ClientPort")
[void]$UdpClient.Send($ByteArray,$ByteArray.Length)

# Set the Receive-Endpoint
$ReceiveEndPoint  = [System.Net.IPEndPoint]::new([System.Net.IPAddress]$ClientIP,$ClientPort)
$UdpClient.Client.ReceiveTimeout = 5000

# Receive Message from Server
$Message         = [Text.Encoding]::ASCII.GetString($UdpClient.Receive([ref]$ReceiveEndPoint))

# Clean up
$UdpClient.Client.Dispose()
$UdpClient.Dispose()