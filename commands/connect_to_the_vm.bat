@echo off
setlocal

echo connecting to the VM...
echo.

ssh -t -i "C:\Users\test\Desktop\PROJECTIME\DOURA\VMS\OCI-DOURA-MAIN-SERVER\ssh-key-2026-10-05.key" ubuntu@84.8.218.66 

echo.
pause
endlocal
