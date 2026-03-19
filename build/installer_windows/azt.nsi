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
!include "Sections.nsh"

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch A-Z+T now"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
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
; Optional: ASR / Speech Recognition features
; Downloads PyTorch + Whisper (~4 GB) from PyPI into an isolated venv.
; Unchecked by default. Requires internet connection.
; Venv is created at %ProgramData%\AZT\asr-env\
; A-Z+T's asr.py looks for %ProgramData%\AZT\asr-env-path.txt to find it.
;
Section /o "ASR Speech Recognition Features (~4 GB download)" SecASR

    DetailPrint "Searching for Python 3..."
    ; Try common install locations for Python 3.12, 3.11, 3.10
    StrCpy $0 ""
    ${If} ${FileExists} "$PROGRAMFILES64\Python312\python.exe"
        StrCpy $0 "$PROGRAMFILES64\Python312\python.exe"
    ${ElseIf} ${FileExists} "$PROGRAMFILES64\Python311\python.exe"
        StrCpy $0 "$PROGRAMFILES64\Python311\python.exe"
    ${ElseIf} ${FileExists} "$PROGRAMFILES64\Python310\python.exe"
        StrCpy $0 "$PROGRAMFILES64\Python310\python.exe"
    ${Else}
        ; Fall back to whatever "python" resolves to on PATH
        nsExec::ExecToStack 'where python'
        Pop $1   ; exit code
        Pop $0   ; stdout (first match)
        ${If} $1 != 0
            MessageBox MB_OK|MB_ICONEXCLAMATION \
                "Python 3 was not found.$\n$\nPlease install Python 3 from https://www.python.org/ and re-run this installer, or install the ASR features manually:$\n  pip install torch openai-whisper transformers huggingface_hub[hf_xet]"
            Goto done_asr
        ${EndIf}
    ${EndIf}

    DetailPrint "Using Python: $0"
    StrCpy $R0 "$COMMONPROGRAMDATA\AZT\asr-env"

    DetailPrint "Creating venv at: $R0"
    nsExec::ExecToLog '"$0" -m venv "$R0"'

    DetailPrint "Upgrading pip..."
    nsExec::ExecToLog '"$R0\Scripts\pip.exe" install --upgrade pip'

    DetailPrint "Installing PyTorch, Whisper, Transformers (~4 GB from PyPI)..."
    DetailPrint "This may take several minutes."
    nsExec::ExecToLog '"$R0\Scripts\pip.exe" install torch openai-whisper transformers "huggingface_hub[hf_xet]"'
    Pop $1
    ${If} $1 != 0
        MessageBox MB_OK|MB_ICONEXCLAMATION "ASR package installation encountered an error (code $1).$\nCheck your internet connection and try running the installer again."
        Goto done_asr
    ${EndIf}

    ; Write marker file so A-Z+T can find the venv
    FileOpen $2 "$COMMONPROGRAMDATA\AZT\asr-env-path.txt" w
    FileWrite $2 "$R0"
    FileClose $2

    DetailPrint "ASR features installed successfully."
    done_asr:

SectionEnd

; Section descriptions shown in the component selection page
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} "A-Z+T application and Charis SIL font. Required."
    !insertmacro MUI_DESCRIPTION_TEXT ${SecASR} "Downloads and installs PyTorch and OpenAI Whisper (~4 GB) for speech recognition. Requires internet. Can be installed later by re-running this installer."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ---------------------------------------------------------------------------
Section "Uninstall"
    RMDir /r "$INSTDIR"
    Delete "$DESKTOP\A-Z+T.lnk"
    RMDir /r "$SMPROGRAMS\A-Z+T"
    DeleteRegKey HKLM "${UNINST_KEY}"
    DeleteRegKey HKLM "Software\AZT"
    ; Fonts are intentionally left installed
SectionEnd
