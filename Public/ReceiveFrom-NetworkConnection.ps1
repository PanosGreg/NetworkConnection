function ReceiveFrom-NetworkConnection {

<#

#>

[CmdletBinding()]
Param(

    [Parameter(Position=0,Mandatory,ValueFromPipeline)]
    [ValidateNotNull()]
    [PSTypeName('PSRemoting.Network.Connection')]$Connection
)

Begin {

    if ($Connection.Mode -eq 'HttpServer') {
        function ReceiveFrom-HttpClient ($Connection) {
            if (-not $Connection.HttpServer.IsListening) {Throw 'HTTP Server is not running'}
            $Context   = $Connection.HttpServer.GetContext()
            $Request   = $Context.Request
            $Response  = $Context.Response
            $Response.Headers.Set([System.Net.HttpResponseHeader]::Server,"$env:COMPUTERNAME.PSRemoting")

            if ($Request.HttpMethod -eq 'POST') {
                $InStream         = $Request.InputStream
                $Reader           = [System.IO.StreamReader]::new($InStream)
                Write-Output $($Reader.ReadToEnd())
                $Reader.Close()
                $InStream.Close()
                $Response.Close()
            } #if POST
        } #function
    } #if HttpServer

    if ($Connection.Mode -eq 'HttpClient') {
        function ReceiveFrom-HttpServer ($Connection) {
            $URL              = '{0}Results/' -f $Connection.HttpClient.RequestUri.OriginalString
            $request          = [System.Net.HttpWebRequest]::Create($URL)
            $request.Method   = 'GET'
            $request.Timeout  = $Connection.HttpClient.Timeout * 1000
            $response         = $request.GetResponse()
            $InStream         = $response.GetResponseStream()
            $reader           = [System.IO.StreamReader]::new($InStream)
            Write-Output $($reader.ReadToEnd())
            $reader.Close()
            $InStream.Close()
            $response.Close()
        }
    } #if HttpClient

} #begin

Process {

    $OutputObj = switch ($Connection.Mode) {
        'PipesServer' {$Connection.StreamReader.Readline()}
        'PipesClient' {$Connection.StreamReader.Readline()}
        'TcpServer'   {$Connection.StreamReader.Readline()}
        'TcpClient'   {$Connection.StreamReader.Readline()}
        'UdpServer'   {[Text.Encoding]::ASCII.GetString($Connection.UDP.Receive([ref]$Connection.ReceiveEndpoint))}
        'UdpClient'   {[Text.Encoding]::ASCII.GetString($Connection.UDP.Receive([ref]$Connection.ReceiveEndpoint))}
        'HttpServer'  {ReceiveFrom-HttpClient $Connection}
        'HttpClient'  {ReceiveFrom-HttpServer $Connection}
        default       {}
    }
    Write-Output $OutputObj

} #process

End {}

}