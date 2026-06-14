import Foundation
import SwiftUI

enum AppView {
    case browser
    case login
}

enum PatchCategory: String, CaseIterable, Identifiable {
    case synth
    case drum
    case sampler

    var id: String { rawValue }

    var title: String {
        switch self {
        case .synth: return "Synth"
        case .drum: return "Drum"
        case .sampler: return "Sampler"
        }
    }

    var limit: Int {
        switch self {
        case .synth: return 100
        case .drum, .sampler: return 42
        }
    }

    var tint: Color {
        switch self {
        case .synth: return .op1Blue
        case .drum: return .op1Green
        case .sampler: return .white
        }
    }
}

enum BrowserSection: Equatable {
    case patch(PatchCategory)
    case tapes
}

struct OP1Patch: Identifiable, Equatable {
    let id: String
    let url: URL
    let relativePath: String
    let name: String
    let category: PatchCategory
    let packName: String?
    let packDirectory: String?

    var sortKey: String {
        "\(packDirectory ?? "/000")\(name.lowercased())"
    }
}

struct PatchGroup: Identifiable {
    let id: String
    let packName: String?
    let packDirectory: String?
    var patches: [OP1Patch]
}

struct RemotePatch {
    let id: String
    let name: String
    let patchType: String
    let fileURL: URL
}

struct RemotePack {
    let id: String
    let name: String
    let patches: [RemotePatch]
}

enum TapeStatus: String {
    case processing
    case ready
    case failed
    case unknown

    var title: String {
        switch self {
        case .processing: return "Processing"
        case .ready: return "Ready"
        case .failed: return "Failed"
        case .unknown: return "Unknown"
        }
    }
}

struct RemoteTape: Identifiable, Equatable {
    let id: String
    let name: String
    let status: TapeStatus
    let createdAt: Date?
    let updatedAt: Date?
    let fingerprint: String?
    let trackCount: Int
    let hasArchive: Bool
    let previewURL: URL?
    let downloadURL: URL?

    var displayName: String {
        name.isEmpty ? "Tape #\(id)" : name
    }

    var canLoadToOP1: Bool {
        status == .ready || hasArchive || downloadURL != nil
    }
}

struct TapeUploadTarget {
    let trackNumber: Int
    let uploadURL: URL
    let filename: String
}

struct TapeUploadSession {
    let tape: RemoteTape
    let uploadTargets: [TapeUploadTarget]
}

struct LocalTapeTrack {
    let trackNumber: Int
    let url: URL
    let filename: String
    let byteCount: Int64
    let sha256: String
}

struct LocalTapeSnapshot {
    let tapeDirectory: URL
    let tracks: [LocalTapeTrack]
    let fingerprint: String

    var trackCount: Int {
        tracks.count
    }
}

struct CompanionLink {
    let path: String
    let resourceType: String
    let resourceID: String

    init?(url: URL) {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = path.split(separator: "/").map(String.init)

        guard parts.count >= 4 else {
            return nil
        }

        self.path = path
        self.resourceType = parts[2]
        self.resourceID = parts[3]
    }
}

extension Array where Element == OP1Patch {
    func groupedByPack() -> [PatchGroup] {
        var groups: [PatchGroup] = []

        for patch in self {
            let groupID = patch.packName ?? "__root__"
            if let index = groups.indices.last, groups[index].id == groupID {
                groups[index].patches.append(patch)
            } else {
                groups.append(PatchGroup(
                    id: groupID,
                    packName: patch.packName,
                    packDirectory: patch.packDirectory,
                    patches: [patch]
                ))
            }
        }

        return groups
    }
}
