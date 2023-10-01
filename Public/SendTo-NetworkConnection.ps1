function SendTo-NetworkConnection {

<#

#>

[CmdletBinding()]
Param(

    [Parameter(Position=0,Mandatory,ValueFromPipeline)]
    [ValidateNotNull()]
    [PSTypeName('PSRemoting.Network.Connection')]$Connection,

    [Parameter(Position=1,Mandatory)]
    $Data
)

Begin {

    if ($Connection.Mode -like 'Udp*') {
        $ByteArray  = [Text.Encoding]::ASCII.GetBytes($Data)
        $ByteLength = $ByteArray.Length
    }

    if ($Connection.Mode -eq 'HttpServer') {
        function SendTo-HttpClient ($Connection,$Data) {
            if (-not $Connection.HttpServer.IsListening) {Throw 'HTTP Server is not running'}
            $Context   = $Connection.HttpServer.GetContext()
            $Request   = $Context.Request
            $Response  = $Context.Response
            $Response.Headers.Set([System.Net.HttpResponseHeader]::Server,"$env:COMPUTERNAME.PSRemoting")

            if ($Request.HttpMethod -eq 'GET') {
                if ($Request.Url.LocalPath -eq '/Results/') {
                    $OutStream        = $Response.OutputStream
                    $Writer           = [System.IO.StreamWriter]::new($OutStream)
                    $Writer.AutoFlush = $true
                    $Writer.Write($Data)
                    $Writer.Close()
                    $OutStream.Close()
                    $Response.Close()
                } #if /Results/
            } #if GET
        } #function
    } #if HttpServer

    if ($Connection.Mode -eq 'HttpClient') {
        function SendTo-HttpServer ($Connection,$Data) {
            $URL              = $Connection.HttpClient.RequestUri.OriginalString
            $request          = [System.Net.HttpWebRequest]::Create($URL)
            $request.Method   = 'POST'
            $request.Timeout  = $Connection.HttpClient.Timeout * 1000
            $OutStream        = $request.GetRequestStream()
            $writer           = [System.IO.StreamWriter]::new($OutStream)
            $writer.AutoFlush = $true
            $writer.Write($Data)
            $response         = $request.GetResponse()
            $writer.Close()
            $Outstream.Close()
            $response.Close()
        } #function
    } #if HttpClient

}

Process {

    switch ($Connection.Mode) {
        'PipesServer' {$Connection.StreamWriter.WriteLine($Data)}
        'PipesClient' {$Connection.StreamWriter.WriteLine($Data)}
        'TcpServer'   {$Connection.StreamWriter.WriteLine($Data)}
        'TcpClient'   {$Connection.StreamWriter.WriteLine($Data)}
        'UdpServer'   {[void]$Connection.UDP.Send($ByteArray,$ByteLength)}
        'UdpClient'   {[void]$Connection.UDP.Send($ByteArray,$ByteLength)}
        'HttpServer'  {SendTo-HttpClient $Connection $Data}
        'HttpClient'  {SendTo-HttpServer $Connection $Data}
        default       {}
    }

} #process

End {}

} #function