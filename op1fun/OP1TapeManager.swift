import CryptoKit
import Foundation

enum OP1TapeManagerError: LocalizedError {
    case missingTapeDirectory
    case missingTracks
    case invalidArchive
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .missingTapeDirectory:
            return "The OP-1 tape folder could not be found."
        case .missingTracks:
            return "No OP-1 tape tracks were found."
        case .invalidArchive:
            return "The selected tape backup did not contain valid OP-1 tape tracks."
        case .extractionFailed:
            return "The tape backup could not be unpacked."
        }
    }
}

enum OP1TapeManager {
    static func snapshot(mountPoint: URL) throws -> LocalTapeSnapshot {
        let tapeDirectory = mountPoint.appendingPathComponent("tape", isDirectory: true)
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: tapeDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw OP1TapeManagerError.missingTapeDirectory
        }

        let tracks = try (1...4).compactMap { trackNumber -> LocalTapeTrack? in
            let url = tapeDirectory.appendingPathComponent("track_\(trackNumber).aif")
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }

            return try localTrack(trackNumber: trackNumber, url: url)
        }

        guard !tracks.isEmpty else {
            throw OP1TapeManagerError.missingTracks
        }

        return LocalTapeSnapshot(
            tapeDirectory: tapeDirectory,
            tracks: tracks,
            fingerprint: fingerprint(for: tracks)
        )
    }

    static func restore(archiveURL: URL, to mountPoint: URL) throws {
        let tapeDirectory = mountPoint.appendingPathComponent("tape", isDirectory: true)
        let extractionDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("op1fun-tape-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(
            at: extractionDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: extractionDirectory)
        }

        try extractZip(archiveURL, to: extractionDirectory)
        let restoredTracks = try tracksInArchive(extractionDirectory)

        guard !restoredTracks.isEmpty else {
            throw OP1TapeManagerError.invalidArchive
        }

        try FileManager.default.createDirectory(
            at: tapeDirectory,
            withIntermediateDirectories: true
        )

        for trackNumber in 1...4 {
            let destination = tapeDirectory.appendingPathComponent("track_\(trackNumber).aif")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
        }

        for (trackNumber, sourceURL) in restoredTracks {
            let destination = tapeDirectory.appendingPathComponent("track_\(trackNumber).aif")
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        }
    }

    private static func localTrack(trackNumber: Int, url: URL) throws -> LocalTapeTrack {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()

        return LocalTapeTrack(
            trackNumber: trackNumber,
            url: url,
            filename: url.lastPathComponent,
            byteCount: Int64(data.count),
            sha256: digest
        )
    }

    private static func fingerprint(for tracks: [LocalTapeTrack]) -> String {
        let manifest = tracks
            .sorted { $0.trackNumber < $1.trackNumber }
            .map { "\($0.trackNumber):\($0.byteCount):\($0.sha256)" }
            .joined(separator: "\n")
        let digest = SHA256.hash(data: Data(manifest.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func extractZip(_ archiveURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destinationURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw OP1TapeManagerError.extractionFailed
        }

        guard process.terminationStatus == 0 else {
            throw OP1TapeManagerError.extractionFailed
        }
    }

    private static func tracksInArchive(_ directoryURL: URL) throws -> [(Int, URL)] {
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw OP1TapeManagerError.invalidArchive
        }

        let candidates = enumerator
            .compactMap { $0 as? URL }
            .filter { url in
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                    return false
                }

                return ["aif", "aiff"].contains(url.pathExtension.lowercased())
            }

        var mapped: [Int: URL] = [:]
        var unmapped: [URL] = []

        for candidate in candidates {
            if let trackNumber = trackNumber(from: candidate) {
                mapped[trackNumber] = candidate
            } else {
                unmapped.append(candidate)
            }
        }

        for candidate in unmapped.sorted(by: { $0.path < $1.path }) {
            guard let trackNumber = (1...4).first(where: { mapped[$0] == nil }) else {
                break
            }

            mapped[trackNumber] = candidate
        }

        return mapped
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    private static func trackNumber(from url: URL) -> Int? {
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        for trackNumber in 1...4 {
            let number = String(trackNumber)
            if name == "track_\(number)" ||
                name == "track-\(number)" ||
                name == "track \(number)" ||
                name == number {
                return trackNumber
            }
        }

        return nil
    }
}
