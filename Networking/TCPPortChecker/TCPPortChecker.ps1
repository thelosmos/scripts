# Checks lists of hosts for open tcp ports provided in parameters. If no ports are defined, 135, 139, and 445 are used.


param([String[]] $ComputerName, [Array] $Port)
if (!($Port)){
  $Port = @('135', '139', '445')
  }
foreach ($p in $Port) {
  foreach ($i in $ComputerName) {
  Test-NetConnection -ComputerName $i -Port $p | Format-Table -Property ComputerName, RemoteAddress, PingSucceeded, RemotePort, TCPTestSucceeded
  }
}

