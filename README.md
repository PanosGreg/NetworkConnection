## NetworkConnection
Initiate a client-server communication channel using PowerShell

## Disclaimer

This is an old module I wrote back in 2019, so the code is not as savvy.  
It can get some improvements in regards to clean code, readability, error-handling, SRP, KISS, .Net types with C#, etc...  
But the functions work nonetheless, it does what it's supposed to do.
Also the Pester tests were written for Pester v4, so they won't work with Pester v5, they need to be updated
I may spend a bit of time on the module at some stage if I have a break, we'll see.

Since this was an old module that I happened to restore from my computer, I've also added an extra folder with my notes from back then, as they are handy and give some context, even though they are not needed for the module to work.


## Examples

### TCP Example

- Open 2 powershell sessions, one will be the server and the other one will be the client

_first we'll set up a new client-server connection, we'll use the TCP transport for this one_

- On the server  
`$con = Start-ServerConnection -Transport TCP -PortNumber 1202 -Timeout 30 -Verbose`  
_let's say your local IP is 192.168.0.52_

- And now on the client  
`$con = Start-ClientConnection -ComputerName 192.168.0.52 -Transport TCP -PortNumber 1202 -Verbose`

_now let's send some data over the connection_

- From either the server or the client  
`SendTo-NetworkConnection -Connection $con -Data 'abcd'`
- And then on the other end  
`ReceiveFrom-NetworkConnection -Connection $con`

_finally let's close the connection_

- From both the server and the client  
`Stop-NetworkConnection -Connection $con -Verbose`

### Names Pipes Example
_same setup as above, 2 PS Sessions_

- On the server: `$con = Start-ServerConnection -Transport Pipes -PipeName MyConnection -Timeout 30 -Verbose`
- On the client: `$con = Start-ClientConnection -ComputerName 192.168.0.52 -Transport Pipes -PipeName MyConnection -Verbose`
- From either end: `SendTo-NetworkConnection -Connection $con -Data '1234'`
- On the other end: `ReceiveFrom-NetworkConnection -Connection $con`
- From both ends: `Stop-NetworkConnection -Connection $con -Verbose`


### UDP Example
_again same setup_

- On the server: `$con = Start-ServerConnection -Transport UDP -PortNumber 1202 -Timeout 30 -Verbose`
- On the client: `$con = Start-ClientConnection -ComputerName 192.168.0.52 -Transport UDP -PortNumber 1202 -Verbose`
- From either end: `SendTo-NetworkConnection -Connection $con -Data 'qqqq'`
- On the other end: `ReceiveFrom-NetworkConnection -Connection $con`
- From both ends: `Stop-NetworkConnection -Connection $con -Verbose`

### HTTP Example
_the only change on this setup, is that the PS Session on the server side needs to run as admin_

- On the server: `$con = Start-ServerConnection -Transport HTTP -PortNumber 1202 -Timeout 30 -Verbose`
- On the client: `$con = Start-ClientConnection -ComputerName 192.168.0.52 -Transport HTTP -PortNumber 1202 -Verbose`
- From either end: `SendTo-NetworkConnection -Connection $con -Data 'test12'`
- On the other end: `ReceiveFrom-NetworkConnection -Connection $con`
- From server end: `Stop-NetworkConnection -Connection $con -Verbose`  
_no need to stop the connection from the client side when using the HTTP transport_

