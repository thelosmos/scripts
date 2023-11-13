# Script is expecting to find the xml files named ZD_User_Access_Task_**domain name**.xml and ZD_Enum_Task_**domain name**.xml.
# Powershell.exe -ExecutionPolicy Bypass -File
### Do not alter below variables.
#$aDSite = (Get-ADReplicationSite | select -Expandproperty Name)
$computerDomain = (Get-ADDomain -Current LocalComputer | select -ExpandProperty DNSRoot)
#$userAccTaskPath = "\\$computerDomain\SYSVOL\$computerDomain\scripts\ZDec\ZD_User_Access_Task_${aDSite}_$computerDomain.xml"
#$enumTaskPath = "\\$computerDomain\SYSVOL\$computerDomain\scripts\ZDec\ZD_Enum_Task_${aDSite}_$computerDomain.xml"
$userAccTaskPath = "\\$computerDomain\SYSVOL\$computerDomain\scripts\ZDec\ZD_User_Access_Task_$computerDomain.xml"
$enumTaskPath = "\\$computerDomain\SYSVOL\$computerDomain\scripts\ZDec\ZD_Enum_Task_$computerDomain.xml"
$userAccTask = @(Get-ScheduledTask -TaskName "ZD User Access*" | Select -ExpandProperty TaskName)
$enumTask = @(Get-ScheduledTask -TaskName "ZD Enumeration*" | Select -ExpandProperty TaskName)

# Checks if task xml files exist.
if ((Test-Path -Path $userAccTaskPath -PathType leaf) -and (Test-Path -Path $enumTaskPath -PathType leaf)) {

    # Appends hash of current scheduled task xml file to task name. This is used to determine if the file has been changed and the task needs to be updated.
    $userAccTaskHash =  (Get-FileHash -Algorithm MD5 -Path $userAccTaskPath | Select -ExpandProperty Hash)
    $enumTaskHash = (Get-FileHash -Algorithm MD5 -Path $enumTaskPath | Select -ExpandProperty Hash)
    $userAccTaskName = "ZD User Access $userAccTaskHash"
    $enumTaskName = "ZD Enumeration $enumTaskHash"

# Checks if a task is already installed. If not, it installs it.
    if ($userAccTask.count -eq 0) {
        Register-ScheduledTask -Xml (Get-Content $userAccTaskPath | Out-String) -TaskName $userAccTaskName
        Write-Output "Task $userAccTaskName has been registered"
        }
# If a task is already found to be installed, it unregisters them and installs the new one.
    elseif ($userAccTask -ne $userAccTaskName) {
        foreach ($item in $userAccTask) {
            Unregister-ScheduledTask -TaskName $item -Confirm:$false
            Write-Output "Task $item has been unregistered"
            Register-ScheduledTask -Xml (Get-Content $userAccTaskPath | Out-String) -TaskName $userAccTaskName
            Write-Output "Task $userAccTaskName has been registered"
        }
    }
    else {
        Write-Output "User access task is already up-to-date."
        }
    
# Checks if a task is already installed. If not, it installs it.
    if ($enumTask.count -eq 0) {
        Register-ScheduledTask -Xml (Get-Content $enumTaskPath | Out-String) -TaskName $enumTaskName
        Write-Output "Task $enumTaskName has been registered"
        }
# If a task is already found to be installed, it unregisters them and installs the new one.
    elseif ($enumTask -ne $enumTaskName) {
        foreach ($item in $enumTask) {
            Unregister-ScheduledTask -TaskName $item -Confirm:$false
            Write-Output "Task $item has been unregistered"
            Register-ScheduledTask -Xml (Get-Content $enumTaskPath | Out-String) -TaskName $enumTaskName
            Write-Output "Task $enumTaskName has been registered"
            }
        }
    else {
        Write-Output "Enumeration task is already up-to-date."
        }
}


else { 
    Write-Output "A Task xml file missing. Check for $userAccTaskPath and $enumTaskPath" 
    }

