' Starts the WPF toolkit launcher without a background console window.
' This file does not handle or store credentials.
Option Explicit
Dim shell, fso, folder, launcher, psExe, command
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
folder = fso.GetParentFolderName(WScript.ScriptFullName)
launcher = fso.BuildPath(folder, "ITToolkit-Launcher.ps1")
If Not fso.FileExists(launcher) Then
    MsgBox "Missing ITToolkit-Launcher.ps1 in " & folder, vbCritical, "IT Toolkit Launcher"
    WScript.Quit 1
End If
psExe = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
command = """" & psExe & """ -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & launcher & """"
shell.Run command, 0, False
