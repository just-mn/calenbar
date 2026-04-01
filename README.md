# CalenBar

**Keep your Calendar events and Reminders always visible in the macOS menu bar**

[![macOS](https://img.shields.io/badge/macOS-14.6%2B-blue)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

[Features](#-features) • [Installation](#-installation) • [Building](#-building-from-source) • [Privacy](#-privacy)

**[🇷🇺 Русская версия](README.ru.md)**

---

## ✨ Features

### 📅 Events (first menu bar icon)
- **Flashes + plays sound** when a calendar alert fires
- Shows event name and countdown to start time
- Stays visible until you manually dismiss it
- **During an event:** always displayed, shows time remaining
- **Multiple overlapping events:** cycle automatically every 5 seconds
- Dismissing removes only the notification — the event stays in Calendar.app

### ✅ Reminders (second menu bar icon)
- Appears when a reminder is due or its alarm fires
- **Flashes + plays sound** to grab your attention
- **Requires action** — you can't just dismiss it:
  - **Snooze** — creates a new alarm N minutes from now
  - **Mark Complete** — marks the reminder as done in Reminders.app

### ⚙️ Settings
- Choose which calendars and reminder lists to monitor
- Toggle flashing and sound effects; pick your notification sound
- Customize snooze duration options (5, 10, 15, 30 min, etc.)
- Launch at login option

## 📋 Requirements

- **macOS 14 Sonoma** or later
- **Xcode 15** or later (only for building from source)

## 📦 Installation

### Option 1: Download pre-built app (Recommended)

1. Go to the [**Releases**](../../releases) page
2. Download the latest **CalendarBar.app.zip** file
3. Unzip and move **CalendarBar.app** to your **Applications** folder
4. **Important:** On first launch, macOS will block the app because it's signed with an individual developer certificate:
   - Open **System Settings** → **Privacy & Security**
   - Scroll down to the **Security** section
   - Click **Open Anyway** next to the CalenBar message
   
5. On first launch, the app will request access to **Calendar** and **Reminders** — grant permission

### Option 2: Build from source

See [Building from Source](#-building-from-source) below.

## 🛠 Building from Source

If you prefer to compile the app yourself:

### 1. Clone the repository

```bash
git clone https://github.com/just-mn/calenbar.git
cd calenbar
```

### 2. Open the project in Xcode

```bash
open calenbar.xcodeproj
```

### 3. Configure signing (optional)

The project is configured for **Automatic Signing**.

- **If you have an Apple ID:** Xcode will automatically create a development certificate
- **If you don't:** The project will build with ad-hoc signing

To change signing settings:
1. Select the **CalendarBar** project in the navigator
2. Go to **Signing & Capabilities** tab
3. Choose your **Team** or leave empty for ad-hoc signing

### 4. Build the app

**To run from Xcode:**
- Press **⌘R** — the app launches immediately in the menu bar

**To install to Applications:**
1. Press **⌘B** to build
2. In Xcode: **Product** → **Show Build Folder in Finder**
3. Navigate to **Products** → **Debug**
4. Copy **CalendarBar.app** to your **Applications** folder:

```bash
# Or via terminal
cp -R ~/Library/Developer/Xcode/DerivedData/CalendarBar-*/Build/Products/Debug/CalendarBar.app /Applications/
```

## 🔒 Privacy

CalendarBar uses the system **EventKit** framework to read your Calendar and Reminders data **locally on your device**. No information is sent to the internet or any third-party servers.

How it works:
- Polls events and reminders every 30 seconds
- Reacts instantly to calendar changes via system notifications
- All data is processed exclusively on your Mac

**No analytics. No tracking. No cloud.**

## 🛠️ Technical Details

- **EventKit Framework** — access to Calendar and Reminders
- **SwiftUI** — modern declarative UI
- **MenuBarExtra** — native menu bar integration
- Polling every 30 seconds + subscription to calendar change notifications
- Audio via **AVFoundation** and system sounds
- Service Management API for login item support

## 🤝 Contributing

Found a bug or have a feature request?
- Open an [Issue](../../issues)
- Submit a [Pull Request](../../pulls)

All contributions are welcome!

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

## 🎨 Acknowledgments

This project was created with assistance from [Claude](https://claude.ai) by Anthropic. The code was generated through an AI-assisted development session and has not been manually reviewed line by line.

---

**[🇷🇺 Читать на русском](README.ru.md)**
