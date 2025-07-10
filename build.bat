@echo off
setlocal enabledelayedexpansion

REM Script de Deploy para Love2D (Windows)
REM Configurações
set PROJECT_NAME=solo_hero
set VERSION=0.1.0
set BUILD_DIR=build
set DIST_DIR=dist

echo.
echo ===============================================
echo    🎮 DEPLOY LOVE2D - %PROJECT_NAME%
echo ===============================================
echo.

REM Verificar se 7-Zip está disponível
where 7z >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ 7-Zip nao encontrado! Instale o 7-Zip para continuar.
    echo    Download: https://www.7-zip.org/
    pause
    exit /b 1
)

REM Limpar builds anteriores
echo 🧹 Limpando builds anteriores...
if exist %BUILD_DIR% rmdir /s /q %BUILD_DIR%
if exist %DIST_DIR% rmdir /s /q %DIST_DIR%
mkdir %BUILD_DIR%
mkdir %DIST_DIR%

REM Copiar arquivos do projeto
echo 📁 Copiando arquivos do projeto...
xcopy /e /i /q src\* %BUILD_DIR%\src 2>nul
xcopy /e /i /q assets\* %BUILD_DIR%\assets\ 2>nul
copy *.lua %BUILD_DIR%\ >nul 2>nul

REM Substituir DEV=true por DEV=false no conf.lua
echo 🔧 Desativando modo DEV em conf.lua...

powershell -Command "(Get-Content %BUILD_DIR%\conf.lua) -replace 'DEV\s*=\s*true', 'DEV = false' | Set-Content %BUILD_DIR%\conf.lua"

REM Verificar se há arquivos para fazer o build
if not exist %BUILD_DIR%\main.lua (
    echo ❌ Arquivo main.lua nao encontrado!
    echo    Certifique-se de que o projeto Love2D esta na pasta correta.
    pause
    exit /b 1
)

REM Criar arquivo .love
echo 📦 Criando arquivo .love...
cd %BUILD_DIR%
7z a -tzip "..\%DIST_DIR%\%PROJECT_NAME%-%VERSION%.love" .\*
cd ..

if not exist %DIST_DIR%\%PROJECT_NAME%-%VERSION%.love (
    echo ❌ Erro ao criar arquivo .love!
    pause
    exit /b 1
)

REM Verificar tamanho do arquivo
for %%I in (%DIST_DIR%\%PROJECT_NAME%-%VERSION%.love) do set LOVE_SIZE=%%~zI
set /a LOVE_SIZE_MB=%LOVE_SIZE%/1024/1024

echo.
echo ===============================================
echo ✅ BUILD CONCLUIDO COM SUCESSO!
echo ===============================================
echo 📦 Arquivo: %PROJECT_NAME%-%VERSION%.love
echo 📊 Tamanho: %LOVE_SIZE% bytes (~%LOVE_SIZE_MB% MB)
echo 📁 Local: %DIST_DIR%\
echo.

REM Verificar se Love2D está instalado
love --version >nul 2>nul
if %errorlevel% equ 0 (
    echo ✅ Love2D encontrado no sistema
    echo.
    set /p CHOICE="🚀 Executar o jogo agora? (S/N): "
    if /i "!CHOICE!"=="S" (
        start "" love %DIST_DIR%\%PROJECT_NAME%-%VERSION%.love
    )
) else (
    echo ⚠️  Love2D nao encontrado no PATH do sistema
    echo    Para testar: love %DIST_DIR%\%PROJECT_NAME%-%VERSION%.love
)

echo.
echo 📋 PROXIMOS PASSOS:
echo    1. Teste o arquivo .love criado
echo    2. Distribua o arquivo para outros usuarios
echo    3. Para executavel nativo, use ferramentas como love-release
echo.

REM Abrir pasta de destino
set /p CHOICE="📂 Abrir pasta de destino? (S/N): "
if /i "%CHOICE%"=="S" (
    start "" explorer %DIST_DIR%
)

echo.
echo 🎉 Deploy finalizado!
pause