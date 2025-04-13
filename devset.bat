@echo off
  if "%windir%"=="" goto not_win

  pushd . & cd /D %~dp0
  if NOT "%1"=="" goto start

:usage
  echo.&echo USAGE: devset param1 param2 .. param9 & echo.& echo A wrapper that checks if this is a 32-bit or 64-bit OS and&echo then calls the 32/64-bit devcon binary with parameters specified.
  call :check_os
  echo.
  if "%os_v%"=="64" echo detected: 64-bit OS installed (devcon64)
  if "%os_v%"==""   echo detected: 32-bit OS installed (devcon)
  echo.
  echo NOTE: Use quotes around any deviceID params with ampersands in them.
  echo.
  goto :exit

:start
  call :check_os
  devcon%os_v% %1 %2 %3 %4 %5 %6 %7 %8 %9 
  goto exit

:check_os
  set OS_v=
  REG.exe Query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -v BuildLabEx | Find /i "amd64"  > nul
  If %ERRORLEVEL% == 0 set OS_v=64
  goto :EOF

:not_Win
  echo.
  echo [devset] ERROR: Please run this utility while in Windows XP/Vista/W7.
  echo.
  goto endDOS

:exit
  set os_v=
  popd

:endDOS
