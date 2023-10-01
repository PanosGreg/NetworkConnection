#Requires -RunAsAdministrator
$HttpServer = [System.Net.HttpListener]::new()
$port = 8000
$HttpServer.Prefixes.Add("http://+:$port/")
$HttpServer.Prefixes.Add("http://+:$port/Exit/")
$HttpServer.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Anonymous

$Timeout = 5
try   { $HttpServer.Start() }
catch { Throw $_ }


# Check Server connectivity - Async

try   { $Connect = $HttpServer.BeginGetContext($null,$null) }
catch { Throw $_}
$Stopwatch       = [Diagnostics.Stopwatch]::StartNew()
while (-not $Connect.IsCompleted) {
    if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
        $HttpServer.Close()
        $Stopwatch.Stop()
        Throw 'Timeout exceeded'
    }
}
$Stopwatch.Stop()
try   {
    $Context = $HttpServer.EndGetContext($Connect)
    Write-Verbose "Client connected"
    $Buffer  = [Text.Encoding]::UTF8.GetBytes('Connected')
    $Context.Response.ContentLength64 = $Buffer.Length
    $Context.Response.OutputStream.Write($Buffer,0,$Buffer.Length)
    $Context.Response.Close()
}
catch {
    $HttpServer.Close()
    Throw $_
}


# On the client
# Check Client Connectivity - Async
    $Timeout            = 5
    $HttpClient         = [System.Net.HttpWebRequest]::Create('http://dr-its-fsmgmt:8000/Exit/')
    $HttpClient.Method  = 'GET'
    $HttpClient.Timeout = $Timeout*1000

    try   { $Connect = $HttpClient.BeginGetResponse($null,$null) }
    catch { Throw $_}
    $Stopwatch       = [Diagnostics.Stopwatch]::StartNew()
    while (-not $Connect.IsCompleted) {
        if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
            $HttpClient.Abort()
            $Stopwatch.Stop()
            Throw 'Timeout exceeded'
        }
    }
    $Stopwatch.Stop()
    try   {
        $Response = $HttpClient.EndGetResponse($Connect)
        Write-Verbose "Client connected"
        $Response.Close()
    }
    catch {
        $HttpClient.Abort()
        Throw $_
    }



#######################


#### On the Client

# GET example
    # via Invoke-WebRequest
    $OrigProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    $Connect = Invoke-WebRequest -Uri "http://dr-its-fsmgmt:8000/" -Method Get -TimeoutSec 5
    [Text.Encoding]::UTF8.GetString($Connect.Content)
    $ProgressPreference = $OrigProgressPreference
    # via HttpWebRequest & StreamReader
    $Timeout  = 5
    $request  = [System.Net.HttpWebRequest]::Create('http://dr-its-fsmgmt:8000/')
    $request.Timeout = $Timeout*1000
    $response = $request.GetResponse()
    $stream   = $response.GetResponseStream()
    $reader   = [System.IO.StreamReader]::new($stream)
    $reader.ReadToEnd()
    $reader.Close()
    $stream.Close()

# POST example
    # via Invoke-Webrequest (PS function)
    $OrigProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    $Connect = Invoke-WebRequest -Uri "http://dr-its-fsmgmt:8000/" -Method Post -TimeoutSec 5 -Body 'This is the Data'
    [Text.Encoding]::UTF8.GetString($Connect.Content)
    $ProgressPreference = $OrigProgressPreference
    # via HttpWebRequest (.NET class) & default Stream
    $request = [System.Net.HttpWebRequest]::Create('http://dr-its-fsmgmt:8000/')
    $request.Method = 'POST'
    $data   = 'this is my post'
    $buffer = [Text.Encoding]::UTF8.GetBytes($Data)
    $request.ContentLength = $Buffer.Length
    $stream = $request.GetRequestStream()
    $stream.Write($buffer,0,$buffer.Length)
    $reader = [System.IO.StreamReader]::new($request.GetResponse().GetResponseStream())
    $reader.ReadToEnd()
    $reader.Close()
    $stream.close()
    # via HttpWebRequest (.NET class) & streamWriter
    $request = [System.Net.HttpWebRequest]::Create('http://dr-its-fsmgmt:8000/')
    $request.Method = 'POST'
    $writer = [System.IO.StreamWriter]::new($request.GetRequestStream())
    $writer.AutoFlush = $true
    $data   = 'this is a 3rd post'
    $writer.Write($Data)
    $writer.Close()
    $reader = [System.IO.StreamReader]::new($request.GetResponse().GetResponseStream())
    $reader.ReadToEnd()
    $reader.Close()

# Exit example
    # via Invoke-Webrequest (PS function)
    $Connect = Invoke-WebRequest -Uri "http://dr-its-fsmgmt:8000/Exit/" -Method Get -TimeoutSec 5
    [Text.Encoding]::UTF8.GetString($Connect.Content)
    # via HttpWebRequest & StreamReader
    $Timeout  = 5
    $request  = [System.Net.HttpWebRequest]::Create('http://dr-its-fsmgmt:8000/Exit/')
    $request.Timeout = $Timeout*1000
    $response = $request.GetResponse()
    $stream   = $response.GetResponseStream()
    $reader   = [System.IO.StreamReader]::new($stream)
    $reader.ReadToEnd()
    $reader.Close()
    $stream.Close()

##############

# on the server

while ($HttpServer.IsListening) {

    $Context   = $HttpServer.GetContext()
    $Request   = $Context.Request
    $Response  = $Context.Response
    $Response.Headers.Set([System.Net.HttpResponseHeader]::Server,"$env:COMPUTERNAME.PSRemoting")

    if ($Request.HttpMethod -eq 'GET') {
        if ($Request.Url.LocalPath -eq '/Exit/') {
            $Data     = "Stopping the Server..."
            Write-Output $Data
            $Buffer   = [Text.Encoding]::UTF8.GetBytes($Data)
            $Response.ContentLength64 = $Buffer.Length
            $OutStream = $Response.OutputStream
            $OutStream.Write($Buffer,0,$Buffer.Length)
            Start-Sleep -Milliseconds 400
            $Response.Close()
            $HttpServer.Stop()
            $HttpServer.Close()
            Break
        }
        if ($Request.Url.LocalPath -eq '/Execute/') {
            $Data     = "Here's a response!"
            $Buffer   = [Text.Encoding]::UTF8.GetBytes($Data)
            $Response.ContentLength64 = $Buffer.Length
            $OutStream = $Response.OutputStream
            $Writer = [System.IO.StreamWriter]::new($OutStream)
            $Writer.AutoFlush = $true
            $Writer.WriteLine($Buffer,0,$Buffer.Length)
            $Writer.Close()
            $Response.Close()
        }
    }
    if ($Request.HttpMethod -eq 'POST') {
        $InStream = $Request.InputStream
        $Reader = [System.IO.StreamReader]::new($InStream)
        $Post   = $Reader.ReadToEnd()
        $Data     = "This is what you sent: $Post"
        $Buffer   = [Text.Encoding]::UTF8.GetBytes($Data)
        $Response.ContentLength64 = $Buffer.Length
        $OutStream = $Response.OutputStream
        $OutStream.Write($Buffer,0,$Buffer.Length)
        $Response.Close()
    }
}


################################


# Extra notes: on the server you can read a command that a client sent like so
# So for example let's say on the client you run:
Invoke-WebRequest -Uri "http://TheServer:8888/PowerShell?command=get-service winmgmt&format=json"

# and then on the server you can:
$command = $request.QueryString.Item('command')  # on this case: get-service winmgmt
$format  = $request.QueryString.Item('format')   # on this case: json

# Also you can do authentication like so:
# from the client:
Invoke-WebRequest -Uri 'http://TheServer:8888/Test/' -UseDefaultCredentials

# and on the server:
if ($request.IsAuthenticated) {
    $identity = $context.User.Identity
    if ($identity -eq 'ApprovedUser') { <# proceed #> }
    else { <# send status code 403 #> }
}
else { <# send status code 403 #> }  # HTTP Status Code 403 = Forbidden