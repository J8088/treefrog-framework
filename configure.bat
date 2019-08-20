@echo OFF
@setlocal

set VERSION=1.26.0
set TFDIR=C:\TreeFrog\%VERSION%
set MONBOC_VERSION=1.9.5
set LZ4_VERSION=1.9.2
set BASEDIR=%~dp0

:parse_loop
if "%1" == "" goto :start
if /i "%1" == "--prefix" goto :prefix
if /i "%1" == "--enable-debug" goto :enable_debug
if /i "%1" == "--enable-gui-mod" goto :enable_gui_mod
if /i "%1" == "--help" goto :help
if /i "%1" == "-h" goto :help
goto :help
:continue
shift
goto :parse_loop


:help
  echo Usage: %0 [OPTION]... [VAR=VALUE]...
  echo;
  echo Configuration:
  echo   -h, --help          display this help and exit
  echo   --enable-debug      compile with debugging information
  echo   --enable-gui-mod    compile and link with QtGui module
  echo;
  echo Installation directories:
  echo   --prefix=PREFIX     install files in PREFIX [%TFDIR%]
  goto :exit

:prefix
  shift
  if "%1" == "" goto :help
  set TFDIR=%1
  goto :continue

:enable_debug
  set DEBUG=yes
  goto :continue

:enable_gui_mod
  set USE_GUI=use_gui=1
  goto :continue

:start
if "%DEBUG%" == "yes" (
  set OPT="CONFIG+=debug"
) else (
  set OPT="CONFIG+=release"
)

::
:: Generates tfenv.bat
::
for %%I in (qmake.exe)  do if exist %%~$path:I set QMAKE=%%~$path:I
for %%I in (cmake.exe)  do if exist %%~$path:I set CMAKE=%%~$path:I
for %%I in (cl.exe)     do if exist %%~$path:I set MSCOMPILER=%%~$path:I
for %%I in (devenv.exe) do if exist %%~$path:I set DEVENV=%%~$path:I

if "%QMAKE%" == "" (
  echo Qt environment not found
  exit /b
)
if "%CMAKE%" == "" (
  echo CMake not found
  exit /b
)
if "%MSCOMPILER%" == "" if "%DEVENV%"  == "" (
  echo MSVC Compiler not found
  exit /b
)

:: get qt install prefix
for /f usebackq %%I in (`qtpaths.exe --install-prefix`) do (
  set QT_INSTALL_PREFIX=%%I
  goto :break
)
:break

:: vcvarsall.bat setup
set MAKE=nmake
if /i "%Platform%" == "x64" (
  set VCVARSOPT=amd64
  set BUILDTARGET=x64
  set ENVSTR=Environment to build for 64-bit executable  MSVC / Qt
) else (
  set VCVARSOPT=x86
  set BUILDTARGET=win32
  set ENVSTR=Environment to build for 32-bit executable  MSVC / Qt
)

echo %QT_INSTALL_PREFIX% | find "msvc2015" >NUL
if not ERRORLEVEL 1 (
  if /i "%Platform%" == "x64" (
    set CMAKEOPT=Visual Studio 14 2015 Win64
  ) else (
    set CMAKEOPT=Visual Studio 14 2015
  )
) else (
   if /i "%Platform%" == "x64" (
    set CMAKEOPT=Visual Studio 15 2017 Win64
  ) else (
    set CMAKEOPT=Visual Studio 15 2017
  )
)

SET /P X="%ENVSTR%"<NUL
qtpaths.exe --qt-version

for %%I in (qtenv2.bat) do if exist %%~$path:I set QTENV=%%~$path:I
set TFENV=tfenv.bat
echo @echo OFF> %TFENV%
echo ::>> %TFENV%
echo :: This file is generated by configure.bat>> %TFENV%
echo ::>> %TFENV%
echo;>> %TFENV%
echo set TFDIR=%TFDIR%>> %TFENV%
echo set TreeFrog_DIR=%TFDIR%>> %TFENV%
echo set QTENV="%QTENV%">> %TFENV%
echo set QMAKESPEC=%QMAKESPEC%>> %TFENV%
echo if exist %%QTENV%% ( call %%QTENV%% )>> %TFENV%
if not "%VCVARSOPT%" == "" (
  echo if not "%%VS140COMNTOOLS%%" == "" ^(>> %TFENV%
  echo   set VCVARSBAT="%%VS140COMNTOOLS%%..\..\VC\vcvarsall.bat">> %TFENV%
  echo ^) else if not "%%VS120COMNTOOLS%%" == "" ^(>> %TFENV%
  echo   set VCVARSBAT="%%VS120COMNTOOLS%%..\..\VC\vcvarsall.bat">> %TFENV%
  echo ^) else ^(>> %TFENV%
  echo   set VCVARSBAT="">> %TFENV%
  echo ^)>> %TFENV%
  echo if exist %%VCVARSBAT%% ^(>> %TFENV%
  echo   echo Setting up environment for MSVC usage...>> %TFENV%
  echo   call %%VCVARSBAT%% %VCVARSOPT%>> %TFENV%
  echo ^)>> %TFENV%
)
echo set PATH=%%TFDIR^%%\bin;%%PATH%%>> %TFENV%
echo echo Setup a TreeFrog/Qt environment.>> %TFENV%
echo echo -- TFDIR set to %%TFDIR%%>> %TFENV%
echo cd /D %%HOMEDRIVE%%%%HOMEPATH%%>> %TFENV%

set TFDIR=%TFDIR:\=/%
del /f /q .qmake.stash >nul 2>&1

:: Builds MongoDB driver
cd /d %BASEDIR%3rdparty
rd /s /q  mongo-driver >nul 2>&1
del /f /q mongo-driver >nul 2>&1
mklink /j mongo-driver mongo-c-driver-%MONBOC_VERSION% >nul 2>&1

cd %BASEDIR%3rdparty\mongo-driver\src\libbson
del /f /q CMakeCache.txt cmake_install.cmake CMakeFiles Makefile >nul 2>&1
cmake -G"%CMAKEOPT%" -DCMAKE_CONFIGURATION_TYPES=Release -DENABLE_STATIC=ON -DENABLE_TESTS=OFF .
echo Compiling BSON library ...
devenv libbson.sln /project bson_static /rebuild Release >nul 2>&1
if ERRORLEVEL 1 (
  :: Shows error
  devenv libbson.sln /project bson_static /build Release
  echo;
  echo Build failed.
  echo MongoDB driver not available.
  exit /b
)

cd %BASEDIR%3rdparty\mongo-driver
del /f /q CMakeCache.txt cmake_install.cmake CMakeFiles Makefile >nul 2>&1
echo cmake -G"%CMAKEOPT%" -DCMAKE_CONFIGURATION_TYPES=Release -DENABLE_STATIC=ON -DENABLE_SSL=OFF -DENABLE_SNAPPY=OFF -DENABLE_SRV=OFF -DENABLE_SASL=OFF -DENABLE_ZLIB=OFF -DENABLE_TESTS=OFF .
cmake -G"%CMAKEOPT%" -DCMAKE_CONFIGURATION_TYPES=Release -DENABLE_STATIC=ON -DENABLE_SSL=OFF -DENABLE_SNAPPY=OFF -DENABLE_SRV=OFF -DENABLE_SASL=OFF -DENABLE_ZLIB=OFF -DENABLE_TESTS=OFF .
echo Compiling MongoDB driver library ...
devenv libmongoc.sln /project mongoc_static /rebuild Release >nul 2>&1
if ERRORLEVEL 1 (
  :: Shows error
  devenv libmongoc.sln /project mongoc_static /build Release
  echo;
  echo Build failed.
  echo MongoDB driver not available.
  exit /b
)

:: Builds LZ4
cd %BASEDIR%3rdparty
echo Compiling LZ4 library ...
rd /s /q  lz4 >nul 2>&1
del /f /q lz4 >nul 2>&1
mklink /j lz4 lz4-%LZ4_VERSION% >nul 2>&1
for /F %%i in ('qtpaths.exe --install-prefix') do echo %%i | find "msvc2015" >NUL
if not ERRORLEVEL 1 (
  set VS=VS2015
) else (
  set VS=VS2017
)
devenv lz4\visual\%VS%\lz4.sln /project liblz4 /rebuild "Release|%BUILDTARGET%" >nul 2>&1
if ERRORLEVEL 1 (
  :: Shows error
  devenv lz4\visual\%VS%\lz4.sln /project liblz4 /build "Release|%BUILDTARGET%"
  echo;
  echo Build failed.
  echo LZ4 not available.
  exit /b
)

cd %BASEDIR%src
if exist Makefile ( %MAKE% -k distclean >nul 2>&1 )
qmake %OPT% target.path='%TFDIR%/bin' header.path='%TFDIR%/include' %USE_GUI%

cd %BASEDIR%tools
if exist Makefile ( %MAKE% -k distclean >nul 2>&1 )
qmake -recursive %OPT% target.path='%TFDIR%/bin' header.path='%TFDIR%/include' datadir='%TFDIR%'
%MAKE% qmake

echo;
echo First, run "%MAKE% install" in src directory.
echo Next, run "%MAKE% install" in tools directory.

:exit
exit /b
