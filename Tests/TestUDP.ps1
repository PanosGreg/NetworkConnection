Describe '- Connect via UDP' -Tag 'UDP' {
    Context '- Which errors out if timeout expires' { # -Tag 'UDP','Server','Timeout'
        It 'While starting a server' {
            $block = { Start-ServerConnection -Transport 'UDP' -PortName Random -Timeout 2 }
            $err = $block | Should -Throw -Passthru
            $err.Exception.Message | Should -Be 'Timeout exceeded'
        }

        It 'While starting a client' {
            $block = { Start-ClientConnection -ComputerName $ComputerName -Transport 'UDP' -PortName Random -Timeout 2 }
            $err = $block | Should -Throw -Passthru
            $err.Exception.Message | Should -BeLike "Timeout exceeded*"
        }
    } #context timeout

    Context '- Initiate a connection while being a server' { # -Tag 'UDP','Server'
        BeforeAll {
            #region --------------------------------------- Variables
            $Ports = @{
                DNS    = 53
                DHCP   = 67
                NTP    = 123
            }
            $UsedPorts = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveUdpListeners().where({$_.AddressFamily -eq 'InterNetwork'}).Port
            foreach ($p in ($Ports.GetEnumerator() | Get-Random -Count $Ports.Count)) {
                if   ($UsedPorts.Contains($p.Value)) {Continue}
                else {$PortName = $p.Key ; Break}
            }
            #endregion

            $RegStart = Register-EngineEvent -SourceIdentifier 'Server.Started' -Action {$global:ServerStarted = $true} -MaxTriggerCount 1
            $RegStop  = Register-EngineEvent -SourceIdentifier 'Server.Stopped' -Action {$global:ServerStopped = $true} -MaxTriggerCount 1
        } #BeforeAll

        Context '- When the connection starts' { # -Tag 'UDP','Server','Start'
            BeforeAll {
                #region --------------------------------------- Client-Server connection
                Start-Sleep -Milliseconds 500
                $Job = Invoke-Command -Session $sess -Scriptblock {
                    $con = Start-ClientConnection -ComputerName $using:srv -Transport 'UDP' -PortName $using:PortName -Timeout 10
                } -AsJob
                $con = Start-ServerConnection -Transport 'UDP' -PortName $PortName -Timeout 10 -AllowFirewall
                #endregion
            }

            It 'It creates a connection object' {
                $con.Mode | Should -Be 'UdpServer'
                $con.UDP | Should -BeOfType System.Net.Sockets.UdpClient
            }

            It "It opens a local port ($PortName $($Ports[$PortName]))" {
                $IP = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveUdpListeners().where({$_.AddressFamily -eq 'InterNetwork' -and $_.Port -eq $Ports[$PortName]})
                $IP.Port | Should -Be "$($Ports[$PortName])"
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

        Context '- And when the connection ends' { # -Tag 'UDP','Server','Stop'
        
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
                $IP = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveUdpListeners().where({$_.AddressFamily -eq 'InterNetwork' -and $_.Port -eq $Ports[$PortName]})
                $IP | Should -Be $null
            }

            AfterAll {
                $RegStart,$RegStop | Remove-Job -Force
                Remove-Variable -Name ServerStopped -Force -Scope Global
            }
        } #context server stop

    } #context server

    Context '- Initiate a connection while being a client' { # -Tag 'UDP','Client'
        BeforeAll {
            #region --------------------------------------- Client-Server connection
            $PortNumber = [random]::new().next(59000,59999)
            Start-Sleep -Milliseconds 500
            $Job = Invoke-Command -Session $sess -Scriptblock {
                $con = Start-ServerConnection -Transport 'UDP' -PortNumber $using:PortNumber -Timeout 10 -AllowFirewall
            } -AsJob
            $con = Start-ClientConnection -ComputerName $ComputerName -Transport 'UDP' -PortNumber $PortNumber -Timeout 10
            #endregion
        } #BeforeAll

        It "It creates a connection object on port $PortNumber" {
            $con.Mode | Should -Be 'UdpClient'
            $con.UDP | Should -BeOfType System.Net.Sockets.UdpClient
            $con.UDP.Client.RemoteEndpoint.Port | Should -Be $PortNumber
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

    Write-Host "`n  Connect via UDP Finished" -ForegroundColor Green    

} #describe UDP