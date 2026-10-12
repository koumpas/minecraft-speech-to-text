import AppKit
import AVFoundation
import Foundation
import Speech

private func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

private func waitForSpeechPermission() -> Bool {
    if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
    var authorized = false
    var finished = false
    SFSpeechRecognizer.requestAuthorization { status in
        authorized = status == .authorized
        finished = true
    }
    while !finished { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    return authorized
}

private func waitForMicrophonePermission() -> Bool {
    if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized { return true }
    var authorized = false
    var finished = false
    AVCaptureDevice.requestAccess(for: .audio) { granted in
        authorized = granted
        finished = true
    }
    while !finished { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    return authorized
}

guard CommandLine.arguments.count == 3 else {
    fail("The speech helper needs an output path and a stop path.", code: 2)
}

let outputPath = CommandLine.arguments[1]
let stopPath = CommandLine.arguments[2]
NSApplication.shared.setActivationPolicy(.accessory)

guard waitForSpeechPermission() else {
    fail("Speech Recognition permission is not enabled for Minecraft Speech to Text Helper.", code: 3)
}
guard waitForMicrophonePermission() else {
    fail("Microphone permission is not enabled for Minecraft Speech to Text Helper.", code: 4)
}
guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
    fail("The Mac speech recognizer is not available.", code: 5)
}

let request = SFSpeechAudioBufferRecognitionRequest()
request.shouldReportPartialResults = true
if recognizer.supportsOnDeviceRecognition {
    request.requiresOnDeviceRecognition = true
}

let lock = NSLock()
var transcript = ""
var recognitionFinished = false
let recognitionTask = recognizer.recognitionTask(with: request) { result, error in
    lock.lock()
    if let result {
        transcript = result.bestTranscription.formattedString
        recognitionFinished = result.isFinal
    }
    if error != nil { recognitionFinished = true }
    lock.unlock()
}

let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode
let recordingFormat = inputNode.outputFormat(forBus: 0)
inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
    request.append(buffer)
}

do {
    audioEngine.prepare()
    try audioEngine.start()
} catch {
    recognitionTask.cancel()
    fail("The microphone could not start: \(error.localizedDescription)", code: 6)
}

while !FileManager.default.fileExists(atPath: stopPath) {
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
}

audioEngine.stop()
inputNode.removeTap(onBus: 0)
request.endAudio()

let finalDeadline = Date().addingTimeInterval(3)
while Date() < finalDeadline {
    lock.lock()
    let finished = recognitionFinished
    lock.unlock()
    if finished { break }
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
}

lock.lock()
let finalTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
lock.unlock()

do {
    try finalTranscript.write(toFile: outputPath, atomically: true, encoding: .utf8)
} catch {
    fail("The transcript could not be saved.", code: 7)
}

recognitionTask.cancel()

