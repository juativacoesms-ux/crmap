@echo off
title Painel Administrativo CRMAP
cd /d "%~dp0"
cd painel
echo Iniciando o Painel de Gerenciamento de Produtos...
echo Por favor, mantenha esta janela aberta enquanto estiver usando o painel.
echo.
echo Abrindo o painel no seu navegador...
start http://localhost:3000
node server.js
pause
