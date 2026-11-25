@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
title DAVe

rem ============================================================
rem  DAVe — запуск под Windows
rem  Использование:
rem    run-dave.bat          обычный запуск (сборка при необходимости)
rem    run-dave.bat dev      режим разработки (hot reload, порт 5173)
rem    run-dave.bat build    принудительная пересборка и запуск
rem ============================================================

rem --- Проверка Node.js (нужен 22.13+ или 24 LTS: модуль node:sqlite) ---
where node >nul 2>nul
if errorlevel 1 goto :no_node

for /f "tokens=1,2 delims=." %%a in ('node -p "process.versions.node"') do (
    set "NODE_MAJOR=%%a"
    set "NODE_MINOR=%%b"
)
if !NODE_MAJOR! LSS 22 goto :node_old
if !NODE_MAJOR! EQU 22 if !NODE_MINOR! LSS 13 goto :node_old
goto :node_ok

:no_node
echo [ОШИБКА] Node.js не найден. Установите LTS с https://nodejs.org
pause
exit /b 1

:node_old
echo [ОШИБКА] Node.js !NODE_MAJOR!.!NODE_MINOR! слишком старый.
echo Нужен Node.js 22.13+ или 24 LTS (встроенный модуль node:sqlite).
pause
exit /b 1

:node_ok

rem --- Первый запуск: создаём .env ---
if exist ".env" goto :env_ok

echo Первый запуск: создаю файл .env
echo.
echo Примеры URL:
echo   Baikal:   https://baikal.example.com/dav.php
echo   Radicale: http://radicale.example.com:5232
echo.
set /p "DAV_URL=Введите URL вашего DAV-сервера: "
if "!DAV_URL!"=="" (
    echo [ОШИБКА] URL не введён. Запустите файл снова.
    pause
    exit /b 1
)

rem Генерируем SESSION_SECRET (64 hex-символа) средствами Node
for /f "usebackq delims=" %%s in (`node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`) do set "SECRET=%%s"

rem Папка для данных рядом с проектом; слеши вперёд — так надёжнее для .env
set "DATA_DIR=%~dp0data"
set "DATA_DIR=!DATA_DIR:\=/!"

(
    echo DAV_BASE_URL="!DAV_URL!"
    echo SESSION_SECRET=!SECRET!
    echo DATA_DIR="!DATA_DIR!"
    echo PORT=3000
    echo TRUST_PROXY=0
) > ".env"

echo.
echo .env создан. Базы сессий и кэша будут лежать в папке data рядом с файлом.
echo Настройки можно поменять, отредактировав .env вручную.
echo.

:env_ok

rem --- Зависимости ---
if exist "node_modules" goto :deps_ok
echo Устанавливаю зависимости: npm install ...
call npm install
if errorlevel 1 (
    echo [ОШИБКА] npm install завершился с ошибкой.
    pause
    exit /b 1
)

:deps_ok

rem --- Режим разработки ---
if /i "%~1"=="dev" (
    echo Запуск dev-режима: frontend http://localhost:5173 , backend :3000
    call npm run dev
    pause
    exit /b 0
)

rem --- Сборка (если нет готового фронтенда или запрошен build) ---
if /i "%~1"=="build" goto :do_build
if exist "packages\frontend\dist" goto :build_ok

:do_build
echo Собираю проект: npm run build ...
call npm run build
if errorlevel 1 (
    echo [ОШИБКА] Сборка не удалась.
    pause
    exit /b 1
)

:build_ok

rem --- Запуск ---
echo.
echo DAVe запускается: http://localhost:3000  (если не меняли PORT в .env)
echo Остановка: Ctrl+C или закройте окно.
echo.
set "NODE_ENV=production"
node --env-file=.env packages/backend/dist/server.js

echo.
echo Сервер остановлен.
pause
exit /b 0