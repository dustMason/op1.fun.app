import Foundation

enum JSONAPIError: LocalizedError {
    case invalidResource
    case missingDownloadURL
    case missingPackPatches

    var errorDescription: String? {
        switch self {
        case .invalidResource:
            return "The op1.fun API response could not be decoded."
        case .missingDownloadURL:
            return "The selected patch did not include a downloadable file URL."
        case .missingPackPatches:
            return "The selected pack did not include any patch records."
        }
    }
}

enum JSONAPI {
    static func parsePatchRoot(_ data: Data) throws -> RemotePatch {
        let object = try rootObject(from: data)
        guard let resource = object["data"] as? [String: Any] else {
            throw JSONAPIError.invalidResource
        }

        return try parsePatch(resource)
    }

    static func parsePackRoot(_ data: Data) throws -> RemotePack {
        let object = try rootObject(from: data)

        guard
            let resource = object["data"] as? [String: Any],
            let id = resource["id"] as? String
        else {
            throw JSONAPIError.invalidResource
        }

        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        let name = attributes["name"] as? String ?? id
        let included = object["included"] as? [[String: Any]] ?? []
        let includedPatches = Dictionary(uniqueKeysWithValues: included.compactMap { resource -> (String, [String: Any])? in
            guard
                let type = resource["type"] as? String,
                type == "patches",
                let id = resource["id"] as? String
            else {
                return nil
            }

            return ((["patches", id].joined(separator: ":")), resource)
        })

        let relationshipData =
            (((resource["relationships"] as? [String: Any])?["patches"] as? [String: Any])?["data"] as? [[String: Any]]) ?? []

        var patches: [RemotePatch] = []
        for reference in relationshipData {
            guard
                let referenceID = reference["id"] as? String,
                let patchResource = includedPatches[["patches", referenceID].joined(separator: ":")]
            else {
                continue
            }

            patches.append(try parsePatch(patchResource))
        }

        if patches.isEmpty {
            patches = try included
                .filter { ($0["type"] as? String) == "patches" }
                .map(parsePatch)
        }

        guard !patches.isEmpty else {
            throw JSONAPIError.missingPackPatches
        }

        return RemotePack(id: id, name: name, patches: patches)
    }

    private static func parsePatch(_ resource: [String: Any]) throws -> RemotePatch {
        guard let id = resource["id"] as? String else {
            throw JSONAPIError.invalidResource
        }

        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        let name = attributes["name"] as? String ?? id
        let patchType =
            attributes["patch-type"] as? String ??
            attributes["patch_type"] as? String ??
            attributes["patchType"] as? String ??
            "synth"

        guard let fileURL = link(named: "file", in: resource) else {
            throw JSONAPIError.missingDownloadURL
        }

        return RemotePatch(id: id, name: name, patchType: patchType, fileURL: fileURL)
    }

    private static func rootObject(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JSONAPIError.invalidResource
        }

        return object
    }

    private static func link(named name: String, in resource: [String: Any]) -> URL? {
        guard let links = resource["links"] as? [String: Any] else {
            return nil
        }

        if let string = links[name] as? String {
            return URL(string: string)
        }

        if
            let object = links[name] as? [String: Any],
            let href = object["href"] as? String
        {
            return URL(string: href)
        }

        return nil
    }
}
