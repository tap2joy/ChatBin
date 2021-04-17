cd ./Gateway
taskkill /f /im Gateway.exe /t

ping -n 1 127.0.0.1 >nul
cd ../ChatService
taskkill /f /im ChatService.exe /t

ping -n 1 127.0.0.1 >nul
cd ../CenterService
taskkill /f /im CenterService.exe /t