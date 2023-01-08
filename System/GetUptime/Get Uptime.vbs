


On Error Resume Next

Set WshShell = WScript.CreateObject("WScript.Shell")

Do
   ComputerName = InputBox("You want to Get Uptime, eh?" & vbcrlf & vbcrlf & "Enter the computer name or click Cancel to quit.", "Get Uptime", ComputerName)

   If IsEmpty(ComputerName) Then
     Wscript.Quit
   Else
      If Not IsPingable(ComputerName) Then
        MsgBox "Could not ping the computer named " & ComputerName & "." & vbcrlf & vbcrlf & "Please try again.", 0, "Error"
      Else
        'Wscript.Echo "cmd.exe /k C:\Misc\Tools\Misc\uptime.exe /computername:" & ComputerName & " /s"
        'WshShell.Run "cmd.exe /k C:\Misc\Tools\Misc\uptime.exe /computername:" & ComputerName & " /s"
	wshShell.Run """\\pmcucarefs1\wmhome\Scripts\lsrunase.exe"" imprivata ADMIN_DOMAIN1 ZzrjHca_LGnOaDQmXHUN ""cmd.exe /k C:\Misc\Tools\Misc\uptime.exe /computername:" & ComputerName & " /s""", 0, False

      End If
   End If
Loop



Function IsPingable(ComputerName)
 Dim objShell, objExec, strCmd, strTemp
 
 strCmd = "ping -n 1 " & ComputerName
 
 Set objShell = CreateObject("WScript.Shell")
 Set objExec = objShell.Exec(strCmd)
 strTemp = UCase(objExec.StdOut.ReadAll)
 
 If InStr(strTemp, "MS") Then
    IsPingable = True
 Else
    IsPingable = False
 End If
End Function