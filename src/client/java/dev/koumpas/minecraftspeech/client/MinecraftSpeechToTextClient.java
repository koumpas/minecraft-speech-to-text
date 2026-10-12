package dev.koumpas.minecraftspeech.client;

import net.fabricmc.api.ClientModInitializer;

public final class MinecraftSpeechToTextClient implements ClientModInitializer {
	@Override
	public void onInitializeClient() {
		PushToTalkSpeech.init();
	}
}

