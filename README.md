# Retronome 🎧

**Retronome** is an unbranded, offline-first retro click-wheel media player for iOS, built with modern SwiftUI and AVFoundation. It faithfully recreates the authentic 6th-generation physical player experience—from the capacitive wheel gesture physics and mechanical sound/haptic ticks, to the 4:3 split-browser LCD, 3D Cover Flow, and skeuomorphic playback interface.

---

## ✨ Features

### 🕹️ Authentic Click Wheel & Physical Feedback
- **Rotational Gesture Engine**: Continuous angular tracking calculates natural clockwise and counter-clockwise movement around the wheel.
- **Physical Feedback (`FeedbackManager`)**:
  - Mechanical wheel tick audio (`AudioServicesPlaySystemSound(1104)`) paired with `UISelectionFeedbackGenerator`.
  - Crisp button press sound (`AudioServicesPlaySystemSound(1105)`) paired with medium impact haptics (`UIImpactFeedbackGenerator`).
  - **Clicker Toggle**: Turn sound and vibration on or off globally with a single setting.
- **Adjustable Sensitivity**: Switch between **High**, **Standard**, and **Low** rotation thresholds.
- **Hardware HOLD Switch**: Working top slider switch locks the wheel and buttons to prevent accidental touches.

### 📐 Proportional 9:16 Shell Architecture
- **Immersive Pillarboxing/Letterboxing**: On modern tall iPhones (iPhone X, 11, 12, 13, 14, 15, 16 series, ~19.5:9), the iPod casing is strictly constrained to a 9:16 aspect ratio against an ambient `#1A1A1A` backdrop.
- **Dynamic Proportional Scaling**: The 4:3 LCD and Click Wheel scale cleanly relative to the shell width, ensuring zero geometric distortion while seamlessly filling 16:9 devices (such as iPhone 8 and iPhone SE).

### 🖥️ 4:3 Retro LCD Display & Navigation
- **Split Browser**:
  - Left pane: Parallax layered push/pop menu hierarchy with smooth dimming transitions.
  - Right pane: Stationary preview window featuring album art, vintage monochrome disc engraving, and track details.
  - Performance: `LazyVStack` and `ScrollViewReader` provide smooth 60fps scrolling across large music collections.
- **Retro Status Bar**:
  - Metallic brushed gradient finish with bottom divider.
  - Cyan playback status indicator, lock glyph, and 3D glossy battery capsule with specular highlights.
  - Center player name container with automatic smooth marquee scrolling for long names.

### 💿 3D Cover Flow
- **Realistic 3D Card Stack**: Rendered using SwiftUI `rotation3DEffect` with dynamic perspective, side card angles (±60°), and smooth mirrored floor reflections into pure black.
- **Jewel Case Flip**: Pressing the Center button flips the active album 180° around the Y-axis to reveal the tracklist on the back of the case. Selecting a track starts playback immediately.

### 🎵 Now Playing & Scrubber
- **Playback Group**: Centered 105x105 album artwork with vertical reflection overlay, 5-star rating row, repeat badge (`1` / `∞`), and shuffle indicator.
- **Skeuomorphic Aqua Scrubber**: Recessed track background with high-gloss blue cylindrical capsule fill and specular glass rod highlights.
- **Wheel Scrubbing**: Rotate the Click Wheel clockwise to fast-forward, or counter-clockwise to rewind in 5-second increments.
- **Center Button Cycle**: Pressing Center on Now Playing cycles Repeat mode: **Off** ➔ **Repeat Once** ➔ **Repeat Forever**.

### 📁 Offline Library & File Importing
- **Zero Network Permissions**: Offline and privacy-respecting by design.
- **Supported Formats**: Audio (`.mp3`, `.m4a`, `.wav`, `.flac`) and Video (`.mp4`, `.mov`).
- **Files App Integration**: Import audio or video files directly from the iOS Files picker.
- **Auto-Hiding Import Actions**: Import buttons stay visible when libraries are empty and gracefully tuck away once files are loaded.
- **Live File Monitoring**: `DispatchSourceFileSystemObject` detects file additions or deletions in the app's `Documents/` directory in real-time.
- **Background Playback**: Background audio session with lock screen / Control Center Now Playing integration.

### 🎨 Personalization
- **Outer Shell Themes**: Choose from 3 chassis finishes:
  - **Light**: Classic brushed silver faceplate with light wheel and chrome buttons.
  - **Gray**: Space gray anodized chassis with dark wheel styling.
  - **Dark Gray**: Deep slate / charcoal finish.
- **Custom Player Name**: Set an in-app player name (up to 50 characters, full Unicode and emoji support) rendered in the status bar header.

---

## 🛠️ Requirements & Tech Stack

| Specification | Requirement |
| :--- | :--- |
| **Platform** | iOS 16.0+ (iPhone 8, iPhone SE 2/3, up to iPhone 16 Pro Max) |
| **Frameworks** | SwiftUI, AVFoundation, AudioToolbox, MediaPlayer, Combine, UIKit |
| **Architecture** | MVVM with centralized `PlayerViewModel` and `PlaybackEngine` |
| **Build Tools** | Xcode 15+ / Xcode 16 (`xcodebuild`, iOS SDK 16.0+) |

---

## 🚀 Building & Running

### Using Xcode
1. Open [`ClassicPlayer.xcodeproj`](ClassicPlayer.xcodeproj) in Xcode.
2. Select an iOS device or simulator (iOS 16.0+).
3. Build and run (`Cmd + R`).

### Command Line / CI Archive
To build an unsigned release archive matching the GitHub Actions pipeline:
```bash
xcodebuild -project ClassicPlayer.xcodeproj \
  -scheme ClassicPlayer \
  -sdk iphoneos \
  -configuration Release \
  -archivePath build/Retronome.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  archive
```

---

## 📄 License
This project is for educational and nostalgic preservation purposes. All UI elements, glyphs, and audio/haptic triggers are implemented purely with standard iOS system APIs without proprietary assets or trademarks.
