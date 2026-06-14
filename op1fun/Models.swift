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

