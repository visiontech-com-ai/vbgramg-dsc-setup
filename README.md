# VBGRAMG DSC Setup — NREGA & VBGRAMG Java + Firefox Digital Signature Tool 

One-click setup tool that installs **Java 8 (32-bit)** and **Firefox 43.0.1 (32-bit)** with auto-update permanently disabled — for NREGA, VBGRAMG, and other Indian government digital signature portals.

**Made by [Vision Technologies and Robotics](mailto:subho@visiontech.com.in)**

---

## Why This Tool?

Indian government portals like **NREGA** (nrega.nic.in) and **VBGRAMG** use Java applets for digital signatures. Modern browsers have dropped Java plugin support. This tool installs the exact versions of Java and Firefox that work, and ensures Firefox never auto-updates to an incompatible version.

## What Gets Installed

| Software | Version | Source |
|----------|---------|--------|
| Firefox | 43.0.1 (32-bit) | [Mozilla Official Archive](https://ftp.mozilla.org/pub/firefox/releases/43.0.1/win32/en-US/) |
| Java 8 JRE | Oracle Java 8 (32-bit) | [Oracle java.com](https://www.java.com/en/download/manual.jsp) |

> **Why Oracle Java and not a free open-source build?** NREGA/VBGRAMG use a Java **browser applet** for signing, which needs the Java browser plugin (`npjp2.dll`). Only Oracle's Java 8 ships this plugin — open-source builds (Azul Zulu, Temurin, Corretto) include the Java engine but omit the browser plugin, so applets will not load. The tool downloads the 32-bit Oracle JRE directly from Oracle's official java.com server (no login needed) and installs it with the plugin enabled.

## How to Use

1. **Download** `setup.bat` from the [latest release](https://github.com/visiontech-com-ai/vbgramg-dsc-setup/releases/latest/download/setup.bat) (single file, no ZIP)
2. **Double-click** `setup.bat`
3. **Click "Yes"** on the Windows permission prompt
4. **Wait** for the setup to complete (2-5 minutes) — it downloads everything it needs
5. **Open Firefox 43** from the desktop shortcut and navigate to your portal

That's it. No command line, no technical knowledge needed.

## What the Setup Does

### Firefox 43.0.1
- Downloads and installs Firefox 43.0.1 (32-bit) silently
- **Disables auto-update through 5 independent layers:**
  1. Locks all update preferences via `mozilla.cfg` autoconfig
  2. Prevents the Mozilla Maintenance Service from running
  3. Disables the `updater.exe` executable
  4. Blocks Firefox update servers in the Windows hosts file
  5. Removes Mozilla scheduled update tasks

### Java 8 (Oracle JRE, 32-bit)
- Downloads the current Oracle Java 8 (32-bit) offline installer directly from Oracle's official java.com server
- Installs it silently **with the browser applet plugin enabled** (`WEB_JAVA=1`) so the signing applet loads in Firefox
- Configures Java security: sets security level to HIGH with relaxed checks for government portals
- Deploys the exception site list (edit `exception.sites` to add your portal URLs)
- Disables Java auto-update via registry and scheduled tasks

## Editing the Exception Site List

Before running the setup, open `exception.sites` with Notepad and add your portal URLs (one per line):

```
https://nrega.nic.in
http://nrega.nic.in
https://nregasp2.nic.in
http://nregasp2.nic.in
https://your-portal-url-here.nic.in
```

If you edit the file after running setup, just double-click `setup.bat` again to apply changes.

## System Requirements

- **OS:** Windows 10 or Windows 11
- **Internet:** Required for first-time download (~100 MB)
- **Disk Space:** ~300 MB free
- **Other browsers:** Not affected. Use Firefox 43 only for NREGA/VBGRAMG work.

## File Structure

```
vbgramg-dsc-setup/
├── setup.bat              ← Double-click this to start
├── setup.ps1              ← Main installation script (called by setup.bat)
├── firefox-install.ini    ← Firefox silent install configuration
├── mozilla.cfg            ← Firefox update lock configuration
├── local-settings.js      ← Firefox autoconfig loader
├── exception.sites        ← Java exception site list (edit this)
├── index.html             ← Project webpage
└── README.md              ← This file
```

## Troubleshooting

**Java applet not loading:** In Firefox 43, go to `about:addons` → Plugins → Set "Java(TM) Platform" to "Always Activate".

**Digital signature popup not appearing:** Add your portal URL to `exception.sites` and re-run setup.bat.

**Windows SmartScreen warning:** Click "More info" → "Run anyway". This is normal for downloaded scripts.

**Firefox updated despite protection:** Re-run setup.bat to reinstall Firefox 43.0.1 and re-apply all update blocks.

## Keywords

nrega, nrega java, nrega digital signature, vbgramg, vbgramg java, vbgramg digital signature, nrega java setup, nrega firefox setup, java 8 for nrega, firefox 43 download, vbgramg dsc setup, nrega java firefox download, digital signature setup india

---

**Vision Technologies and Robotics** | [subho@visiontech.com.in](mailto:subho@visiontech.com.in)
