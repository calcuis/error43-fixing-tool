@echo off & cls & break off & setlocal EnableDelayedExpansion
  
:admin_access
  >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
  if '%errorlevel%' NEQ '0' (
     echo Requesting administrative privileges... 
     goto UAC_prompt
  )  else (goto :start_as_admin)

:UAC_prompt
  echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
  set params = %*:"=""
  echo UAC.ShellExecute "cmd.exe", "/c %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"
  "%temp%\getadmin.vbs"
  del "%temp%\getadmin.vbs"
  exit /b

:start_as_admin
  set curpath=%~dp0
  set curpath=%curpath:~0,-1%
  pushd . & cd /D %curpath%
  set NV_KEY=RM1774520& set NV_KEY_DATA=0x1& set NV_KEY_TYPE=REG_DWORD
  
:text_strings_banner
  set        SCRIPT_NAME=error43-fixer

:text_strings_msgs
  set          PRESS_KEY=Press any key to exit . . . 
  set         NO_NV_GPUS=No Nvidia GPUs found. Please attach one and ensure it's driver is installed.
  set NO_NV_ERROR43_GPUS=No Nvidia GPUs in error code 43 state found.  Nothing to do.
  set       ALREADY_FIXED=is already registry patched but still has error code 43.
  set          APPLY_FIX=has error code 43. Applying registry patch.
  set         FIX_FAILED=ERROR. Registry patch failed. Please manually add using regedit:
  set           IS_FIXED=is fixed. Now reports as:
  set        IS_NOT_FIXED=still has a problem:
  set         RESTART_GPU=restarting adapter.
  set   MORE_EGPUIO_FIXES=.  Press any key to see other fixes for error code 43 . .
  set    "NV_REG_CHANGE_1=  Registry changes have been made. Note: "
  set    "NV_REG_CHANGE_2=    1. RE-RUN this script if you delete or reinstall this GPU ^& error code 43 reappears."
  set    "NV_REG_CHANGE_3=    2. To UNDO this change, uninstall the adapter in Device Manager-^>Display adapters ^& restart."
 (set NL=^
%=EMPTY=%
)
 
:banner  
  echo(
  echo   [97;42m                                          [0m
  echo   [97;42m   %SCRIPT_NAME% %SCRIPT_VER%            [0m
  echo   [97;42m   %SCRIPT_AUTH%      [0m
  echo   [97;42m                                          [0m
  echo   [97;42m   %SCRIPT_HOME%   [0m
  echo   [97;42m                                          [0m
  echo(
  set GPU_ADAPTERS=REG QUERY HKLM\System\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}
  for  /F %%i in ('%GPU_ADAPTERS% ^| findstr "^HKEY_LOCAL.*\\....$"') do (
     reg query %%i /v DriverDesc 2>nul | findstr /I "NVidia" > nul 
     if not errorlevel 1 set NV_ADAPTERS=!NV_ADAPTERS! %%i
   )
   for %%i in (%NV_ADAPTERS%) do (
    call :patch_NV_adapter %%i
  )
  if not "%NV_FIXED%"=="" (
     echo ^!NL!%NV_REG_CHANGE_1%^!NL!^!NL!%NV_REG_CHANGE_2%^!NL!%NV_REG_CHANGE_3%
    goto :press_key_exit	 
  )
  if "%NV_ADAPTERS%"     =="" echo   %NO_NV_GPUS%         & goto :press_key_exit
  if "%NV_ERR43_FOUND%"  =="" echo   %NO_NV_ERROR43_GPUS% & goto :press_key_exit
  echo(
  pause>nul|set/p =  %MORE_EGPUIO_FIXES%
  start "" %EGPUIO_FIXES_URL%
  goto :END
  
  :press_key_exit
  echo(& pause>nul|set/p =.  %PRESS_KEY%
  goto :END

:patch_NV_adapter
  set NV_dev_key=%1
  
  for /f "skip=1 tokens=3,*" %%j in ('REG QUERY "%NV_dev_key%" /v MatchingDeviceId') do set HW_id=%%j
  for /f "skip=1 tokens=2,*" %%j in ('REG QUERY "%NV_dev_key%" /v DriverDesc') do set NV_adapter=%%k

  call devset status "%HW_id%" | findstr "code 43" > nul
  if errorlevel 1 goto :EOF
  set NV_ERR43_FOUND=1
  
  reg query %NV_dev_key% /v %NV_KEY% 2>nul | findstr "%NV_KEY%.*%NV_KEY_TYPE%.*%NV_KEY_DATA%" > nul
  if not errorlevel 1 echo   [%NV_adapter%] %ALREADY_FIXED% & goto :EOF
  
  echo   [%NV_adapter%] %APPLY_FIX%
  reg add %NV_dev_key% /v %NV_KEY% /t %NV_KEY_TYPE% /d %NV_KEY_DATA% /f > nul
  reg query %NV_dev_key% /v %NV_KEY% 2>nul  | findstr "%NV_KEY%.*%NV_KEY_TYPE%.*%NV_KEY_DATA%" > nul
  
  if errorlevel 1 (
    echo(
	echo   [%NV_adapter%] %FIX_FAILED%
	echo(
	echo   Key:  %NV_dev_key% 
	echo   Data: %NV_KEY% = %NV_KEY_DATA% (%NV_KEY_TYPE%^)
	goto :EOF
  )
  
  set NV_CHANGES=1
  echo   [%NV_adapter%] %RESTART_GPU%
  call devset restart "%HW_id%" > nul
  
  timeout /T 2 /nobreak > nul
  for /f "skip=2 delims=" %%j in ('call devset status "%HW_id%"') do (set NV_status="%%j"&goto :trim_left)

  :trim_left
  set NV_status=%NV_status:"=%
  for /f "tokens=* delims= " %%j in ("%NV_status%") do set NV_status=%%j

  call devset status "%HW_id%" | findstr "Driver is running." > nul
  if NOT errorlevel 1 (
     set NV_FIXED=1
     echo   [%NV_adapter%] %IS_FIXED% '%NV_status%'
     goto :EOF
   )

  echo   [%NV_adapter%] %IS_NOT_FIXED% '%NV_status%'
  goto :EOF
  
:END
  echo(
  popd
  endlocal 
