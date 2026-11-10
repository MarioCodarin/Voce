import Foundation

/// A tiny valid PCM WAV file, used to exercise the real AVFoundation path.
func silentWAV(seconds: Int = 1) -> URL {
    let rate = 16000
    let bytes = rate * seconds * 2
    var data = Data()
    data += "RIFF".utf8
    data += withUnsafeBytes(of: UInt32(36 + bytes).littleEndian, Array.init)
    data += "WAVEfmt ".utf8
    data += withUnsafeBytes(of: UInt32(16).littleEndian, Array.init)
    data += withUnsafeBytes(of: UInt16(1).littleEndian, Array.init)
    data += withUnsafeBytes(of: UInt16(1).littleEndian, Array.init)
    data += withUnsafeBytes(of: UInt32(rate).littleEndian, Array.init)
    data += withUnsafeBytes(of: UInt32(rate * 2).littleEndian, Array.init)
    data += withUnsafeBytes(of: UInt16(2).littleEndian, Array.init)
    data += withUnsafeBytes(of: UInt16(16).littleEndian, Array.init)
    data += "data".utf8
    data += withUnsafeBytes(of: UInt32(bytes).littleEndian, Array.init)
    data += Data(repeating: 0, count: bytes)
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("voce-test-\(UUID().uuidString).wav")
    try! data.write(to: url)
    return url
}
