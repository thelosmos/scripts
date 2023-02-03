- Get Active Directory Computers with OS and Last Login
```
Get-ADComputer -filter * -Properties * | Select Name, OperatingSystem, LastLogonDate
```
