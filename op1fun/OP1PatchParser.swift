import Foundation

enum OP1PatchParserError: Error {
    case missingFormHeader
    case missingAIFFHeader
    case missingMetadata
    case invalidMetadata
}

enum OP1PatchParser {
    static func parse(fileURL: URL, mountPoint: URL) throws -> OP1Patch {
        let data = try Data(contentsOf: fileURL)

        guard string(in: data, range: 0..<4) == "FORM" else {
            throw OP1PatchParserError.missingFormHeader
        }

        guard string(in: data, range: 8..<12).map({ $0 == "AIFC" || $0 == "AIFF" }) == true else {
            throw OP1PatchParserError.missingAIFFHeader
        }

        let relativePath = relativePath(for: fileURL, mountPoint: mountPoint)
        let components = relativePath.split(separator: "/").map(String.init)
        let metadata = try metadata(from: data)
        let category = try category(metadata: metadata, pathComponents: components)
        let packName: String?
        let packDirectory: String?

        if components.count > 2 {
            packName = components[1..<(components.count - 1)].joined(separator: "/")
            packDirectory = "/" + components[0..<(components.count - 1)].joined(separator: "/")
        } else {
            packName = nil
            packDirectory = nil
        }

        return OP1Patch(
            id: relativePath,
            url: fileURL,
            relativePath: relativePath,
            name: fileURL.lastPathComponent,
            category: category,
            packName: packName,
            packDirectory: packDirectory
        )
    }

    private static func metadata(from data: Data) throws -> [String: Any]? {
        let formLength = Int(bigEndianUInt32(in: data, at: 4) ?? 0)
        let end = min(data.count, 8 + formLength)
        var position = 12

        while position + 8 <= end {
            let chunkName = string(in: data, range: position..<(position + 4))
            let chunkLength = Int(bigEndianUInt32(in: data, at: position + 4) ?? 0)
            let chunkDataStart = position + 8
            let chunkDataEnd = min(position + 8 + chunkLength, data.count)

            if chunkName == "APPL", chunkDataStart + 4 <= chunkDataEnd {
                let signature = string(in: data, range: chunkDataStart..<(chunkDataStart + 4))

                if signature == "op-1" {
                    let payloadStart = chunkDataStart + 4
                    let payload = data[payloadStart..<chunkDataEnd]
                    let jsonString = String(decoding: payload, as: UTF8.self)
                        .replacingOccurrences(of: "\0", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    guard
                        let jsonData = jsonString.data(using: .utf8),
                        let object = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                    else {
                        throw OP1PatchParserError.invalidMetadata
                    }

                    return object
                }
            }

            let paddedLength = chunkLength + (chunkLength % 2)
            position += 8 + paddedLength
        }

        return nil
    }

    private static func category(metadata: [String: Any]?, pathComponents _: [String]) throws -> PatchCategory {
        guard let type = metadata?["type"] as? String else {
            throw OP1PatchParserError.missingMetadata
        }

        if type == "drum" {
            return .drum
        } else if type == "sampler" {
            return .sampler
        } else {
            return .synth
        }
    }

    private static func relativePath(for fileURL: URL, mountPoint: URL) -> String {
        let mountPath = mountPoint.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path

        if filePath.hasPrefix(mountPath) {
            let suffix = filePath.dropFirst(mountPath.count)
            return suffix.hasPrefix("/") ? String(suffix) : "/" + suffix
        }

        return "/" + fileURL.lastPathComponent
    }

    private static func bigEndianUInt32(in data: Data, at offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else {
            return nil
        }

        return data[offset..<(offset + 4)].reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
    }

    private static func string(in data: Data, range: Range<Int>) -> String? {
        guard range.lowerBound >= 0, range.upperBound <= data.count else {
            return nil
        }

        return String(data: data[range], encoding: .ascii)
    }
}
