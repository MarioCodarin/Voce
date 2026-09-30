import Foundation

/// Writes a `multipart/form-data` body to disk so large audio never has to sit in memory.
struct MultipartBody {
    let boundary: String
    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    init(boundary: String = "voce-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    /// Creates the body file with the text `fields` followed by the audio `file`.
    func write(fields: [(name: String, value: String)], file fileURL: URL, to destination: URL) throws {
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        for field in fields {
            try output.write(contentsOf: Data((
                "--\(boundary)\r\n"
                + "Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n"
                + "\(field.value)\r\n"
            ).utf8))
        }

        try output.write(contentsOf: Data((
            "--\(boundary)\r\n"
            + "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n"
            + "Content-Type: \(AudioFormat.mimeType(for: fileURL.pathExtension))\r\n\r\n"
        ).utf8))

        let input = try FileHandle(forReadingFrom: fileURL)
        defer { try? input.close() }
        while let block = try input.read(upToCount: 1 << 20), !block.isEmpty {
            try output.write(contentsOf: block)
        }

        try output.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
    }
}
