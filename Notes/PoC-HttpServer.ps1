

## WebServer and Web Client


## On the Server

$HttpServer = [System.Net.HttpListener]::new()
$port = 8000
$HttpServer.Prefixes.Add("http://+:$port/")
$HttpServer.Prefixes.Add("http://+:$port/Exit/")
$HttpServer.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Anonymous

$Timeout = 5
try   { $HttpServer.Start() }
catch { Throw $_ }

$ServerLoop = $true
while ($ServerLoop) {
    if (-not $HttpServer.IsListening) {$ServerLoop = $false}
    $Context   = $HttpServer.GetContext()
    $Request   = $Context.Request
    $Response  = $Context.Response
    $Response.Headers.Set([System.Net.HttpResponseHeader]::Server,"$env:COMPUTERNAME.PSRemoting")

    if ($Request.HttpMethod -eq 'GET') {
        switch ($Request.Url.LocalPath) {
            '/'         {
                $Data             = "This is a Web Server that's configured for PowerShell Remoting"
                $OutStream        = $Response.OutputStream
                $Writer           = [System.IO.StreamWriter]::new($OutStream)
                $Writer.AutoFlush = $true
                $Writer.WriteLine($Data)
                $Writer.Close()
                $OutStream.Close()
                $Response.Close() }
            '/Exit/'    {
                $Data             = "Stopping the Server..."
                $OutStream        = $Response.OutputStream
                $Writer           = [System.IO.StreamWriter]::new($OutStream)
                $Writer.AutoFlush = $true
                $Writer.WriteLine($Data)
                Start-Sleep -Milliseconds 400
                $Writer.Close()
                $OutStream.Close()
                $Response.Close()
                $HttpServer.Stop()
                $HttpServer.Close()
                Write-Output $Data
                $ServerLoop = $false
                Break }
            default     {
                $Data             = "Invalid URL"
                $OutStream        = $Response.OutputStream
                $Writer           = [System.IO.StreamWriter]::new($OutStream)
                $Writer.AutoFlush = $true
                $Writer.WriteLine($Data)
                $Writer.Close()
                $OutStream.Close()
                $Response.Close() }
            } #switch

    } #if GET
    if ($Request.HttpMethod -eq 'POST') {
        $InStream         = $Request.InputStream
        $Reader           = [System.IO.StreamReader]::new($InStream)
        $Post             = $Reader.ReadToEnd()
        $Data             = "This is what you sent: $Post"
        $OutStream        = $Response.OutputStream
        $Writer           = [System.IO.StreamWriter]::new($OutStream)
        $Writer.AutoFlush = $true
        $Writer.WriteLine($Data)
        $Writer.Close()
        $Reader.Close()
        $InStream.Close()
        $OutStream.Close()
        $Response.Close()
    } #if POST
} #while ServerLoop


## On the Client

# POST Method
    $Timeout          = 5
    $request          = [System.Net.HttpWebRequest]::Create('http://dr-its-fsmgmt:8000/')
    $request.Method   = 'POST'
    $request.Timeout  = $Timeout*1000
    $OutStream        = $request.GetRequestStream()
    $writer           = [System.IO.StreamWriter]::new($OutStream)
    $writer.AutoFlush = $true
    $data             = 'this is a post'
    $writer.Write($Data)
    $writer.Close()
    $Outstream.Close()
    $response         = $request.GetResponse()
    $InStream         = $response.GetResponseStream()
    $reader           = [System.IO.StreamReader]::new($InStream)
    $reader.ReadToEnd()
    $reader.Close()
    $InStream.Close()
    $response.Close()


# GET Method
    $Timeout          = 5
    $request          = [System.Net.HttpWebRequest]::Create('http://dr-its-fsmgmt:8000/Exit/')
    $request.Method   = 'GET'
    $request.Timeout  = $Timeout*1000
    $response         = $request.GetResponse()
    $InStream         = $response.GetResponseStream()
    $reader           = [System.IO.StreamReader]::new($InStream)
    $reader.ReadToEnd()
    $reader.Close()
    $InStream.Close()
    $response.Close()