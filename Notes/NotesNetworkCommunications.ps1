

## Notes 

<# Blocking Methods and Solutions

1) Blocking Method:
   - System.IO.Pipes.NamedPipeServerStream.WaitForConnection()
   Solution:
   - Use the BeginWaitForConnection($null,$null) method instead

2) Blocking Method:
   - System.IO.Pipes.NamedPipeClientStream.Connect()
   Solution:
   - Use the constructor with the Timeout parameter like so
     System.IO.Pipes.NamedPipeClientStream.Connect(5000)  # for 5 seconds timeout

3) Blocking Method:
   System.IO.StreamReader.ReadLine()
   Solution:
   - Unfortunately there is no solution to this one that will bypass the block
   - The thing that I do is use the method in a while loop and if the message received
     is "Exit" then break from the loop, so that it won't do ReadLine() again which will block
   - Another option would be to run the StreamReader inside a Runspace and if the runspace takes
     a while to respond (you can set a timeout via the [Diagnostics.Stopwatch] class), then
     kill the runspace.
   - IF the underlying stream is TCP then it supports Seek Operations which means that the 
     $StreamReader.Peek() method works and thus you can use that before ReadLine() to determine
     if there are data to be read or not.
     Unfortunately Named Pipes do no support seeking and hence the .Peek() method from StreamReader
     does not work correctly, it always returns -1
   - Also if the underlying stream is TCP, then the TcpClient class has the property .DataAvailable
     if true then you can go ahead and ReadLine. But unfortunately the Named Pipes classes do not have
     this property.
   - Notes: ReadLine will block until the underlying stream has a newline character
            The ReadLineAsync blocks as well, even though it says Async on the method's name.
   - A solution for the Named Pipes could be to use the native method BeginRead(),EndRead() instead
     of using a StreamReader(). I haven't tested it though.

4) Blocking Method:
   System.Net.Sockets.UdpClient.Receive()
   Solution:
   - 
     
#>

 <# The Test-Path function and the Server Named Pipes
 If you instatiate a System.IO.Pipes.NamedPipeServerStream class and then immediateley do a 
 Test-Path \\.\pipe\$PipeName, then you won't be able to run the .WaitForConnection() or the
 BeginWaitForConnection() methods

 You'll get an error saying 'The pipe is being closed' or 'The pipe is closed'.

 What is happening is that the Test-Path command manages to delete the pipe file from the system
 so after you have the server pipe object, if you run Test-Path once it returns True, meaning that
 it found the \\.\pipe\$PipeName file, but if you run it again it returns False.
 Hence the connection methods do not work.

 Also do note that you can't do the same on the Named Pipes Client, there is no \\.\pipe\$PipeName
 created there, this file is only created on the server.
#>

<# Dynamic Parameters, Positioning and ValidateNotNullOrEmpty
There's an issue when using dynamic parameters while also using the ValidateNotNullOrEmpty attribute on the
regular parameter.

For example if the regular parameter Transport is set to Pipes and then two new dynamic parameters show up,
the PipeName and the Timeout. In order for these to be used you need to set them immediately after Transport.
If you opt to use another regular paramter in between, for example ComputerName, then the function won't work.
If you opt to use another regular parameter before Transport then the function won't work. So the only way for
the function to work if you want to set the extra dynamic parameters is if you set them immediately after the
Transport parameter and if Trnasport comes in first.

So just don't use the ValidateNotNullOrEmpty attribute on the regular parameter.
#>

<# TCP Client/Server & associated classes

So when starting a TCP Server these are the classes involved:
- TcpListener   - this is the TCP server which listens to a specific port
- TcpClient     - this is the class that can produce the network stream
                  this is produced by the tcp server once a client is connected
- IAsyncResult  - this is used to identify if a client has connected or not
                  this is produced only by the Async connection method, BeginAcceptTcpClient()
                  if you use the regular blocking method, AcceptTcpClient(), then this class won't be used
- NetworkStream - this is the network stream that's used for transfering data back and forth
                  this is produced by the .GetStream() method of the TcpClient class
                  this is used with the StreamReader and StreamWriter classes to receive and send data accordingly

Server Process Steps:
1) TcpListener.New(LocalIP,localPort)
2) TcpListener.Start()
3) TcpClient = TcpListener.AcceptTcpClient()          # <-- Blocking method
            O R
   IAsyncResult = TcpListener.BeginAcceptTcpClient()  # <-- Non-blocking method (async method)
3b)if you used the BeginAcceptTcpClient() method then
   TcpClient = TcpListener.EndAcceptTcpClient(IAsyncResult)
4) NetworkStream = TcpClient.GetStream()
5) StreamReader(NetworkStream)
   StreamWriter(NetworkStream)

When starting a TCP CLient then these are the classes involved:
- TcpClient     - this is the client that will connect to a server
- IAsyncResult  - this is used to identify if a client has connected or not
                  this is produced only by the Async connection method, BeginAcceptTcpClient()
                  if you use the regular blocking method, AcceptTcpClient(), then this class won't be used
- NetworkStream - this is the network stream that's used for transfering data back and forth
                  this is produced by the .GetStream() method of the TcpClient class
                  this is used with the StreamReader and StreamWriter classes to receive and send data accordingly
                  
Client Process Steps:
1) TcpClient.New()
2) TcpClient.Connect(Server,Port)                      # <-- Blocking method
        O R
   IAsyncResult = TcpClient.BeginConnect(Server,Port)  # <-- Non-blocking method (async method)
2b)if you used the BeginConnect() method then
   TcpClient.EndConnect(IAsyncResult)
3) NetworkStream = TcpClient.GetStream()
4) StreamReader(NetworkStream)
   StreamWriter(NetworkStream)

#>

<# Classes, methods and their results

[System.Net.Sockets.TcpListener]
    .BeginAcceptTcpClient()  --> [System.IAsyncResult]
    .EndAcceptTcpClient()    --> [System.Net.Sockets.TcpClient]
    .AcceptTcpClient()       --> [System.Net.Sockets.TcpClient]

[System.Net.Sockets.TcpClient]
    .GetStream()             --> [System.Net.Sockets.NetworkStream]

#>

<# Initiate connection via Non-Blocking method & send/receive data via blocking method
So the module has been built with he following general idea in mind.
I use an Async way to establish the connection (which gives the IAsync object), for either
Named Pipes, TCP or UDP connections. So that if there's an issue with either end, then
the script won't get stuck. 
Once that's done (so once connected), I use a blocking method to receive data.
#>
