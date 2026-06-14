import Foundation

enum JSONAPIError: LocalizedError {
    case invalidResource
    case missingDownloadURL
    case missingPackPatches
    case missingTapeUploads

    var errorDescription: String? {
        switch self {
        case .invalidResource:
            return "The op1.fun API response could not be decoded."
        case .missingDownloadURL:
            return "The selected patch did not include a downloadable file URL."
        case .missingPackPatches:
            return "The selected pack did not include any patch records."
        case .missingTapeUploads:
            return "op1.fun did not return upload URLs for this tape."
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

        guard let resource = object["data"] as? [String: Any] else {
            throw JSONAPIError.invalidResource
        }

        let included = object["included"] as? [[String: Any]] ?? []
        return try parsePack(resource, included: included, requiresPatches: true)
    }

    static func parsePackListRoot(_ data: Data) throws -> [RemotePack] {
        let object = try rootObject(from: data)
        guard let resources = object["data"] as? [[String: Any]] else {
            throw JSONAPIError.invalidResource
        }

        let included = object["included"] as? [[String: Any]] ?? []
        return try resources.map { resource in
            try parsePack(resource, included: included, requiresPatches: false)
        }
    }

    static func parseUser(from object: [String: Any]) -> RemoteUser? {
        if let user = object["user"] as? [String: Any] {
            return parseUser(user)
        }

        if let resource = object["data"] as? [String: Any],
           (resource["type"] as? String) == "users" {
            return parseUser(resource)
        }

        if let id =
            stringValue(named: "user-id", in: object) ??
            stringValue(named: "user_id", in: object) ??
            stringValue(named: "userID", in: object) ??
            stringValue(named: "username", in: object) {
            return RemoteUser(
                id: id,
                username: stringValue(named: "username", in: object) ?? id
            )
        }

        return nil
    }

    static func parseTapeListRoot(_ data: Data) throws -> [RemoteTape] {
        let object = try rootObject(from: data)
        guard let resources = object["data"] as? [[String: Any]] else {
            throw JSONAPIError.invalidResource
        }

        return try resources.map(parseTape)
    }

    static func parseTapeRoot(_ data: Data) throws -> RemoteTape {
        let object = try rootObject(from: data)
        guard let resource = object["data"] as? [String: Any] else {
            throw JSONAPIError.invalidResource
        }

        return try parseTape(resource)
    }

    static func parseTapeUploadSessionRoot(_ data: Data) throws -> TapeUploadSession {
        let object = try rootObject(from: data)
        guard let resource = object["data"] as? [String: Any] else {
            throw JSONAPIError.invalidResource
        }

        let tape = try parseTape(resource)
        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        let meta = object["meta"] as? [String: Any] ?? [:]
        let uploadObjects =
            meta["uploads"] as? [[String: Any]] ??
            attributes["upload-urls"] as? [[String: Any]] ??
            attributes["upload_urls"] as? [[String: Any]] ??
            []

        let uploadTargets = uploadObjects.compactMap(parseTapeUploadTarget)
        guard !uploadTargets.isEmpty else {
            throw JSONAPIError.missingTapeUploads
        }

        return TapeUploadSession(tape: tape, uploadTargets: uploadTargets)
    }

    static func parseTapeDownloadRoot(_ data: Data) throws -> URL {
        let object = try rootObject(from: data)

        if let urlString = object["download_url"] as? String ?? object["download-url"] as? String,
           let url = URL(string: urlString) {
            return url
        }

        if
            let links = object["links"] as? [String: Any],
            let url = link(named: "download", in: ["links": links])
        {
            return url
        }

        if let resource = object["data"] as? [String: Any],
           let url = link(named: "download", in: resource) {
            return url
        }

        throw JSONAPIError.missingDownloadURL
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

    private static func parsePack(
        _ resource: [String: Any],
        included: [[String: Any]],
        requiresPatches: Bool
    ) throws -> RemotePack {
        guard let id = resource["id"] as? String else {
            throw JSONAPIError.invalidResource
        }

        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        let name = attributes["name"] as? String ?? id
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

        if patches.isEmpty, requiresPatches {
            patches = try included
                .filter { ($0["type"] as? String) == "patches" }
                .map(parsePatch)
        }

        if requiresPatches, patches.isEmpty {
            throw JSONAPIError.missingPackPatches
        }

        return RemotePack(
            id: id,
            name: name,
            description: stringValue(named: "description", in: attributes),
            userID: stringValue(named: "user-id", in: attributes) ?? stringValue(named: "user_id", in: attributes),
            patches: patches,
            listedPatchCount: relationshipData.isEmpty ? nil : relationshipData.count,
            selfPath: apiPath(from: link(named: "self", in: resource)),
            downloadURL: link(named: "download", in: resource)
        )
    }

    private static func parseUser(_ object: [String: Any]) -> RemoteUser? {
        if let id = object["id"] as? String {
            let attributes = object["attributes"] as? [String: Any] ?? object
            return RemoteUser(
                id: id,
                username: stringValue(named: "username", in: attributes) ?? id
            )
        }

        guard let id = stringValue(named: "id", in: object) ?? stringValue(named: "slug", in: object) else {
            return nil
        }

        return RemoteUser(
            id: id,
            username: stringValue(named: "username", in: object) ?? id
        )
    }

    private static func parseTape(_ resource: [String: Any]) throws -> RemoteTape {
        guard let id = resource["id"] as? String else {
            throw JSONAPIError.invalidResource
        }

        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        let name = stringValue(named: "name", in: attributes) ?? "Tape #\(id)"
        let statusValue = stringValue(named: "status", in: attributes) ?? "unknown"
        let status = TapeStatus(rawValue: statusValue) ?? .unknown
        let fingerprint =
            stringValue(named: "fingerprint", in: attributes) ??
            stringValue(named: "tape-fingerprint", in: attributes) ??
            stringValue(named: "tape_fingerprint", in: attributes)

        return RemoteTape(
            id: id,
            name: name,
            status: status,
            createdAt: dateValue(named: "created-at", in: attributes) ?? dateValue(named: "created_at", in: attributes),
            updatedAt: dateValue(named: "updated-at", in: attributes) ?? dateValue(named: "updated_at", in: attributes),
            fingerprint: fingerprint,
            trackCount: intValue(named: "track-count", in: attributes) ?? intValue(named: "track_count", in: attributes) ?? 0,
            hasArchive: boolValue(named: "has-archive", in: attributes) ?? boolValue(named: "has_archive", in: attributes) ?? false,
            previewURL: link(named: "preview", in: resource),
            downloadURL: link(named: "download", in: resource)
        )
    }

    private static func parseTapeUploadTarget(_ object: [String: Any]) -> TapeUploadTarget? {
        guard
            let trackNumber = intValue(named: "track-number", in: object) ?? intValue(named: "track_number", in: object),
            let uploadURLString = stringValue(named: "upload-url", in: object) ?? stringValue(named: "upload_url", in: object),
            let uploadURL = URL(string: uploadURLString)
        else {
            return nil
        }

        return TapeUploadTarget(
            trackNumber: trackNumber,
            uploadURL: uploadURL,
            filename: stringValue(named: "filename", in: object) ?? "track_\(trackNumber).aif"
        )
    }

    private static func rootObject(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JSONAPIError.invalidResource
        }

        return object
    }

    private static func stringValue(named name: String, in object: [String: Any]) -> String? {
        object[name] as? String
    }

    private static func intValue(named name: String, in object: [String: Any]) -> Int? {
        if let value = object[name] as? Int {
            return value
        }

        if let value = object[name] as? String {
            return Int(value)
        }

        return nil
    }

    private static func boolValue(named name: String, in object: [String: Any]) -> Bool? {
        if let value = object[name] as? Bool {
            return value
        }

        if let value = object[name] as? String {
            return ["true", "1", "yes"].contains(value.lowercased())
        }

        return nil
    }

    private static func dateValue(named name: String, in object: [String: Any]) -> Date? {
        guard let value = object[name] as? String else {
            return nil
        }

        return ISO8601DateFormatter().date(from: value)
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

    private static func apiPath(from url: URL?) -> String? {
        guard let url else {
            return nil
        }

        let parts = url.path
            .split(separator: "/")
            .map(String.init)

        guard let index = parts.firstIndex(of: "v1") else {
            return url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        return parts[(index + 1)...].joined(separator: "/")
    }
}
