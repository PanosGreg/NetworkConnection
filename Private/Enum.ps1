enum ConnectionMode {
    Undefined    = 0
    TcpClient    = 11
    TcpServer    = 12
    UdpClient    = 21
    UdpServer    = 22
    PipesClient  = 31
    PipesServer  = 32
    HttpClient   = 41
    HttpServer   = 42
}

$rand = [random]::new().next(59000,59999)
$EnumPorts = @'
enum PortNumber {
    RDP    = 3389   # TCP
    SCCM   = 10123  # TCP
    Sophos = 8194   # TCP
    Lync   = 5061   # TCP
    AD     = 443    # TCP
    LDAP   = 389    # TCP
    SCOM   = 5723   # TCP
    DNS    = 53     # UDP
    DHCP   = 67     # UDP
    NTP    = 123    # UDP
    Random = <Rand> # Both
}
'@
Invoke-Expression $EnumPorts.Replace('<Rand>',$rand)