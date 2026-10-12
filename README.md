# Minecraft Speech to Text

A small client-side Fabric mod for Minecraft Java Edition on macOS.

Hold **V**, speak, and release **V**. The mod opens Minecraft chat with the transcript. Review the text and press **Return** to send it. The mod does not send text automatically.

The speech conversion uses Apple's Speech framework. It uses on-device recognition when macOS supports it. It does not need an API key.

## Requirements

- macOS 13 or newer
- Minecraft Java Edition 26.3
- Fabric Loader 0.19.5 or newer
- Fabric API for Minecraft 26.3
- Java 25
- Xcode Command Line Tools

## Build and install

Close Minecraft. Then run:

```sh
./gradlew clean build
./install-macos.sh
```

The installer puts the mod JAR and the native speech helper in the standard Minecraft directory. You can give it a different Minecraft directory as its first argument:

```sh
./install-macos.sh "/path/to/minecraft-directory"
```

Start Minecraft with the Fabric profile. The first use can show macOS permission prompts for **Microphone** and **Speech Recognition**. If recognition does not start, enable both permissions for **Minecraft Speech to Text Helper** in **System Settings > Privacy & Security**.

## Use

1. Enter a world or server.
2. Hold **V**.
3. Speak.
4. Release **V**.
5. Review the transcript in chat.
6. Press **Return** to send it, or edit it first.

You can change the key in **Options > Controls > Speech to Text**.

## Scope

This repository contains only the speech-to-text mod, its macOS helper, and the files that build and install them. It does not contain Magic Craft scenes, weapons, worlds, or game logic.

## License

CC0-1.0

