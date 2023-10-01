$Job = Start-Job -Name HttpServer -ScriptBlock {
Write-Output 'Starting Server'
$HttpServer = [System.Net.HttpListener]::new()
$HttpPort   = 8000
$Prefix     = 'http://{0}:{1}/' -f 'localhost',$HttpPort
$HttpServer.Prefixes.Add($Prefix)
$HttpServer.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Anonymous
$HttpServer.Start()
$Context  = $HttpServer.GetContext()
$Request  = $Context.Request
$Response = $Context.Response
$Response.Headers.Set([System.Net.HttpResponseHeader]::Server,"$env:COMPUTERNAME.TestServer")

$OutStream        = $Response.OutputStream
$Writer           = [System.IO.StreamWriter]::new($OutStream)
$Writer.AutoFlush = $true
$InStream         = $Request.InputStream
$Reader           = [System.IO.StreamReader]::new($InStream)

if ($Request.HttpMethod -eq 'GET') {
  if ($Request.Url.LocalPath -eq '/') {
    $Data = 'This is a Test Web Server'
    $Writer.WriteLine($Data)
    Write-Output 'GET request received'
  } #if http://../
  else {
    $Data = 'Invalid URL'
    $Writer.WriteLine($Data)
  }
} #if GET
if ($Request.HttpMethod -eq 'POST') {
  $Post   = $Reader.ReadToEnd()
  $Data   = "This is what you sent: $Post"
  $Writer.WriteLine($Data)
  Write-Output 'POST request received'
} #if POST

Start-Sleep -Milliseconds 500
$Writer.Close()
$Reader.Close()
$InStream.Close()
$OutStream.Close()
$Response.Close()
$HttpServer.Stop()
$HttpServer.Close()
Write-Output 'Server Stopped'
} #job

function Get-ServerResponse ($URI,$Method) {
$ProgressPreference = 'SilentlyContinue'
if ($Method -eq 'GET') {
    $Connect = Invoke-WebRequest -Uri $URI -Method GET -TimeoutSec 5
}
elseif ($Method -eq 'POST') {
    $Connect = Invoke-WebRequest -Uri $URI -Method POST -TimeoutSec 5 -Body 'This is the Data'
}
else {Return 'Invalid Method'}

$ProgressPreference = 'Continue'
[Text.Encoding]::UTF8.GetString($Connect.Content)
}

$URI = 'http://{0}:{1}/' -f 'localhost','8000'
Get-ServerResponse -URI $URI -Method GET
$Job | Receive-Job -AutoRemoveJob -Wait