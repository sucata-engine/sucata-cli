@echo off
setlocal

set LUAJIT_COMMIT=ea9eb7edb5eac4a9d175d74523db34fac0fa5180
set ROOT_DIR=%~dp0..\..
set WORK_DIR=%ROOT_DIR%\temp\luajit-build

if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"
git clone https://github.com/LuaJIT/LuaJIT.git "%WORK_DIR%" || exit /b 1
git -C "%WORK_DIR%" checkout %LUAJIT_COMMIT% || exit /b 1

pushd "%WORK_DIR%\src"
call msvcbuild.bat amalg || (popd & exit /b 1)
popd

if not exist "%ROOT_DIR%\src\luajit\lib\windows" mkdir "%ROOT_DIR%\src\luajit\lib\windows"
copy /y "%WORK_DIR%\src\lua51.lib" "%ROOT_DIR%\src\luajit\lib\windows\lua51.lib" || exit /b 1
copy /y "%WORK_DIR%\src\lua51.dll" "%ROOT_DIR%\lua51.dll" || exit /b 1
rmdir /s /q "%WORK_DIR%"

echo LuaJIT installed at src\luajit\lib\windows\lua51.lib and lua51.dll
