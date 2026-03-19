# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for A-Z+T
# Usage: pyinstaller azt.spec --clean
#
# NOTE: ASR/ML features (torch, whisper, transformers) are excluded from the
# binary to keep size manageable. Install them separately with pip if needed.

import sys as _sys
from PyInstaller.utils.hooks import collect_all

(librosa_datas, librosa_binaries, librosa_hiddenimports) = collect_all('librosa')
(langcodes_datas, langcodes_binaries, langcodes_hiddenimports) = collect_all('langcodes')

block_cipher = None

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=librosa_binaries + langcodes_binaries,
    datas=[
        ('SILCAWL', 'SILCAWL'),
        ('images', 'images'),
        ('translations', 'translations'),
        ('xlpstylesheets', 'xlpstylesheets'),
        ('xlptransforms', 'xlptransforms'),
        ('langtags.json', '.'),
    ] + librosa_datas + langcodes_datas,
    hiddenimports=[
        'pkg_resources',
        'pyaudio',
        'soundfile',
        'lxml',
        'lxml.etree',
        'lxml._elementpath',
        'PIL',
        'PIL.Image',
        'PIL.ImageTk',
        'svglib.svglib',
        'reportlab',
        'reportlab.graphics.renderPDF',
        'reportlab.graphics.renderSVG',
        'patiencediff',
        'psutil',
        'packaging',
        'packaging.version',
        'numpy',
        'scipy',
        'scipy.signal',
        'tkinter',
        'tkinter.ttk',
        'tkinter.filedialog',
        'tkinter.messagebox',
        'configparser',
        'urllib3',
    ] + librosa_hiddenimports + langcodes_hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'torch', 'torchvision', 'torchaudio',
        'transformers',
        'whisper',
        'openai',
        'huggingface_hub',
        'tensorflow',
        'pyautogui',   # GUI automation; problematic on headless builds
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='azt',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,  # replace with path to .icns (macOS) or .ico (Windows) when available
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='azt',
)

# macOS .app bundle — PyInstaller ignores this on non-macOS platforms
if _sys.platform == 'darwin':
    app = BUNDLE(
        coll,
        name='A-Z+T.app',
        icon=None,  # replace with path to .icns when available
        bundle_identifier='org.sil.azt',
        version='1.0.5',
        info_plist={
            'NSHighResolutionCapable': True,
            'NSMicrophoneUsageDescription': (
                'A-Z+T requires microphone access for audio recording.'
            ),
            'CFBundleDisplayName': 'A-Z+T',
            'CFBundleName': 'A-Z+T',
            'CFBundleShortVersionString': '1.0.5',
            'CFBundleVersion': '1.0.5',
            'NSPrincipalClass': 'NSApplication',
            'NSAppleScriptEnabled': False,
        },
    )
