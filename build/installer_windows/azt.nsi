; NSIS installer script for A-Z+T (Windows x86_64)
; Run makensis from the repository root:
;   makensis build\installer_windows\azt.nsi
;
; Prerequisites in the build environment:
;   - PyInstaller output at dist\azt\
;   - Charis SIL TTFs at build\installer_windows\fonts\

!define APP_NAME    "A-Z+T"
!define APP_VERSION "1.0.5"
!define PUBLISHER   "SIL International"
!define APP_EXE     "azt.exe"
!define BUNDLE_ID   "org.sil.azt"
!define UNINST_KEY  "Software\Microsoft\Windows\CurrentVersion\Uninstall\AZT"

SetCompressor /SOLID lzma
Name "${APP_NAME} ${APP_VERSION}"
OutFile "AZT-${APP_VERSION}-windows-x86_64.exe"
InstallDir "$PROGRAMFILES64\A-Z+T"
InstallDirRegKey HKLM "Software\AZT" "InstallDir"
RequestExecutionLevel admin
ShowInstDetails show

!include "MUI2.nsh"
!include "WinMessages.nsh"

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch A-Z+T now"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ---------------------------------------------------------------------------
Section "A-Z+T (required)" SecMain
    SectionIn RO

    ; Install application files
    SetOutPath "$INSTDIR"
    File /r "dist\azt\*.*"

    ; Install Charis SIL fonts system-wide
    SetOutPath "$FONTS"
    File "build\installer_windows\fonts\CharisSIL-Regular.ttf"
    File "build\installer_windows\fonts\CharisSIL-Bold.ttf"
    File "build\installer_windows\fonts\CharisSIL-Italic.ttf"
    File "build\installer_windows\fonts\CharisSIL-BoldItalic.ttf"

    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" \
        "Charis SIL Regular (TrueType)" "CharisSIL-Regular.ttf"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" \
        "Charis SIL Bold (TrueType)" "CharisSIL-Bold.ttf"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" \
        "Charis SIL Italic (TrueType)" "CharisSIL-Italic.ttf"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" \
        "Charis SIL Bold Italic (TrueType)" "CharisSIL-BoldItalic.ttf"

    ; Notify running applications of font change
    SendMessage ${HWND_BROADCAST} ${WM_FONTCHANGE} 0 0 /TIMEOUT=5000

    ; Create shortcuts
    CreateDirectory "$SMPROGRAMS\A-Z+T"
    CreateShortCut "$SMPROGRAMS\A-Z+T\A-Z+T.lnk"   "$INSTDIR\${APP_EXE}"
    CreateShortCut "$SMPROGRAMS\A-Z+T\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
    CreateShortCut "$DESKTOP\A-Z+T.lnk" "$INSTDIR\${APP_EXE}"

    ; Store install location and write uninstaller
    WriteRegStr HKLM "Software\AZT" "InstallDir" "$INSTDIR"
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Add to Windows Programs & Features
    WriteRegStr HKLM "${UNINST_KEY}" "DisplayName"      "${APP_NAME}"
    WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion"   "${APP_VERSION}"
    WriteRegStr HKLM "${UNINST_KEY}" "Publisher"        "${PUBLISHER}"
    WriteRegStr HKLM "${UNINST_KEY}" "UninstallString"  "$INSTDIR\Uninstall.exe"
    WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation"  "$INSTDIR"
    WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
    WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1

SectionEnd

; ---------------------------------------------------------------------------
Section "Uninstall"
    RMDir /r "$INSTDIR"
    Delete "$DESKTOP\A-Z+T.lnk"
    RMDir /r "$SMPROGRAMS\A-Z+T"
    DeleteRegKey HKLM "${UNINST_KEY}"
    DeleteRegKey HKLM "Software\AZT"
    ; Fonts are intentionally left installed
SectionEnd
