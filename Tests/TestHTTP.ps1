Describe '- Connect via HTTP' -Tag 'HTTP' {

    BeforeAll {
        $RandomPort = [random]::new().next(59000,59999)
        $UsedPorts  = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().where({$_.AddressFamily -eq 'InterNetwork'}).Port        
        for ($i = 0 ; $i -le 10; $i++) {
            if   ($UsedPorts.Contains($RandomPort+$i)) {Continue}
            else {$PortNumber = $RandomPort+$i ; Break}
        }
    }

    Context '- Which errors out if timeout expires' { # -Tag 'HTTP','Server','Timeout'
        It 'While starting a server' {
            $block = { Start-ServerConnection -Transport 'HTTP' -PortNumber $PortNumber -Timeout 2 }
            $err = $block | Should -Throw -Passthru
            $err.Exception.Message | Should -Be 'Timeout exceeded'
        }

        It 'While starting a client' {
            $block = { Start-ClientConnection -ComputerName $ComputerName -Transport 'HTTP' -PortNumber $PortNumber -Timeout 2 }
            $err = $block | Should -Throw -Passthru
            $err.Exception.Message | Should -BeLike "Timeout exceeded*"
        }
    } #context timeout

    Context '- Initiate a connection while being a server' { # -Tag 'HTTP','Server'
        BeforeAll {
            $RegStart = Register-EngineEvent -SourceIdentifier 'Server.Started' -Action {$global:ServerStarted = $true} -MaxTriggerCount 1
            $RegStop  = Register-EngineEvent -SourceIdentifier 'Server.Stopped' -Action {$global:ServerStopped = $true} -MaxTriggerCount 1

            #region --------------------------------------- Client-Server connection
            Start-Sleep -Milliseconds 500
            $Job = Invoke-Command -Session $sess -Scriptblock {
                $con = Start-ClientConnection -ComputerName $using:srv -Transport 'HTTP' -PortNumber $using:PortNumber -Timeout 15
            } -AsJob
            $con = Start-ServerConnection -Transport 'HTTP' -PortNumber $PortNumber -Timeout 15 -AllowFirewall
            #endregion            
        } #BeforeAll

        Context '- When the connection starts' { # -Tag 'HTTP','Server','Start'

            It 'It creates a connection object' {
                $con.Mode | Should -Be 'HttpServer'
                $con.HttpServer | Should -BeOfType System.Net.HttpListener
            }

            It "It opens a local port ($PortNumber)" {
                $IP = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().where({$_.AddressFamily -eq 'InterNetwork' -and $_.Port -eq $PortNumber})
                $IP.Port | Should -Be "$($PortNumber)"
            }

            It 'It creates a firewall rule' {
                $Rule = Get-NetFirewallRule -Name 'PSRemotingServer' -ErrorAction SilentlyContinue
                $Rule.Name | Should -Be 'PSRemotingServer'
            }

            It 'It fires an event (ServerStarted)' {
                $global:ServerStarted | Should -Be $true
            }

        } #context server start

        It 'It sends and receives data' {
            Start-Sleep -Milliseconds 500
            $JobHttp = Invoke-Command -Session $sess -Scriptblock {ReceiveFrom-NetworkConnection -Connection $con} -AsJob
            SendTo-NetworkConnection -Connection $con -Data 'Test123'
            $Data = $JobHttp | Receive-Job -AutoRemoveJob -Wait
            $Data | Should -Be 'Test123'
        }

        Context '- And when the connection ends' { # -Tag 'HTTP','Server','Stop'
        
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
                $IP = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().where({$_.AddressFamily -eq 'InterNetwork' -and $_.Port -eq $PortNumber})
                $IP.Port | Should -Be $null
            }
        } #context server stop

        AfterAll {
            $RegStart,$RegStop,$Job | Remove-Job -Force
            Remove-Variable -Name 'ServerStarted' -Force -Scope Global -ErrorAction Ignore
            Remove-Variable -Name 'ServerStopped' -Force -Scope Global -ErrorAction Ignore
        }

    } #context server

    It 'It creates a connection as a client' -Skip {  # <-- for whatever reason HTTP listener does not work on that remote computer
        Start-Sleep -Milliseconds 500
        $Job = Invoke-Command -Session $sess -Scriptblock {
            $con = Start-ServerConnection -Transport 'HTTP' -PortNumber $using:PortNumber -Timeout 10 -AllowFirewall
        } -AsJob
        $con = Start-ClientConnection -ComputerName $ComputerName -Transport 'HTTP' -PortNumber $PortNumber -Timeout 10
        $con.Mode | Should -Be 'HttpClient'
        $con.HttpClient | Should -BeOfType System.Net.HttpWebRequest
        $con | Stop-NetworkConnection
        $job | Remove-Job -Force
    }

    Write-Host "`n  Connect via HTTP Finished" -ForegroundColor Green

} #describe HTTP