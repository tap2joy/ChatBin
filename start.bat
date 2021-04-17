cd ./CenterService
start CenterService.exe

ping -n 3 127.0.0.1 >nul
cd ../ChatService
start ChatService.exe

ping -n 3 127.0.0.1 >nul
cd ../Gateway
start Gateway.exe