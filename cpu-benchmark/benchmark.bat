@echo off
setlocal

echo ==========================
echo       LANGUAGE RACE
echo ==========================

echo.
echo [Python]
powershell -NoProfile -Command "Measure-Command { python py-port/main.py }"

echo.
echo [JavaScript]
powershell -NoProfile -Command "Measure-Command { node js-port/main.js }"

echo.
echo [Lua]
powershell -NoProfile -Command "Measure-Command { lua lua-port/main.lua }"

echo.
echo [Ruby]
powershell -NoProfile -Command "Measure-Command { ruby ruby-port/main.rb }"

pause