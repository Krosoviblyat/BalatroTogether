@echo off
setlocal
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo .NET Framework C# compiler was not found.
  exit /b 1
)
"%CSC%" /nologo /target:winexe /platform:x64 /optimize+ /codepage:65001 /out:"%~dp0..\Install Balatro Together.exe" /win32manifest:"%~dp0app.manifest" /resource:"%~dp0..\Manual Install.zip",payload.zip /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /reference:System.Web.Extensions.dll /reference:Microsoft.CSharp.dll "%~dp0Installer.cs" "%~dp0SelfTests.cs" "%~dp0Build.cs"
exit /b %errorlevel%
