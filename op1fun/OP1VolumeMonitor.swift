import Foundation

@MainActor
final class OP1VolumeMonitor: ObservableObject {
    @Published private(set) var mountPoint: URL?
    @Published private(set) var patches: [OP1Patch] = []
    @Published private(set) var isRefreshing = false

    var accessProvider: (() -> ScopedVolumeAccess?)?

    private var timer: Timer?

    var isConnected: Bool {
        mountPoint != nil
    }

    func start() {
        Task {
            await refreshNow()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshNow()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refreshNow() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        let access = accessProvider?()
        defer {
            access?.stop()
        }

        let preferredMountPoint = access?.url
        let snapshot = await Task.detached(priority: .userInitiated) {
            OP1VolumeScanner.scan(preferredMountPoint: preferredMountPoint)
        }.value

        mountPoint = snapshot.mountPoint
        patches = snapshot.patches
        isRefreshing = false
    }
}

struct OP1VolumeSnapshot {
    let mountPoint: URL?
    let patches: [OP1Patch]
}

enum OP1VolumeScanner {
    static func scan(preferredMountPoint: URL? = nil) -> OP1VolumeSnapshot {
        if let preferredMountPoint, isOP1Volume(preferredMountPoint) {
            return snapshot(for: preferredMountPoint)
        }

        guard let mountPoint = findMountPoint() else {
            return OP1VolumeSnapshot(mountPoint: nil, patches: [])
        }

        return snapshot(for: mountPoint)
    }

    private static func snapshot(for mountPoint: URL) -> OP1VolumeSnapshot {
        let patches = scanPatches(mountPoint: mountPoint)
            .sorted { $0.sortKey < $1.sortKey }

        return OP1VolumeSnapshot(mountPoint: mountPoint, patches: patches)
    }

    private static func findMountPoint() -> URL? {
        let fileManager = FileManager.default

        if let directURL = URL(string: "file:///Volumes/OP-1"), fileManager.fileExists(atPath: directURL.path) {
            return directURL
        }

        let resourceKeys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeLocalizedNameKey
        ]

        guard let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: resourceKeys,
            options: [.skipHiddenVolumes]
        ) else {
            return nil
        }

        if let namedOP1 = urls.first(where: { url in
            let values = try? url.resourceValues(forKeys: Set(resourceKeys))
            let names = [
                values?.volumeName,
                values?.volumeLocalizedName,
                url.lastPathComponent
            ]

            return names.contains { name in
                name?.localizedCaseInsensitiveContains("OP-1") == true
            }
        }) {
            return namedOP1
        }

        return urls.first(where: isOP1Volume)
    }

    static func isOP1Volume(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        let requiredDirectories = ["synth", "drum", "tape", "album"]

        return requiredDirectories.allSatisfy { name in
            var isDirectory: ObjCBool = false
            let path = url.appendingPathComponent(name, isDirectory: true).path
            return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    private static func scanPatches(mountPoint: URL) -> [OP1Patch] {
        let fileManager = FileManager.default
        var patches: [OP1Patch] = []

        for directoryName in ["synth", "drum"] {
            let directoryURL = mountPoint.appendingPathComponent(directoryName, isDirectory: true)
            guard fileManager.fileExists(atPath: directoryURL.path) else {
                continue
            }

            guard let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard !fileURL.lastPathComponent.hasPrefix(".") else {
                    continue
                }

                let relativeComponents = relativeComponents(for: fileURL, mountPoint: mountPoint)

                // Match the old app: recurse through synth/drum, but ignore OP-1 user preset slots.
                if relativeComponents.count > 1 && relativeComponents[1] == "user" {
                    if (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                    continue
                }

                if let patch = try? OP1PatchParser.parse(fileURL: fileURL, mountPoint: mountPoint) {
                    patches.append(patch)
                }
            }
        }

        return patches
    }

    private static func relativeComponents(for fileURL: URL, mountPoint: URL) -> [String] {
        let mountPath = mountPoint.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path

        guard filePath.hasPrefix(mountPath) else {
            return []
        }

        return filePath
            .dropFirst(mountPath.count)
            .split(separator: "/")
            .map(String.init)
    }
}
