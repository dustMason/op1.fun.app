import AppKit
import Foundation

struct OP1DiskAssociation: Codable, Equatable, Identifiable {
    let id: String
    var displayName: String
    var lastPath: String
    var volumeUUID: String?
    var bookmarkData: Data?
    var folderBookmarks: [String: Data]?
    var associatedAt: Date
}

struct ScopedVolumeAccess {
    let url: URL
    private let scopedResources: [StartedSecurityScope]

    init(url: URL, didStartAccessing: Bool) {
        self.url = url
        self.scopedResources = [
            StartedSecurityScope(url: url, didStartAccessing: didStartAccessing)
        ]
    }

    fileprivate init(url: URL, scopedResources: [StartedSecurityScope]) {
        self.url = url
        self.scopedResources = scopedResources
    }

    func stop() {
        for resource in scopedResources where resource.didStartAccessing {
            resource.url.stopAccessingSecurityScopedResource()
        }
    }
}

fileprivate struct StartedSecurityScope {
    let url: URL
    let didStartAccessing: Bool
}

enum OP1VolumeAccessError: LocalizedError {
    case notConnected
    case invalidSelection
    case cancelled
    case notAssociated
    case bookmarkCreationFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Connect your OP-1 in disk mode, then try again."
        case .invalidSelection:
            return "The selected folder does not look like an OP-1 disk. Choose the disk that contains album, drum, synth, and tape."
        case .cancelled:
            return "OP-1 access was not granted."
        case .notAssociated:
            return "Select your OP-1 disk in op1.fun before saving patches."
        case .bookmarkCreationFailed:
            return "macOS did not grant lasting access to this OP-1 disk. Select the mounted OP-1 disk again."
        }
    }
}

@MainActor
final class OP1VolumeAccess {
    private let bookmarkListKey = "op1fun.op1VolumeBookmarks.v3"
    private static let requiredDirectoryNames = ["album", "drum", "synth", "tape"]
    private let defaults = UserDefaults.standard

    var associations: [OP1DiskAssociation] {
        loadAssociations()
    }

    func associateDisk() throws -> ScopedVolumeAccess {
        guard let selectedURL = requestAssociationURL() else {
            throw OP1VolumeAccessError.cancelled
        }

        let didStartAccessing = selectedURL.startAccessingSecurityScopedResource()

        guard OP1VolumeScanner.isOP1Volume(selectedURL) else {
            if didStartAccessing {
                selectedURL.stopAccessingSecurityScopedResource()
            }
            throw OP1VolumeAccessError.invalidSelection
        }

        do {
            try saveAssociation(for: selectedURL)
        } catch {
            if didStartAccessing {
                selectedURL.stopAccessingSecurityScopedResource()
            }

            throw error
        }

        return ScopedVolumeAccess(
            url: selectedURL,
            didStartAccessing: didStartAccessing
        )
    }

    func hasStoredAccess(for mountPoint: URL) -> Bool {
        guard let access = accessForMountedOP1(mountPoint) else {
            return false
        }

        access.stop()
        return true
    }

    func accessForMountedOP1(_ mountPoint: URL) -> ScopedVolumeAccess? {
        let mountPath = mountPoint.standardizedFileURL.path
        let mountUUID = Self.volumeUUID(for: mountPoint)

        for association in loadAssociations() {
            guard let access = access(for: association, mountedURL: mountPoint) else {
                continue
            }

            let accessPath = access.url.standardizedFileURL.path
            let accessUUID = Self.volumeUUID(for: access.url)
            let hasUUIDs = mountUUID != nil && association.volumeUUID != nil
            let uuidMatches = hasUUIDs && mountUUID == association.volumeUUID
            let bookmarkUUIDMatches = hasUUIDs && mountUUID == accessUUID
            let pathMatches = !hasUUIDs && (accessPath == mountPath || association.lastPath == mountPath)

            guard uuidMatches || bookmarkUUIDMatches || pathMatches else {
                access.stop()
                continue
            }

            guard OP1VolumeScanner.isOP1Volume(access.url) else {
                access.stop()
                continue
            }

            return access
        }

        return nil
    }

    func currentMountedAccess() -> ScopedVolumeAccess? {
        for association in loadAssociations() {
            guard let access = access(for: association) else {
                continue
            }

            if let storedUUID = association.volumeUUID,
               Self.volumeUUID(for: access.url) != storedUUID {
                access.stop()
                continue
            }

            guard FileManager.default.fileExists(atPath: access.url.path),
                  OP1VolumeScanner.isOP1Volume(access.url) else {
                access.stop()
                continue
            }

            return access
        }

        return nil
    }

    func removeAssociation(for mountPoint: URL) {
        let mountPath = mountPoint.standardizedFileURL.path
        let mountUUID = Self.volumeUUID(for: mountPoint)
        let remaining = loadAssociations().filter { association in
            if let mountUUID {
                return association.volumeUUID != mountUUID
            }

            if association.lastPath == mountPath {
                return false
            }

            return true
        }

        saveAssociations(remaining)
    }

    private func access(for association: OP1DiskAssociation, mountedURL selectedMountedURL: URL? = nil) -> ScopedVolumeAccess? {
        if let folderBookmarks = association.folderBookmarks,
           let access = resolveFolderBookmarks(
            folderBookmarks,
            association: association,
            mountedURL: selectedMountedURL
           ) {
            return access
        }

        if let bookmarkData = association.bookmarkData,
           let access = resolveBookmark(bookmarkData, association: association) {
            return access
        }

        guard association.bookmarkData?.isEmpty == false else {
            return nil
        }

        guard let url = selectedMountedURL ?? mountedURL(for: association) else {
            return nil
        }

        return ScopedVolumeAccess(
            url: url,
            didStartAccessing: url.startAccessingSecurityScopedResource()
        )
    }

    private func resolveBookmark(_ bookmarkData: Data, association: OP1DiskAssociation) -> ScopedVolumeAccess? {
        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            let access = ScopedVolumeAccess(
                url: url,
                didStartAccessing: url.startAccessingSecurityScopedResource()
            )

            if isStale {
                try? saveAssociation(for: access.url, existingID: association.id)
            }

            return access
        } catch {
            return nil
        }
    }

    private func resolveFolderBookmarks(
        _ folderBookmarks: [String: Data],
        association: OP1DiskAssociation,
        mountedURL selectedMountedURL: URL? = nil
    ) -> ScopedVolumeAccess? {
        var scopedResources: [StartedSecurityScope] = []
        var resolvedFolders: [URL] = []
        var bookmarkIsStale = false

        do {
            for directoryName in Self.requiredDirectoryNames {
                guard let bookmarkData = folderBookmarks[directoryName],
                      !bookmarkData.isEmpty else {
                    stop(resources: scopedResources)
                    return nil
                }

                var isStale = false
                let folderURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                scopedResources.append(
                    StartedSecurityScope(
                        url: folderURL,
                        didStartAccessing: folderURL.startAccessingSecurityScopedResource()
                    )
                )
                resolvedFolders.append(folderURL)
                bookmarkIsStale = bookmarkIsStale || isStale
            }
        } catch {
            stop(resources: scopedResources)
            return nil
        }

        guard let rootURL = selectedMountedURL?.standardizedFileURL ?? resolvedRootURL(from: resolvedFolders) else {
            stop(resources: scopedResources)
            return nil
        }

        if bookmarkIsStale {
            try? saveAssociation(for: rootURL, existingID: association.id)
        }

        return ScopedVolumeAccess(
            url: rootURL,
            scopedResources: scopedResources
        )
    }

    private func saveAssociation(for url: URL, existingID: String? = nil) throws {
        let standardizedURL = url.standardizedFileURL
        let folderBookmarks = try folderBookmarkData(for: url)
        let volumeUUID = Self.volumeUUID(for: standardizedURL)
        let id = existingID ?? volumeUUID ?? standardizedURL.path

        var associations = loadAssociations()
        let newAssociation = OP1DiskAssociation(
            id: id,
            displayName: standardizedURL.lastPathComponent,
            lastPath: standardizedURL.path,
            volumeUUID: volumeUUID,
            bookmarkData: nil,
            folderBookmarks: folderBookmarks,
            associatedAt: Date()
        )

        if let index = associations.firstIndex(where: { association in
            if association.id == id {
                return true
            }

            if let volumeUUID {
                return association.volumeUUID == volumeUUID
            }

            return association.volumeUUID == nil && association.lastPath == standardizedURL.path
        }) {
            associations[index] = newAssociation
        } else {
            associations.append(newAssociation)
        }

        saveAssociations(associations)
    }

    private func folderBookmarkData(for url: URL) throws -> [String: Data] {
        try Self.requiredDirectoryNames.reduce(into: [String: Data]()) { result, directoryName in
            let directoryURL = url.appendingPathComponent(directoryName, isDirectory: true)
            result[directoryName] = try securityScopedBookmarkData(for: directoryURL)
        }
    }

    private func securityScopedBookmarkData(for url: URL) throws -> Data {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        guard !data.isEmpty else {
            throw OP1VolumeAccessError.bookmarkCreationFailed
        }

        return data
    }

    private func mountedURL(for association: OP1DiskAssociation) -> URL? {
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.volumeUUIDStringKey]

        guard let mountedURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: resourceKeys,
            options: [.skipHiddenVolumes]
        ) else {
            return nil
        }

        if let volumeUUID = association.volumeUUID,
           let url = mountedURLs.first(where: { Self.volumeUUID(for: $0) == volumeUUID }) {
            return url.standardizedFileURL
        }

        return mountedURLs.first { url in
            url.standardizedFileURL.path == association.lastPath
        }?.standardizedFileURL
    }

    private func resolvedRootURL(from folderURLs: [URL]) -> URL? {
        folderURLs
            .map { $0.deletingLastPathComponent().standardizedFileURL }
            .first
    }

    private func stop(resources: [StartedSecurityScope]) {
        for resource in resources where resource.didStartAccessing {
            resource.url.stopAccessingSecurityScopedResource()
        }
    }

    private func loadAssociations() -> [OP1DiskAssociation] {
        guard let data = defaults.data(forKey: bookmarkListKey) else {
            return []
        }

        do {
            let associations = try PropertyListDecoder().decode([OP1DiskAssociation].self, from: data)
            let validAssociations = associations.filter { association in
                isUsableAssociation(association)
            }

            if validAssociations.count != associations.count {
                saveAssociations(validAssociations)
            }

            return validAssociations
        } catch {
            defaults.removeObject(forKey: bookmarkListKey)
            return []
        }
    }

    private func isUsableAssociation(_ association: OP1DiskAssociation) -> Bool {
        if let folderBookmarks = association.folderBookmarks,
           Self.requiredDirectoryNames.allSatisfy({ folderBookmarks[$0]?.isEmpty == false }) {
            return true
        }

        return association.bookmarkData?.isEmpty == false
    }

    private func saveAssociations(_ associations: [OP1DiskAssociation]) {
        do {
            let data = try PropertyListEncoder().encode(associations)
            defaults.set(data, forKey: bookmarkListKey)
        } catch {
            assertionFailure("Failed to save OP-1 disk associations: \(error)")
        }
    }

    private func requestAssociationURL() -> URL? {
        let panel = NSOpenPanel()

        panel.title = "Grant OP-1 Access"
        panel.message = "Choose the mounted OP-1 volume. macOS will grant op1.fun read/write access only through this standard file picker."
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        NSApp.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    private static func volumeUUID(for url: URL) -> String? {
        try? url.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString
    }
}
