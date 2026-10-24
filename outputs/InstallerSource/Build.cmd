@echo off
setlocal
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo .NET Framework C# compiler was not found.
  exit /b 1
)
"%CSC%" /nologo /target:exe /reference:System.Drawing.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /out:"%~dp0..\BrandIconBuilder.exe" "%~dp0BrandIcon.cs"
if errorlevel 1 exit /b %errorlevel%
"%~dp0..\BrandIconBuilder.exe" "%~dp0AppIcon.jpg" "%~dp0Together.ico" "%~dp0..\SetupSource.zip"
if errorlevel 1 exit /b %errorlevel%
"%CSC%" /nologo /target:winexe /platform:x64 /optimize+ /codepage:65001 /out:"%~dp0..\Install Balatro Together.exe" /win32icon:"%~dp0Together.ico" /win32manifest:"%~dp0app.manifest" /resource:"%~dp0..\Manual Install.zip",payload.zip /resource:"%~dp0..\SetupSource.zip",setup-source.zip /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /reference:System.Security.dll /reference:System.Web.Extensions.dll /reference:Microsoft.CSharp.dll "%~dp0Installer.cs" "%~dp0SelfTests.cs" "%~dp0Updater.cs" "%~dp0UpdaterTests.cs" "%~dp0UpdateKey.cs" "%~dp0StudioUI.cs" "%~dp0UIShowcase.cs" "%~dp0Build.cs" "%~dp0SetupUpdates.cs" "%~dp0SetupFlowTests.cs" "%~dp0PublicUpdateTests.cs"
exit /b %errorlevel%
