Describe '- Connect via Named Pipes' -Tag 'Pipes' {

    BeforeAll {
        $PipeName = 'MyPipe{0}' -f [random]::new().next(100,900)
    }

    Context '- Which errors out if timeout expires' { # -Tag 'Pipes','Server','Timeout'
        It 'While starting a server' {
            $block = { Start-ServerConnection -Transport 'Pipes' -PipeName $PipeName -Timeout 2 }
            $err = $block | Should -Throw -Passthru
            $err.Exception.Message | Should -Be 'Timeout exceeded'
        }

        It 'While starting a client' {
            $block = { Start-ClientConnection -ComputerName $ComputerName -Transport 'Pipes' -PipeName $PipeName -Timeout 2 }
            $err = $block | Should -Throw -Passthru
            $err.Exception.Message | Should -BeLike "Pipe client connection failed*"
        }
    } #context timeout

    Context '- Initiate a connection while remote is a server' { # -Tag 'Pipes','Server'

        BeforeAll {
            #region --------------------------------------- Client-Server connection
            Start-Sleep -Milliseconds 500
            $Job = Invoke-Command -Session $sess -Scriptblock {
                $RegStart = Register-EngineEvent -SourceIdentifier 'Server.Started' -Action {$global:ServerStarted = $true} -MaxTriggerCount 1
                $RegStop  = Register-EngineEvent -SourceIdentifier 'Server.Stopped' -Action {$global:ServerStopped = $true} -MaxTriggerCount 1
                $con = Start-ServerConnection -Transport 'Pipes' -PipeName $using:PipeName -Timeout 10
            } -AsJob
            $con = Start-ClientConnection -ComputerName $ComputerName -Transport 'Pipes' -PipeName $PipeName -Timeout 10
            #endregion
        }

        Context '- When the connection starts' { # -Tag 'Pipes','Server','Start'

            It 'It creates a client connection object' {
                $con.Mode | Should -Be 'PipesClient'
                $con.PipeClient | Should -BeOfType System.IO.Pipes.NamedPipeClientStream
            }

            It 'It creates a server connection object [on the remote]' {
                Start-Sleep -Milliseconds 500
                $Remote = Invoke-Command -Session $sess -Scriptblock {
                    [pscustomobject] @{
                        Mode       = $con.Mode.ToString()
                        PipeServer = $con.PipeServer.pstypenames[0]
                    }
                }
                $Remote.Mode | Should -Be 'PipesServer'
                $Remote.PipeServer | Should -Be 'System.IO.Pipes.NamedPipeServerStream'
            }

            It "It opens a named pipe ($PipeName) [on the remote]" {
                Start-Sleep -Milliseconds 500
                $Remote = Invoke-Command -Session $sess -Scriptblock {
                    Get-ChildItem \\.\pipe\ | where name -eq $using:PipeName
                }
                $Remote.Name | Should -Be $PipeName
            }

            It 'It fires an event (ServerStarted) [on the remote]' {
                Start-Sleep -Milliseconds 500
                $Remote = Invoke-Command -Session $sess -Scriptblock {
                    Get-Variable -Name ServerStarted -Scope Global -ErrorAction Ignore
                }
                $Remote.Value | Should -Be $true
            }
        } #context server start

        It 'It sends and receives data' {
            SendTo-NetworkConnection -Connection $con -Data 'Test123'
            Start-Sleep -Milliseconds 500
            $Data = Invoke-Command -Session $sess -Scriptblock {ReceiveFrom-NetworkConnection -Connection $con}
            $Data | Should -Be 'Test123'
        }

        Context '- And when the connection ends' { # -Tag 'Pipes','Server','Stop'
        
            BeforeAll {
                Start-Sleep -Milliseconds 500
                Invoke-Command -Session $sess -Scriptblock {$con | Stop-NetworkConnection}
                $con | Stop-NetworkConnection
            }

            It 'It fires an event (ServerStopped) [on the remote]' {
                Start-Sleep -Milliseconds 500
                $Remote = Invoke-Command -Session $sess -Scriptblock {
                    Get-Variable -Name ServerStopped -Scope Global
                }
                $Remote.Value | Should -Be $true
            }

            It 'It closes the pipe [on the remote]' {
                Start-Sleep -Milliseconds 500
                $Remote = Invoke-Command -Session $sess -Scriptblock {
                    Get-ChildItem \\.\pipe\ | where name -eq $using:PipeName
                }
                $Remote.Name | Should -Be $null
            }

        } #context server stop

        AfterAll {
            Start-Sleep -Milliseconds 500
            Invoke-Command -Session $sess -Scriptblock {$con | Stop-NetworkConnection}
            $con | Stop-NetworkConnection
            $Job | Remove-Job -Force            
        }
    } #context server

    It 'It creates a connection while remote is a client' -Skip {  # <-- can't run client on remote cause it won't connect due to double hop issue (network access limitation when remoted)
        Start-Sleep -Milliseconds 500
        $Job = Invoke-Command -Session $sess -Scriptblock {
            $con = Start-ClientConnection -ComputerName $using:srv -Transport 'Pipes' -PipeName $using:PipeName -Timeout 10
        } -AsJob
        $con = Start-ServerConnection -Transport 'Pipes' -PipeName $PipeName -Timeout 10
        $con.Mode | Should -Be 'PipeClient'
        $Pipe = Get-ChildItem \\.\pipe\ | where name -eq $PipeName
        $Pipe.Name | Should -Be $PipeName
        $con | Stop-NetworkConnection
        Start-Sleep -Milliseconds 500
        Invoke-Command -Session $sess -Scriptblock { $con | Stop-NetworkConnection }
        $job | Remove-Job -Force
    }

    Write-Host "`n  Connect via Named Pipes Finished" -ForegroundColor Green

} #describe Pipes