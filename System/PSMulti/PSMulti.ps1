$parameters = @{
    ComputerName = ''
    ScriptBlock = { set-executionpolicy bypass;.ps1 }
}

Invoke-Command @parameters