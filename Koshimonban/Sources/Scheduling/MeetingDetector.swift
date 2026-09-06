import Foundation
import CoreAudio
import CoreMediaIO

/// 会議中かどうかを、マイクとカメラが使われているかで判定する。
///
/// アプリを名指しで判定しない。Zoom / Google Meet / Teams / Slack ハドルは
/// どれも「マイクかカメラを掴む」という点では同じなので、デバイス側を見れば
/// ブラウザ経由のものも含めてまとめて拾える。個別対応も要らない。
///
/// macOS がメニューバーに出すオレンジ・緑のインジケータと同じ情報源。
/// デバイスの状態を問い合わせるだけなので、マイクやカメラの利用許可は不要。
///
/// **ミュートしていても検知できる。** 会議アプリのミュートはソフトウェア側の処理で、
/// デバイス自体は掴んだままのことがほとんどのため。
@MainActor
final class MeetingDetector {

    /// 会議中とみなすか。マイクとカメラのどちらかが使われていればそうみなす。
    var isInMeeting: Bool {
        isMicrophoneInUse || isCameraInUse
    }

    var isMicrophoneInUse: Bool {
        Self.audioInputDevices().contains { Self.audioDeviceIsRunning($0) == true }
    }

    var isCameraInUse: Bool {
        Self.videoDevices().contains { Self.videoDeviceIsRunning($0) == true }
    }

    /// 設定画面に出す診断用の一覧。誤検知が出たときに、どのデバイスが原因かを見るために使う。
    struct DeviceState: Identifiable {
        let id: String
        let name: String
        let isRunning: Bool
        let isCamera: Bool
    }

    func deviceStates() -> [DeviceState] {
        let microphones = Self.audioInputDevices().map { device in
            DeviceState(id: "audio-\(device)",
                        name: Self.audioDeviceName(device),
                        isRunning: Self.audioDeviceIsRunning(device) == true,
                        isCamera: false)
        }
        let cameras = Self.videoDevices().map { device in
            DeviceState(id: "video-\(device)",
                        name: Self.videoDeviceName(device),
                        isRunning: Self.videoDeviceIsRunning(device) == true,
                        isCamera: true)
        }
        return microphones + cameras
    }

    // MARK: マイク（CoreAudio）

    /// 入力チャンネルを持つデバイスだけを返す。
    /// 既定の入力デバイスだけを見ると、会議アプリが別のデバイス（ヘッドセット等）を
    /// 使っている場合に取りこぼす。
    private static func audioInputDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }

        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.filter { hasInputStreams($0) }
    }

    private static func hasInputStreams(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else {
            return false
        }
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, buffer) == noErr else {
            return false
        }
        let list = UnsafeMutableAudioBufferListPointer(
            buffer.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }

    private static func audioDeviceIsRunning(_ device: AudioDeviceID) -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr else {
            return nil
        }
        return running != 0
    }

    private static func audioDeviceName(_ device: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr else {
            return "不明なマイク"
        }
        return name as String
    }

    // MARK: カメラ（CoreMediaIO）

    private static func videoDevices() -> [CMIOObjectID] {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }

        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, size, &used, &ids) == noErr else { return [] }

        return ids
    }

    private static func videoDeviceIsRunning(_ device: CMIOObjectID) -> Bool? {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var running: UInt32 = 0
        var used: UInt32 = 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        guard CMIOObjectGetPropertyData(device, &address, 0, nil, size, &used, &running) == noErr else {
            return nil
        }
        return running != 0
    }

    private static func videoDeviceName(_ device: CMIOObjectID) -> String {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyName),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var name: CFString = "" as CFString
        var used: UInt32 = 0
        let size = UInt32(MemoryLayout<CFString>.size)
        guard CMIOObjectGetPropertyData(device, &address, 0, nil, size, &used, &name) == noErr else {
            return "不明なカメラ"
        }
        return name as String
    }
}
