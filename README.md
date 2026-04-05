<div align="center">

# 🦀 Claw Code Mobile

### 🚀 Claude Code on Your Phone — Full Linux, No Server, No PC 🚀

[![Android](https://img.shields.io/badge/Android-7.0+-3DDC84?logo=android&logoColor=white&style=for-the-badge)](https://developer.android.com)
[![Claw Code](https://img.shields.io/badge/Claw_Code-48K+_★-FF6B35?logo=github&logoColor=white&style=for-the-badge)](https://github.com/instructkr/claw-code)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.1-7F52FF?logo=kotlin&logoColor=white&style=for-the-badge)](https://kotlinlang.org)
[![Python](https://img.shields.io/badge/Python-3.x-3776AB?logo=python&logoColor=white&style=for-the-badge)](https://python.org)
[![Rust](https://img.shields.io/badge/Rust-Core-DEA584?logo=rust&logoColor=white&style=for-the-badge)](https://www.rust-lang.org)
[![Status](https://img.shields.io/badge/Status-🔥%20IT%20WORKS-brightgreen?style=for-the-badge)](https://friuns2.github.io/claw-code-android/)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

<br />

> **They said you can't run Claude Code on a phone.**
> **They said you need a Mac, a server, SSH, a terminal.**
> **We put an entire Linux distro inside an APK and proved them wrong.**

<br />

```
 ██████╗██╗      █████╗ ██╗    ██╗     ██████╗ ██████╗ ██████╗ ███████╗
██╔════╝██║     ██╔══██╗██║    ██║    ██╔════╝██╔═══██╗██╔══██╗██╔════╝
██║     ██║     ███████║██║ █╗ ██║    ██║     ██║   ██║██║  ██║█████╗
██║     ██║     ██╔══██║██║███╗██║    ██║     ██║   ██║██║  ██║██╔══╝
╚██████╗███████╗██║  ██║╚███╔███╔╝    ╚██████╗╚██████╔╝██████╔╝███████╗
 ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝     ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
              M O B I L E  ·  O N  ·  Y O U R  ·  P H O N E
```

</div>

[Download APK](https://friuns2.github.io/claw-code-android/) ·
[Claw Code Website](https://claw-code.codes) ·
[Google Play](https://play.google.com/store/apps/details?id=gptos.intelligence.assistant&hl=en) ·
[Project Spec](PROJECT_SPEC.md)

---

## 🤯 What Is This?

People run Claude Code on MacBooks. On cloud servers. On expensive Linux workstations with 64GB RAM.

**We run it on a phone.**

This project takes the [Claw Code](https://github.com/instructkr/claw-code) agent framework — the open-source clean-room rewrite of Claude Code's architecture with **48K+ stars** — and packages it into a single Android APK with a complete embedded Linux environment. No root. No Termux. No server. No SSH tunnels. No second device.

**You pull your phone out of your pocket, open the app, and start coding with an AI agent.** That's it. That's the product.

> 🧠 **TL;DR** — Full Claw Code + AI coding agent running natively on Android in an embedded Linux environment extracted from the APK. One app. Zero dependencies. Your pocket is now a dev workstation.

---

## 📱 Screenshots

<div align="center">
<table>
<tr>
<td align="center" width="50%">
<img src="https://raw.githubusercontent.com/friuns2/claw-code-android/main/screenshots/screenshot.png" width="300" />
<br /><b>💬 AI Coding Agent</b><br />
<sub>Full conversational coding with streaming responses, reasoning visibility, and <code>danger-full-access</code> mode.</sub>
</td>
<td align="center" width="50%">
<img src="https://raw.githubusercontent.com/friuns2/claw-code-android/main/screenshots/screenshot2.png" width="300" />
<br /><b>🧩 Dashboard & Sessions</b><br />
<sub>Multi-thread sessions, agent routing, skills, Canvas — all running locally on your phone.</sub>
</td>
</tr>
</table>

> **Yes, that's a full AI coding agent. Yes, it's running on a phone. Yes, it writes and executes code.**

</div>

---

## 🌍 What Can You Do With This?

| | Feature | Description |
|---|---|---|
| 🦀 | **Claw Code Agent** | Full Claude Code architecture agent — reads codebase, writes code, runs commands autonomously |
| 🐧 | **Embedded Linux** | Complete Linux userland extracted from APK — sh, apt, Node.js, Python, SSL certs |
| ⚡ | **Rust Core** | Native Rust binary (aarch64-musl) — 73MB of raw performance running on ARM64 |
| 💬 | **Conversational Coding** | Streaming responses with reasoning visibility and multi-thread sessions |
| 🔓 | **Full Auto-Approval** | No permission popups — `danger-full-access` sandbox mode by default |
| 🔋 | **Background Execution** | Foreground service keeps everything alive when you switch apps |
| 🔑 | **OAuth Login** | One-time browser-based auth — shared across all agent sessions |
| 📴 | **Offline Bootstrap** | Linux environment extracted from APK — works without internet after setup |
| 🛠️ | **19 Built-in Tools** | File I/O, shell execution, Git operations, web scraping, notebook editing |
| 🧠 | **Query Engine** | LLM API calls, response streaming, caching, multi-step orchestration |
| 🔌 | **MCP Support** | Model Context Protocol with 6 transport types — connect external tool servers |
| 🏗️ | **Multi-Agent** | Spawn sub-agents to parallelize complex tasks in isolated contexts |

---

## ⚡ Quick Start

```bash
# 🔓 Just download and install
adb install -r claw-code-mobile.apk
adb shell am start -n com.codex.mobile/.MainActivity
# ✈️ and you're flying
```

Or [download the APK](https://friuns2.github.io/claw-code-android/) directly. Open it. Login. Code.

### 🔧 Build from Source

```bash
git clone https://github.com/friuns2/claw-code-android.git
cd claw-code-android

npm install && npm run build

cd android && bash scripts/download-bootstrap.sh
bash scripts/build-server-bundle.sh && ./gradlew assembleDebug

adb install -r app/build/outputs/apk/debug/app-debug.apk
```

---

## 📁 Project Structure

```
🦀 claw-code-android/
├── 📱 android/
│   ├── app/src/main/
│   │   ├── AndroidManifest.xml
│   │   ├── 📦 assets/
│   │   │   ├── proxy.js                 # 🔌 CONNECT proxy (DNS/TLS bridge)
│   │   │   ├── bionic-compat.js         # 🤖 Android platform shim
│   │   │   └── server-bundle/           # 🌐 Pre-built Vue + Express + deps
│   │   └── java/com/codex/mobile/
│   │       ├── BootstrapInstaller.kt    # 🐧 Linux environment setup
│   │       ├── CodexForegroundService.kt # 🔋 Background persistence
│   │       ├── CodexServerManager.kt    # 🔧 Install, auth, proxy, server
│   │       └── MainActivity.kt         # 📱 WebView + setup orchestration
│   └── 🛠️ scripts/
│       ├── download-bootstrap.sh        # 📥 Fetch Termux bootstrap
│       └── build-server-bundle.sh       # 📦 Bundle frontend into APK assets
├── 🦀 rust/                             # Rust performance core (6 crates)
├── 🐍 src/                              # Python agent workspace
│   ├── commands.py                      # ⌘ 15 slash commands
│   ├── tools.py                         # 🔧 19 built-in tools
│   ├── query_engine.py                  # 🧠 Core query engine
│   ├── models.py                        # 🔮 LLM provider abstraction
│   └── main.py                          # 🚀 Entry point
├── 🌐 docs/                             # GitHub Pages website
└── 📖 README.md                         # You are here
```

---

## 🏗️ Architecture

> **Four layers. One APK. Your phone is a Linux workstation now.**

```
┌──────────────────────────────────────────────────────────┐
│                      Android APK                          │
│                                                           │
│  ┌────────────┐  ┌──────────────────────────────────────┐ │
│  │  WebView   │  │  APK Assets                          │ │
│  │  (Vue.js)  │  │  bootstrap-aarch64.zip               │ │
│  └─────┬──────┘  │  server-bundle/ (Vue + Express)      │ │
│        │         │  proxy.js / bionic-compat.js          │ │
│        │         └──────────────────────────────────────┘ │
│  ┌─────▼────────────────────────────────────────────────┐ │
│  │             CodexServerManager                        │ │
│  │  Bootstrap → Node.js → Claw Code Agent → Auth         │ │
│  │  Proxy → Query Engine → Tool System → Web Server      │ │
│  └─────┬────────────────────────────────────────────────┘ │
│        │                                                  │
│  ┌─────▼────────────────────────────────────────────────┐ │
│  │             Embedded Linux ($PREFIX)                   │ │
│  │                                                       │ │
│  │  claw-code agent → :18923 (HTTP, WebView target)      │ │
│  │    └─ Rust core  (native aarch64-musl, JSON-RPC)      │ │
│  │                                                       │ │
│  │  gateway         → :18789 (WebSocket)                 │ │
│  │  control UI      → :19001 (static file server)        │ │
│  │                                                       │ │
│  │  proxy.js        → :18924 (CONNECT proxy, DNS/TLS)    │ │
│  └───────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

### 🔌 Services

| Port | Service | Purpose |
|------|---------|---------|
| 🔗 18789 | Gateway | WebSocket control plane for agents, sessions, tools |
| 🌐 18923 | Web Server | HTTP server with Vue.js UI (WebView target) |
| 🔌 18924 | CONNECT Proxy | DNS/TLS bridge for musl-linked Rust binary |
| 📊 19001 | Control UI | Static file server for agent dashboard |

---

## 🔥 How It Works

> **They shipped an entire operating system inside an Android app. Absolute madlads.**

### 🐧 Embedded Linux

The APK bundles Termux's `bootstrap-aarch64.zip` — a minimal Linux userland with `sh`, `apt-get`, `dpkg-deb`, SSL certificates, and core libraries. On first launch, it's extracted to the app's private storage. **No root required.**

### 🦀 Native Rust Binary

The Claw Code framework ships a 73MB native Rust binary compiled for `aarch64-unknown-linux-musl`. npm refuses to install it on Android, so we download the tarball directly from the npm registry and extract it manually. **Because we don't take "no" for an answer.**

### 🔌 DNS/TLS Proxy

The musl-linked binary reads `/etc/resolv.conf` for DNS — which doesn't exist on Android. A Node.js CONNECT proxy on port 18924 bridges this gap: Node.js uses Android's Bionic DNS resolver, and the native binary routes all HTTPS through `HTTPS_PROXY`.

### 🤖 Android Compatibility Layer

The `bionic-compat.js` shim patches `process.platform` to return `"linux"`, fixes `os.cpus()` and `os.networkInterfaces()` for Android's non-standard formats. **Android thinks it's running Linux. We don't correct it.**

### 🔓 W^X Bypass

Android 10+ enforces SELinux W^X (Write XOR Execute) policies. We use `targetSdk = 28` to bypass this — same approach as Termux (F-Droid). Security researchers love this one.

---

## 🚀 Startup Sequence

1. 🔋 Battery optimization exemption + foreground service
2. 🐧 Bootstrap extraction (Termux userland)
3. 📦 Node.js + Python installation
4. 🔧 Build tools (clang, cmake, make, lld)
5. 🦀 Claw Code agent + native Rust binary installation
6. ⚙️ Full-access config (`approval_policy = "never"`)
7. 🔌 CONNECT proxy startup
8. 🔑 OAuth login via browser
9. 🏗️ Gateway + Control UI + Web Server
10. 📱 WebView loads `http://127.0.0.1:18923/`

---

## 🎯 Requirements

- 📱 **Android 7.0+** (API 24) — ARM64 device
- 🌐 **Internet connection** — for first-run setup + API calls
- 🔑 **API key** — for your chosen LLM provider
- 💾 **~500MB storage** — for Linux environment + Node.js + Rust core + agent framework

---

## 🧬 Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| 🦀 Agent Framework | Claw Code (Python + Rust) | latest |
| 🧠 Rust Core | 6-crate workspace, 16 runtime modules | — |
| 🔧 Tool System | 19 built-in, permission-gated tools | — |
| ⌘ Commands | 15 slash commands | — |
| 🔮 LLM Support | Provider-agnostic (Claude, OpenAI, local) | — |
| 🌐 Runtime | Node.js (Termux) | 24.x |
| 🖥️ Frontend | Vue.js 3 + Vite + TailwindCSS | 3.x |
| 📱 Android | Kotlin + WebView | 2.1.0 |
| 🐧 Linux | Termux bootstrap (aarch64) | — |

---

## 🆚 Claw Code Mobile vs. Desktop

| Aspect | Desktop (Mac/Linux/Server) | Mobile (This App) |
|--------|---------------------------|-------------------|
| 🖥️ Platform | macOS, Linux, WSL | Android 7.0+ (ARM64) |
| 📦 Installation | `pip install` + terminal | Download APK → open → done |
| 🔧 Dependencies | Python, Rust, terminal emulator | Nothing. Zero. Nada. |
| 🐧 Linux | Native OS | Embedded in APK |
| 🦀 Rust Binary | Native install | Extracted from npm registry |
| 🌐 DNS | System resolver | CONNECT proxy bridge |
| 🔋 Background | Terminal stays open | Foreground service |
| 💰 Server Costs | $0-∞ depending on cloud | $0. It's your phone. |
| 📍 Portability | Carry your laptop | **Carry your pocket** |

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| 💥 App crashes on launch | Check `adb logcat` for errors |
| 🔒 "Permission denied" executing binaries | Ensure `targetSdk = 28` in `build.gradle.kts` |
| 🦀 Rust binary fails to start | Verify aarch64 architecture, check CONNECT proxy |
| 🌐 "No address associated with hostname" | Check internet; CONNECT proxy may not be running |
| 🔑 Login page doesn't open | Ensure a default browser is set on the device |
| 🔋 App killed in background | Grant battery optimization exemption in Android settings |
| 🧰 Build tools fail | Verify clang/cmake/make are installed and binary-patched |

---

## 🤝 Contributing

Found a bug? Want a feature? Have a wild idea about running more things on phones that shouldn't run on phones?

[Open an issue](https://github.com/friuns2/claw-code-android/issues) · [Submit a PR](https://github.com/friuns2/claw-code-android/pulls)

---

## ⭐ Star This Repo

If you believe AI coding agents should run **everywhere** — not just on expensive machines behind SSH tunnels — **smash that star button. ⭐**

If you ever wished you could code on the bus, in a coffee shop, or while waiting at the dentist with a **full AI agent that reads your codebase and writes code autonomously** — this is for you.

[![Stars](https://img.shields.io/github/stars/friuns2/claw-code-android?style=for-the-badge&logo=github&color=gold)](https://github.com/friuns2/claw-code-android/stargazers)
[![Forks](https://img.shields.io/github/forks/friuns2/claw-code-android?style=for-the-badge&logo=github&color=blue)](https://github.com/friuns2/claw-code-android/network)

---

## 📜 Credits

- 🦀 [Claw Code](https://github.com/instructkr/claw-code) — Open-source AI coding agent framework (48K+ ⭐)
- 🌐 [Claw Code Website](https://claw-code.codes) — Architecture docs & comparison
- 📱 [AidanPark/openclaw-android](https://github.com/AidanPark/openclaw-android) — Android patches and bionic-compat.js
- 🐧 [Termux](https://termux.dev) — Linux environment bootstrap for Android

---

<div align="center">

**Built by shoving an entire Linux distro + AI agent framework into an APK** 🔬
*Your pocket called. It wants to write some code.* 😏

</div>

[Download APK](https://friuns2.github.io/claw-code-android/) · [Claw Code](https://claw-code.codes) · [Google Play](https://play.google.com/store/apps/details?id=gptos.intelligence.assistant&hl=en)
