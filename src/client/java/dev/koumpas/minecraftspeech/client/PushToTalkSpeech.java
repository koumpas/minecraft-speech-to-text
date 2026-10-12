package dev.koumpas.minecraftspeech.client;

import com.mojang.blaze3d.platform.InputConstants;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keymapping.v1.KeyMappingHelper;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.screens.ChatScreen;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;

/** Push-to-talk transcription backed by the native macOS Speech framework. */
public final class PushToTalkSpeech {
	private static final KeyMapping.Category CATEGORY = KeyMapping.Category.register(
		Identifier.fromNamespaceAndPath("minecraft_speech_to_text", "controls"));
	private static final KeyMapping SPEECH_KEY = KeyMappingHelper.registerKeyMapping(new KeyMapping(
		"key.minecraft_speech_to_text.push_to_talk", InputConstants.Type.KEYBOARD, InputConstants.KEY_V, CATEGORY));
	private static boolean wasDown;
	private static volatile boolean busy;
	private static Path stopFile;

	private PushToTalkSpeech() {}

	public static void init() {
		ClientTickEvents.END_CLIENT_TICK.register(client -> {
			boolean down = SPEECH_KEY.isDown();
			if (down && !wasDown) start(client);
			if (!down && wasDown) stop(client);
			wasDown = down;
		});
	}

	private static void start(Minecraft client) {
		if (client.player == null || busy) return;
		Path helper = client.gameDirectory.toPath()
			.resolve("minecraft-speech-to-text/Minecraft Speech to Text Helper.app");
		if (!Files.isDirectory(helper)) {
			message(client, "The speech helper is missing. Run install-macos.sh.");
			return;
		}

		try {
			Path sessionDirectory = Files.createTempDirectory("minecraft-speech-to-text-");
			Path outputFile = sessionDirectory.resolve("transcript.txt");
			stopFile = sessionDirectory.resolve("stop");
			busy = true;
			message(client, "Listening. Keep V held while you speak.");
			Thread.startVirtualThread(() -> transcribe(client, helper, sessionDirectory, outputFile, stopFile));
		} catch (IOException exception) {
			busy = false;
			message(client, "Speech recognition could not start.");
		}
	}

	private static void stop(Minecraft client) {
		if (!busy || stopFile == null) return;
		try {
			Files.createFile(stopFile);
			message(client, "Processing speech.");
		} catch (IOException exception) {
			message(client, "Speech recognition could not stop.");
		}
	}

	private static void transcribe(
		Minecraft client,
		Path helper,
		Path sessionDirectory,
		Path outputFile,
		Path sessionStopFile
	) {
		String diagnostic = "";
		String transcript = "";
		try {
			Process process = new ProcessBuilder(
				"/usr/bin/open", "-W", "-n", helper.toString(), "--args",
				outputFile.toString(), sessionStopFile.toString())
				.redirectErrorStream(true)
				.start();
			diagnostic = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
			int exitCode = process.waitFor();
			if (exitCode == 0 && Files.exists(outputFile)) transcript = Files.readString(outputFile).trim();
		} catch (IOException exception) {
			diagnostic = "The speech helper could not start.";
		} catch (InterruptedException exception) {
			Thread.currentThread().interrupt();
			diagnostic = "Speech processing stopped.";
		}

		String finalTranscript = transcript.replace('\n', ' ').replace('\r', ' ').trim();
		String finalDiagnostic = diagnostic;
		cleanup(sessionDirectory);
		client.execute(() -> finish(client, finalTranscript, finalDiagnostic));
	}

	private static void finish(Minecraft client, String transcript, String diagnostic) {
		busy = false;
		stopFile = null;
		if (client.player == null) return;
		if (transcript.isBlank()) {
			String detail = diagnostic.isBlank() ? "No speech was detected. Hold V while you speak." : diagnostic;
			message(client, detail);
			return;
		}

		client.setScreenAndShow(new ChatScreen(transcript, false));
	}

	private static void cleanup(Path directory) {
		try (var paths = Files.walk(directory)) {
			paths.sorted(Comparator.reverseOrder()).forEach(path -> {
				try {
					Files.deleteIfExists(path);
				} catch (IOException ignored) {
					// Temporary files are best-effort cleanup.
				}
			});
		} catch (IOException ignored) {
			// Temporary files are best-effort cleanup.
		}
	}

	private static void message(Minecraft client, String text) {
		client.execute(() -> {
			if (client.player != null) {
				client.player.sendOverlayMessage(Component.literal("[Speech to Text] " + text));
			}
		});
	}
}
