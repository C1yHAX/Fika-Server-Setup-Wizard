# 🎮 Fika-Server-Setup-Wizard

> All-in-One setup tool for running your own FIKA multiplayer server on Single Player Tarkov (SPT).

![License](https://img.shields.io/github/license/C1yHAX/Fika-Server-Setup-Wizard)
![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)

---

## 📖 About

Instead of reading multiple guides, manually downloading files and configuring everything yourself - this tool automates the entire process.

It detects existing installations, downloads the required components and configures them automatically.

**Designed for users with no technical background.**

---

## ✨ Features

- 🔍 **Automatic detection** of all existing installations (all drives, Steam libraries, common paths)
- 🚀 **One-click full setup** via "Install All"
- 🔧 **Individual installation** of each component separately
- 🟢 **Real-time status indicator** for every component
- 📋 **Live log** with timestamps for every action
- 🌐 **Bilingual UI** - German and English

---

## 📦 Components

| # | Component | Description |
|---|-----------|-------------|
| 01 | **Steam** | Downloads and starts the official Steam installer |
| 02 | **Escape from Tarkov** | Install via BSG Launcher or Steam |
| 03 | **SPT Server** | Downloads and runs the official SPT installer |
| 04 | **Fika** | Installs Plugin + Server-Mod from official GitHub releases |
| 05 | **Headless Client** | Installs Fika.Headless plugin + FikaHeadlessManager |
| 06 | **Docker + WSL2** | Enables WSL2, installs kernel update and Docker Desktop |
| 07 | **Firewall** | Opens all required ports automatically |
| 08 | **FikaWebApp** | Pulls and starts the lacyway/fikawebapp Docker container |

---

## 🔌 Firewall Ports

| Port | Protocol | Usage |
|------|----------|-------|
| 6969 | TCP + UDP | SPT Server |
| 25565 | UDP | Fika Peer-to-Peer |
| 8080 | TCP | FikaWebApp |
| 5000 | TCP | Container internal |

---

## 💻 Requirements

- Windows 10 or Windows 11 (64-bit)
- Administrator rights
- Internet connection

---

## 🔒 Downloads — Official Sources Only

All files are downloaded exclusively from official sources:

| Component | Source |
|-----------|--------|
| Steam | `cdn.akamai.steamstatic.com` |
| BSG Launcher | `launcher.escapefromtarkov.com` |
| SPT | `ligma.waffle-lord.net` |
| Fika | `github.com/project-fika` |
| Docker | `desktop.docker.com` |
| WSL2 | `wslstorestorage.blob.core.windows.net` |

---

## 🚀 How to Use

1. Download the latest release from the Releases page
3. Accept the UAC prompt (Administrator rights required)
4. Select your language (German / English)
5. Click **"Install All"** or install each component individually

---

## 📸 Screenshots

![Preview](screenshots/preview.png)

---

## ⚠️ Disclaimer

This is an **unofficial community tool** and has no affiliation with:
- Battlestate Games
- The SPT Project
- The FIKA Project

Use at your own risk.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

---

<div align="center">
Made with ❤️ by C1yHAX
</div>
