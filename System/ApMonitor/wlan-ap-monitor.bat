:loop
set time_hh=%time:~0,2%
if %time_hh% lss 10 (set time_hh=0%time:~1,1%)
set time_mn=%time:~3,2%
set time_ss=%time:~6,2%
set time_ms=%time:~9,2%


echo %time_hh%:%time_mn%:%time_ss%.%time_ms% >> WLANstat_%date:~-4,4%%date:~-7,2%%date:~-10,2%.txt
netsh WLAN show interfaces >> %cd%\WLANstat_%date:~-4,4%%date:~-7,2%%date:~-10,2%.txt
timeout /t 5
goto loop