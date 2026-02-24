!include "MUI2.nsh"
!define APP_NAME "POS App"
!define APP_REGKEY "Software\POSApp"
!define APP_UNINSTALL "Software\Microsoft\Windows\CurrentVersion\Uninstall\POSApp"
!define APP_ICON "..\mobile_cashier\windows\runner\resources\app_icon.ico"
Name "${APP_NAME}"
OutFile "pos-app-setup.exe"
InstallDir "$PROGRAMFILES64\POSApp"
InstallDirRegKey HKLM "${APP_REGKEY}" "InstallDir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
!define MUI_ABORTWARNING
Icon "${APP_ICON}"
UninstallIcon "${APP_ICON}"
AutoCloseWindow true
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
SetShellVarContext all
SetRegView 64
SetOutPath "$INSTDIR"
SetOverwrite ifnewer
nsExec::ExecToLog 'taskkill /F /IM pos-app.exe /T'
Delete "$INSTDIR\pos-app.exe"
File "..\pos-app.exe"
File "${APP_ICON}"
WriteUninstaller "$INSTDIR\Uninstall.exe"
WriteRegStr HKLM "${APP_REGKEY}" "InstallDir" "$INSTDIR"
WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "POSApp" "$INSTDIR\pos-app.exe --autostart"
WriteRegStr HKLM "${APP_UNINSTALL}" "DisplayName" "${APP_NAME}"
WriteRegStr HKLM "${APP_UNINSTALL}" "InstallLocation" "$INSTDIR"
WriteRegStr HKLM "${APP_UNINSTALL}" "UninstallString" "$INSTDIR\Uninstall.exe"
WriteRegStr HKLM "${APP_UNINSTALL}" "DisplayIcon" "$INSTDIR\app_icon.ico"
WriteRegDWORD HKLM "${APP_UNINSTALL}" "NoModify" 1
WriteRegDWORD HKLM "${APP_UNINSTALL}" "NoRepair" 1
CreateDirectory "$SMPROGRAMS\${APP_NAME}"
CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\pos-app.exe" "" "$INSTDIR\app_icon.ico"
CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\pos-app.exe" "" "$INSTDIR\app_icon.ico"
CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk" "$INSTDIR\Uninstall.exe"
ExecShell "open" "$INSTDIR\pos-app.exe"
SectionEnd

Section "Uninstall"
SetShellVarContext all
SetRegView 64
Delete "$DESKTOP\${APP_NAME}.lnk"
Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
Delete "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk"
RMDir "$SMPROGRAMS\${APP_NAME}"
Delete "$INSTDIR\pos-app.exe"
Delete "$INSTDIR\app_icon.ico"
Delete "$INSTDIR\Uninstall.exe"
RMDir "$INSTDIR"
DeleteRegKey HKLM "${APP_UNINSTALL}"
DeleteRegKey HKLM "${APP_REGKEY}"
DeleteRegValue HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "POSApp"
SectionEnd
