# Rebuild

From the repository root, install Python 3.11+ and lupa 2.8, then run:

```
python outputs/BalatroTogether/tools/test.py
python outputs/BalatroTogether/tools/build.py
```

The optional Cryptid/Amulet integration checks require the pinned Amulet source under work/upstream-Amulet. No game files or private native harness are included. The mod builder emits a mod-only ZIP under outputs. Players should use the matching full installer release instead.

The separate Windows installer source rebuilds against the exact matching Manual Install.zip included in an Easy Installer release; see ../InstallerSource/README.md. Keep dependency source archives and license notices with distributions.
