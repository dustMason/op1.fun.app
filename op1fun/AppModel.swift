import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var currentView: AppView
    @Published var selectedCategory: PatchCategory = .synth
    @Published var loginError = ""
    @Published var isLoggingIn = false
    @Published var downloadStatus: String?
    @Published var message: String?
    @Published private(set) var associatedDisks: [OP1DiskAssociation]

    let monitor = OP1VolumeMonitor()
    var showPopover: (() -> Void)?

    private let apiClient = APIClient()
    private let tokenStore = CredentialStore()
    private let volumeAccess = OP1VolumeAccess()
    private var cancellables = Set<AnyCancellable>()
    private var pendingURL: URL?

    init() {
        currentView = tokenStore.isLoggedIn ? .browser : .login
        associatedDisks = volumeAccess.associations
        monitor.accessProvider = { [weak self] in
            self?.volumeAccess.currentMountedAccess()
        }

        monitor.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var email: String {
        tokenStore.email ?? ""
    }

    var isLoggedIn: Bool {
        tokenStore.isLoggedIn
    }

    var hasAssociatedDisks: Bool {
        !associatedDisks.isEmpty
    }

    var isConnectedOP1Associated: Bool {
        guard let mountPoint = monitor.mountPoint else {
            return false
        }

        return volumeAccess.hasStoredAccess(for: mountPoint)
    }

    func start() {
        monitor.start()
    }

    func stop() {
        monitor.stop()
    }

    func patches(for category: PatchCategory) -> [OP1Patch] {
        monitor.patches
            .filter { $0.category == category }
            .sorted { $0.sortKey < $1.sortKey }
    }

    func logIn(email: String, password: String) {
        loginError = ""
        isLoggingIn = true

        Task {
            do {
                let token = try await apiClient.logIn(email: email, password: password)
                tokenStore.email = email
                tokenStore.token = token
                isLoggingIn = false
                currentView = .browser
                message = nil

                Task {
                    try? await apiClient.enableAppFeatureFlag(email: email, token: token)
                }

                if let pendingURL {
                    self.pendingURL = nil
                    handleCompanionURL(pendingURL)
                }
            } catch {
                isLoggingIn = false
                loginError = error.localizedDescription
            }
        }
    }

    func logOut() {
        tokenStore.clear()
        currentView = .login
        loginError = ""
        message = nil
        pendingURL = nil
    }

    func refreshOP1() {
        Task {
            await monitor.refreshNow()
        }
    }

    func associateOP1Disk() {
        do {
            let access = try volumeAccess.associateDisk()
            access.stop()
            associatedDisks = volumeAccess.associations
            message = nil

            Task {
                await monitor.refreshNow()
            }
        } catch {
            if case OP1VolumeAccessError.cancelled = error {
                return
            }

            message = error.localizedDescription
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func showInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func handleCompanionURL(_ url: URL) {
        showPopover?()

        Task {
            await processCompanionURL(url)
        }
    }

    private func processCompanionURL(_ url: URL) async {
        guard let link = CompanionLink(url: url) else {
            message = "Unsupported op1.fun link."
            return
        }

        guard let email = tokenStore.email, let token = tokenStore.token else {
            pendingURL = url
            loginError = "Please login to download packs and patches."
            currentView = .login
            return
        }

        await monitor.refreshNow()

        guard let mountPoint = monitor.mountPoint else {
            message = "Connect your OP-1 in disk mode, then try again."
            return
        }

        guard let access = volumeAccess.accessForMountedOP1(mountPoint) else {
            message = "Select this OP-1 disk in op1.fun before saving patches."
            return
        }

        defer { access.stop() }

        do {
            switch link.resourceType {
            case "patches":
                let patch = try await apiClient.fetchPatch(path: link.path, email: email, token: token)
                try await download(patch: patch, packID: nil, mountPoint: access.url)
                message = "Downloaded \(patch.name)."

            case "packs":
                let pack = try await apiClient.fetchPack(path: link.path, email: email, token: token)
                downloadStatus = "Downloading Pack: \(pack.name)"

                for patch in pack.patches {
                    try await download(patch: patch, packID: pack.id, mountPoint: access.url)
                }

                downloadStatus = nil
                message = "Downloaded \(pack.name)."

            default:
                message = "Unsupported op1.fun link."
            }

            await monitor.refreshNow()
        } catch {
            downloadStatus = nil
            if isFilePermissionError(error) {
                volumeAccess.removeAssociation(for: mountPoint)
                associatedDisks = volumeAccess.associations
                message = "Permission for this OP-1 expired. Select the OP-1 disk again in op1.fun."
            } else {
                message = error.localizedDescription
            }
        }
    }

    private func download(patch: RemotePatch, packID: String?, mountPoint: URL) async throws {
        downloadStatus = "Downloading Patch: \(patch.name)"

        let categoryDirectory = patch.patchType == "drum" ? "drum" : "synth"
        var destinationDirectory = mountPoint.appendingPathComponent(categoryDirectory, isDirectory: true)

        if let packID {
            destinationDirectory.appendPathComponent(packID, isDirectory: true)
        }

        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )

        let (temporaryURL, response) = try await URLSession.shared.download(from: patch.fileURL)
        let filename = downloadFilename(for: patch, response: response)
        let destinationURL = availableDestinationURL(in: destinationDirectory, filename: filename)

        try FileManager.default.copyItem(at: temporaryURL, to: destinationURL)
        try? FileManager.default.removeItem(at: temporaryURL)
        downloadStatus = nil
    }

    private func downloadFilename(for patch: RemotePatch, response: URLResponse) -> String {
        let suggestedFilename = response.suggestedFilename ?? patch.fileURL.lastPathComponent
        let suggestedExtension = URL(fileURLWithPath: suggestedFilename).pathExtension
        let fallbackExtension = suggestedExtension.isEmpty ? "aif" : suggestedExtension
        let sanitizedName = sanitizedFileComponent(patch.name)
        let baseName = sanitizedName.isEmpty ? "patch" : sanitizedName
        let baseExtension = URL(fileURLWithPath: baseName).pathExtension.lowercased()

        if ["aif", "aiff", "aifc"].contains(baseExtension) {
            return baseName
        }

        return "\(baseName).\(fallbackExtension)"
    }

    private func availableDestinationURL(in directoryURL: URL, filename: String) -> URL {
        let originalURL = directoryURL.appendingPathComponent(filename, isDirectory: false)
        guard FileManager.default.fileExists(atPath: originalURL.path) else {
            return originalURL
        }

        let fileExtension = originalURL.pathExtension
        let baseName = fileExtension.isEmpty
            ? originalURL.deletingPathExtension().lastPathComponent
            : String(originalURL.lastPathComponent.dropLast(fileExtension.count + 1))

        var index = 2
        while true {
            let candidateFilename = fileExtension.isEmpty
                ? "\(baseName) \(index)"
                : "\(baseName) \(index).\(fileExtension)"
            let candidateURL = directoryURL.appendingPathComponent(candidateFilename, isDirectory: false)

            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            index += 1
        }
    }

    private func sanitizedFileComponent(_ value: String) -> String {
        let invalidScalars = CharacterSet(charactersIn: "/:")
            .union(.controlCharacters)

        return value
            .unicodeScalars
            .map { invalidScalars.contains($0) ? "-" : Character($0) }
            .reduce(into: "") { result, character in
                result.append(character)
            }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isFilePermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain {
            return [NSFileReadNoPermissionError, NSFileWriteNoPermissionError].contains(nsError.code)
        }

        if nsError.domain == NSPOSIXErrorDomain {
            return nsError.code == 1 || nsError.code == 13
        }

        return false
    }
}
