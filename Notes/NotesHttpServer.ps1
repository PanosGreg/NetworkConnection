

# HTTP Server Notes

<# Blocking Methods
The .GetContext() is a blocking method. This method can be used once you called the .Start() method and added at least one URI prefix
to use it in Async mode (non-blocking) use these methods: .BeginGetContext() and EndGetcontext()
The BeginGetContext() gives back an IAsyncResult object and the EndGetContext requires this object.
#>


<# Admin rights

This requires admin rights becasue the server can serve any one
$HttpServer.Prefixes.Add("http://+:$port/") 

But this does not need admin rights becuase the server can only server its own, meaning the locahost
$HttpServer.Prefixes.Add("http://localhost:$port/")
#>

<# /Exit/ URI prefix
This URI this will be used by the client to break out of the while loop on the server, ex http://dr-its-fsmgmt:8000/Exit/
This is similar to the 'Exit' message when doing Named Pipes or TCP connections
So the client just sends a GET request for this url http://dr-its-fsmgmt:8000/Exit/ and then the server stops
#>


<# HTTP Server .Close() vs .Stop() methods
When doing error handling there's no need to wait for the current web request to finish via .Stop()
in order to gracefully close the connection, because at that stage there's an error,
for example the timeout has expired, so just do Close() to remove the server
#>

# you can check that the web server port is actually open and listening with this command:
[bool][Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().where({$_.port -eq $port -and $_.AddressFamily -eq 'InterNetwork'})

<# Methods and what kind of classes they return

# On the Server
$HttpServer = [System.Net.HttpListener]::new()
$Context    = $HttpServer.GetContext()          # Returns: [System.Net.HttpListenerContext] <-- this is a blocking method
$Request    = $Context.Request                  # Returns: [System.Net.HttpListenerRequest]
$Response   = $Context.Response                 # Returns: [System.Net.HttpListenerResponse]
$OutStream  = $Response.OutputStream            # Returns: [System.IO.Stream]
$InStream   = $Request.InputStream              # Returns: [System.IO.Stream]

# On the Client
$Request    = [System.Net.HttpWebRequest]::Create('http://url')
$Response   = $Request.GetResponse()            # Returns: [System.Net.WebResponse]
$InStream   = $Response.GetResponseStream()     # Returns: [System.IO.Stream]
$OutStream  = $Request.GetRequestStream()       # Returns: [System.IO.Stream]

# On either the Client or Server
$Writer     = [System.IO.StreamWriter]::new($OutStream)  # Server:$Context.Response.OutputStream / Client: $Request.GetRequestStream()
$Reader     = [System.IO.StreamReader]::new($InStream)   # Server:$Context.Request.InputStream   / Client: $Request.GetResponse().GetResponseStream()

#>
