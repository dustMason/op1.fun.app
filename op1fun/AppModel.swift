import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var currentView: AppView
    @Published var selectedCategory: PatchCategory = .synth
    @Published var selectedSection: BrowserSection = .patch(.synth)
    @Published var loginError = ""
    @Published var isLoggingIn = false
    @Published var isLoadingTapes = false
    @Published var downloadStatus: String?
    @Published var message: String?
    @Published private(set) var tapes: [RemoteTape] = []
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
        refreshTapes()
    }

    func stop() {
        monitor.stop()
    }

    func patches(for category: PatchCategory) -> [OP1Patch] {
        monitor.patches
            .filter { $0.category == category }
            .sorted { $0.sortKey < $1.sortKey }
    }

    func selectPatchCategory(_ category: PatchCategory) {
        selectedCategory = category
        selectedSection = .patch(category)
    }

    func selectTapes() {
        selectedSection = .tapes
        refreshTapes()
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
                refreshTapes()

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
        tapes = []
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

    func refreshTapes() {
        guard let email = tokenStore.email, let token = tokenStore.token else {
            return
        }

        guard !isLoadingTapes else {
            return
        }

        isLoadingTapes = true
        Task {
            do {
                tapes = try await apiClient.fetchTapes(email: email, token: token)
                isLoadingTapes = false
            } catch {
                isLoadingTapes = false
                if selectedSection == .tapes {
                    message = error.localizedDescription
                }
            }
        }
    }

    func saveTapeFromOP1() {
        Task {
            do {
                _ = try await backUpCurrentTape()
                await monitor.refreshNow()
                refreshTapes()
            } catch {
                downloadStatus = nil
                message = error.localizedDescription
            }
        }
    }

    func loadTapeToOP1(_ tape: RemoteTape) {
        Task {
            do {
                try await loadTape(tape)
                await monitor.refreshNow()
                message = "Loaded \(tape.displayName) to OP-1."
            } catch {
                downloadStatus = nil
                message = error.localizedDescription
            }
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

    private func backUpCurrentTape() async throws -> RemoteTape {
        guard let email = tokenStore.email, let token = tokenStore.token else {
            throw APIClientError.missingCredentials
        }

        await monitor.refreshNow()

        guard let mountPoint = monitor.mountPoint else {
            throw OP1VolumeAccessError.notConnected
        }

        guard let access = volumeAccess.accessForMountedOP1(mountPoint) else {
            throw OP1VolumeAccessError.notAssociated
        }

        defer { access.stop() }

        let accessURL = access.url
        let snapshot = try await Task.detached(priority: .userInitiated) {
            try OP1TapeManager.snapshot(mountPoint: accessURL)
        }.value
        let name = defaultTapeBackupName()

        downloadStatus = "Creating Tape Backup"
        let session = try await apiClient.createTapeBackup(
            name: name,
            snapshot: snapshot,
            email: email,
            token: token
        )

        for target in session.uploadTargets.sorted(by: { $0.trackNumber < $1.trackNumber }) {
            guard let track = snapshot.tracks.first(where: { $0.trackNumber == target.trackNumber }) else {
                continue
            }

            downloadStatus = "Uploading Track \(target.trackNumber)"
            try await apiClient.uploadTapeTrack(track.url, to: target.uploadURL)
        }

        downloadStatus = "Processing Tape"
        let tape = try await apiClient.completeTapeBackup(
            id: session.tape.id,
            email: email,
            token: token
        )

        downloadStatus = nil
        upsertTape(tape)
        message = "Backed up \(snapshot.trackCount) OP-1 tape tracks."
        return tape
    }

    private func loadTape(_ tape: RemoteTape) async throws {
        guard let email = tokenStore.email, let token = tokenStore.token else {
            throw APIClientError.missingCredentials
        }

        await monitor.refreshNow()

        guard let mountPoint = monitor.mountPoint else {
            throw OP1VolumeAccessError.notConnected
        }

        guard let access = volumeAccess.accessForMountedOP1(mountPoint) else {
            throw OP1VolumeAccessError.notAssociated
        }

        defer { access.stop() }

        let accessURL = access.url

        if currentTapeNeedsBackup(mountPoint: accessURL) {
            switch confirmOverwriteUnbackedTape() {
            case .backUpFirst:
                _ = try await backUpCurrentTape()
                refreshTapes()
            case .overwrite:
                break
            case .cancel:
                return
            }
        }

        downloadStatus = "Downloading Tape"
        let downloadURL: URL
        if let existingDownloadURL = tape.downloadURL {
            downloadURL = existingDownloadURL
        } else {
            downloadURL = try await apiClient.fetchTapeDownloadURL(
                id: tape.id,
                email: email,
                token: token
            )
        }
        let (temporaryURL, _) = try await URLSession.shared.download(from: downloadURL)
        let archiveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("op1fun-\(UUID().uuidString).zip")
        try FileManager.default.moveItem(at: temporaryURL, to: archiveURL)
        defer {
            try? FileManager.default.removeItem(at: archiveURL)
        }

        downloadStatus = "Writing OP-1 Tape"
        try await Task.detached(priority: .userInitiated) {
            try OP1TapeManager.restore(archiveURL: archiveURL, to: accessURL)
        }.value

        downloadStatus = nil
    }

    private func currentTapeNeedsBackup(mountPoint: URL) -> Bool {
        guard let snapshot = try? OP1TapeManager.snapshot(mountPoint: mountPoint) else {
            return false
        }

        return !tapes.contains { tape in
            tape.fingerprint == snapshot.fingerprint
        }
    }

    private enum TapeOverwriteChoice {
        case backUpFirst
        case overwrite
        case cancel
    }

    private func confirmOverwriteUnbackedTape() -> TapeOverwriteChoice {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Overwrite OP-1 tape?"
        alert.informativeText = "The current OP-1 tape does not appear to be backed up to op1.fun. Loading this tape will replace the current OP-1 tape files."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Back Up First")
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .backUpFirst
        case .alertSecondButtonReturn:
            return .overwrite
        default:
            return .cancel
        }
    }

    private func defaultTapeBackupName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return "OP-1 Tape \(formatter.string(from: Date()))"
    }

    private func upsertTape(_ tape: RemoteTape) {
        if let index = tapes.firstIndex(where: { $0.id == tape.id }) {
            tapes[index] = tape
        } else {
            tapes.insert(tape, at: 0)
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
