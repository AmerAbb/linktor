# Linktor

A macOS menu bar app for triggering deep links on iOS and Android devices.

![macOS](https://img.shields.io/badge/macOS-menu%20bar-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![Platform](https://img.shields.io/badge/targets-iOS%20%7C%20Android-green)

## What It Does

Linktor sits in your menu bar and lets you open deep links on a running simulator, emulator, or connected physical device with one click. You define your links in a `.deeplinks.json` file in your project root, point the app at the folder, and it builds a browsable, searchable list with editable parameters.

**Key features:**

- One-click deep link triggering on iOS Simulator/physical device or Android Emulator/physical device
- Device picker with auto-selection (physical devices preferred)
- Auto-detects platform based on project files (`.xcodeproj` = iOS, `build.gradle` = Android)
- Parameterized URLs with editable path and query parameters
- Save presets for frequently-used parameter combinations
- Quick-add manual links without editing the config file
- Search/filter across all links
- Refresh button to reload config without restarting
- Automatic updates — checks every 24 hours, or manually via toolbar button

## Installation

Download the latest `Linktor.zip` from [GitHub Releases](https://github.com/amerabb/linktor/releases/latest), unzip, and move `Linktor.app` to your Applications folder. Launch it — the link icon appears in your menu bar.

> **Note:** Linktor checks for updates automatically every 24 hours while running. You can also check manually using the update button in the toolbar.

### Building from Source

```bash
# Generate the Xcode project
xcodegen generate

# Build a release binary
xcodebuild -project DeepLinkTrigger.xcodeproj -scheme DeepLinkTrigger -configuration Release
```

## Quick Start

1. Create a `.deeplinks.json` file in your project root (see format below)
2. Click the menu bar icon and select your project folder
3. Your links appear — click any link to open it on the booted simulator/emulator

## `.deeplinks.json` Configuration

Place this file in the root of your project directory. The app reads it to build your link library.

### Minimal Example

```json
{
  "scheme": "myapp",
  "links": [
    {
      "name": "Home",
      "path": "/home"
    }
  ]
}
```

This produces the URL `myapp://home` and triggers it on click.

### With Physical iOS Device

```json
{
  "scheme": "myapp",
  "bundleId": "com.example.myapp",
  "links": [
    {
      "name": "Home",
      "path": "/home"
    }
  ]
}
```

The `bundleId` is required for triggering deep links on physical iOS devices (via `xcrun devicectl`). It is optional for simulators and all Android devices.

### Full Example

```json
{
  "scheme": "myapp",
  "links": [
    { "name": "Home", "path": "/home" },
    { "name": "Profile", "path": "/profile" },
    {
      "name": "Product Detail",
      "path": "/product/{productId}",
      "params": { "productId": { "type": "string", "default": "12345" } }
    },
    {
      "name": "Category",
      "path": "/category/{categoryId}/items",
      "params": { "categoryId": { "type": "string", "default": "electronics" } }
    },
    {
      "name": "Search",
      "path": "/search",
      "queryParams": {
        "q": { "type": "string", "default": "shoes" },
        "ref": { "type": "string", "default": "home" }
      }
    },
    {
      "name": "User Profile",
      "path": "/user/{userId}/profile",
      "params": { "userId": { "type": "string", "default": "42" } },
      "queryParams": { "tab": { "type": "string", "default": "overview" } }
    }
  ]
}
```

### Schema Reference

#### Root Object

| Field      | Type   | Required | Description                                                                         |
|------------|--------|----------|-------------------------------------------------------------------------------------|
| `scheme`   | string | Yes      | Your app's URL scheme (e.g. `"myapp"` produces `myapp://`)                          |
| `bundleId` | string | No       | App bundle identifier (e.g. `"com.example.myapp"`). Required for physical iOS devices. |
| `links`    | array  | Yes      | Array of link definitions                                                           |

#### Link Object

| Field         | Type   | Required | Description                                          |
|---------------|--------|----------|------------------------------------------------------|
| `name`        | string | Yes      | Display name shown in the menu                       |
| `path`        | string | Yes      | URL path. Use `{paramName}` for path parameters      |
| `params`      | object | No       | Path parameter definitions, keyed by parameter name  |
| `queryParams` | object | No       | Query parameter definitions, keyed by parameter name |

#### Parameter Object (used in both `params` and `queryParams`)

| Field     | Type   | Required | Description                      |
|-----------|--------|----------|----------------------------------|
| `type`    | string | Yes      | Parameter type (e.g. `"string"`) |
| `default` | string | Yes      | Default value shown in the form  |

### URL Construction

The app builds URLs following this pattern:

```
{scheme}://{path with params substituted}?{queryParams}
```

**Examples based on the config above:**

| Link           | Resulting URL                          |
|----------------|----------------------------------------|
| Home           | `myapp://home`                         |
| Product Detail | `myapp://product/12345`                |
| Search         | `myapp://search?q=shoes&ref=home`      |
| User Profile   | `myapp://user/42/profile?tab=overview` |

Path parameters (`params`) replace `{placeholders}` in the path. Query parameters (`queryParams`) are appended as a query string. All values are editable in the UI before triggering.

## Platform Detection

The app auto-detects the platform when you open a project folder:

| Platform | Detected when project contains                                                                      |
|----------|-----------------------------------------------------------------------------------------------------|
| iOS      | `.xcodeproj`, `.xcworkspace`, or `Package.swift`                                                    |
| Android  | `build.gradle`, `build.gradle.kts`, `settings.gradle`, `settings.gradle.kts`, or `app/build.gradle` |

The same `.deeplinks.json` file works for both platforms — only the trigger mechanism changes.

## Requirements

- **macOS** (menu bar app)
- **For iOS Simulator:** Xcode with a booted Simulator
- **For iOS Physical Device:** Xcode 15+ with a connected device (requires `bundleId` in config)
- **For Android:** ADB installed. The app checks these locations in order:
  1. `~/Library/Android/sdk/platform-tools/adb`
  2. `/usr/local/bin/adb`
  3. `/opt/homebrew/bin/adb`
  4. System PATH (`which adb`)

## Usage Tips

- **Presets:** For parameterized links, fill in the values you use often, then click "Save as Preset" to create a one-click shortcut
- **Quick Add:** Use the `+` button to add a one-off link without editing the JSON file (e.g. `myapp://debug/reset`)
- **Refresh:** After editing `.deeplinks.json`, click the refresh button (⟳) to reload without restarting the app
- **Search:** Use the search bar to filter links by name or path
- **Device Picker:** Use the dropdown in the header to switch between connected devices. Physical devices are auto-selected when available. Use "Refresh Devices" to rescan.

## Releasing a New Version

Releases are automated. Run one command and GitHub Actions handles the rest:

```bash
fastlane release bump:patch   # 0.1.0 → 0.1.1
fastlane release bump:minor   # 0.1.0 → 0.2.0
fastlane release bump:major   # 0.1.0 → 1.0.0
```

This bumps the version in `project.yml`, commits, tags, and pushes. GitHub Actions then builds, archives, signs the appcast, and creates the GitHub Release automatically.

## Contributing

Contributions welcome via pull requests. Fork the repo, create a feature branch, and open a PR. Only the maintainer pushes directly to `main`.

## License

MIT
