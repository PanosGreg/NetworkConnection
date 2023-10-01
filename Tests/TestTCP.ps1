Describe '- Connect via TCP' -Tag 'TCP' {
    Context '- Which errors out if timeout expires' { # -Tag 'TCP','Server','Timeout'
        It 'While starting a server' {
            $block = { Start-ServerConnection -Transport 'TCP' -PortName Random -Timeout 2 }
            $err = $block | Should -Throw -Passthru
            $err.Exception.Message | Should -Be 'Timeout exceeded'
        }

        It 'While starting a client' -Skip { # <-- it works but takes 20 seconds to go through, need to fix the function
            $block = { Start-ClientConnection -ComputerName $ComputerName -Transport 'TCP' -PortName Random -Timeout 2 }
            $err = $block | Should -Throw -Passthru
            $err.Exception.Message | Should -BeLike "Timeout exceeded*"
        }
    } #context timeout

    Context '- Initiate a connection while being a server' { # -Tag 'TCP','Server'
        BeforeAll {
            #region --------------------------------------- Variables
            $Ports = @{
                RDP    = 3389
                SCCM   = 10123
                Sophos = 8194
                Lync   = 5061
                AD     = 445
                LDAP   = 389
                SCOM   = 5723
            }
            $UsedPorts = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().where({$_.AddressFamily -eq 'InterNetwork'}).Port
            foreach ($p in ($Ports.GetEnumerator() | Get-Random -Count $Ports.Count)) {
                if   ($UsedPorts.Contains($p.Value)) {Continue}
                else {$PortName = $p.Key ; Break}
            }
            #endregion

            $RegStart = Register-EngineEvent -SourceIdentifier 'Server.Started' -Action {$global:ServerStarted = $true} -MaxTriggerCount 1
            $RegStop  = Register-EngineEvent -SourceIdentifier 'Server.Stopped' -Action {$global:ServerStopped = $true} -MaxTriggerCount 1
        } #BeforeAll

        Context '- When the connection starts' { # -Tag 'TCP','Server','Start'
            BeforeAll {
                #region --------------------------------------- Client-Server connection
                Start-Sleep -Milliseconds 500
                $Job = Invoke-Command -Session $sess -Scriptblock {
                    $con = Start-ClientConnection -ComputerName $using:srv -Transport 'TCP' -PortName $using:PortName -Timeout 10
                } -AsJob
                $con = Start-ServerConnection -Transport 'TCP' -PortName $PortName -Timeout 10 -AllowFirewall
                #endregion
            }

            It 'It creates a connection object' {
                $con.Mode | Should -Be 'TcpServer'
                $con.TcpStream | Should -BeOfType System.Net.Sockets.NetworkStream
                $con.TcpClient | Should -BeOfType System.Net.Sockets.TcpClient
            }

            It "It opens a local port ($PortName $($Ports[$PortName]))" {
                $EndPoint = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpConnections().where({$_.LocalEndPoint.Port -eq $Ports[$PortName]})
                $EndPoint.State | Should -Be 'Established'
                $EndPoint.RemoteEndPoint.Address.ToString() | Should -Be "$([System.Net.DNS]::GetHostAddresses($ComputerName).IPAddressToString)"
            }

            It 'It creates a firewall rule' {
                $Rule = Get-NetFirewallRule -Name 'PSRemotingServer' -ErrorAction SilentlyContinue
                $Rule.Name | Should -Be 'PSRemotingServer'
            }

            It 'It fires an event (ServerStarted)' {
                $global:ServerStarted | Should -Be $true
            }

            AfterAll {
                $Job | Remove-Job -Force
                Remove-Variable -Name ServerStarted -Force -Scope Global
            }

        } #context server start

        Context '- And when the connection ends' { # -Tag 'TCP','Server','Stop'
        
            BeforeAll {
                Start-Sleep -Milliseconds 500
                Invoke-Command -Session $sess -Scriptblock {$con | Stop-NetworkConnection}
                $con | Stop-NetworkConnection
            }

            It 'It fires an event (ServerStopped)' {
                $global:ServerStopped | Should -Be $true            
            }

            It 'It removes the firewall rule' {
                $block = { Get-NetFirewallRule -Name 'PSRemotingServer' -ErrorAction Stop }
                $block | Should -Throw
            }

            It 'It closes the open port' {
                $EndPoint = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpConnections().where({$_.LocalEndPoint.Port -eq $Ports[$PortName]})
                $EndPoint | Should -Be $null
            }

            AfterAll {
                $RegStart,$RegStop | Remove-Job -Force
                Remove-Variable -Name ServerStopped -Force -Scope Global
            }
        } #context server stop

    } #context server

    Context '- Initiate a connection while being a client' { # -Tag 'TCP','Client'
        BeforeAll {
            #region --------------------------------------- Client-Server connection
            $PortNumber = [random]::new().next(59000,59999)
            Start-Sleep -Milliseconds 500
            $Job = Invoke-Command -Session $sess -Scriptblock {
                $con = Start-ServerConnection -Transport 'TCP' -PortNumber $using:PortNumber -Timeout 10 -AllowFirewall
            } -AsJob
            $con = Start-ClientConnection -ComputerName $ComputerName -Transport 'TCP' -PortNumber $PortNumber -Timeout 10
            #endregion
        } #BeforeAll

        It "It creates a connection object on port $PortNumber" {
            $con.Mode | Should -Be 'TcpClient'
            $con.TcpStream | Should -BeOfType System.Net.Sockets.NetworkStream
            $con.TcpClient | Should -BeOfType System.Net.Sockets.TcpClient
            $con.TcpClient.Client.RemoteEndpoint.Port | Should -Be $PortNumber
        }

        It 'It sends and receives data' {
            SendTo-NetworkConnection -Connection $con -Data 'Test123'
            Start-Sleep -Milliseconds 500
            $Data = Invoke-Command -Session $sess -Scriptblock {ReceiveFrom-NetworkConnection -Connection $con}
            $Data | Should -Be 'Test123'
        }

        AfterAll {
            Start-Sleep -Milliseconds 500
            Invoke-Command -Session $sess -Scriptblock {$con | Stop-NetworkConnection}
            $con | Stop-NetworkConnection
            $job | Remove-Job -Force
            Remove-Variable -Name Con,Job
        }
    } #context client

    Write-Host "`n  Connect via TCP Finished" -ForegroundColor Green

} #describe TCP