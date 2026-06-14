import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.currentView == .login {
                LoginView(model: model)
            } else {
                BrowserView(model: model)
            }
        }
        .background(Color.op1Dark)
        .frame(width: 600, height: 420)
        .foregroundStyle(Color.op1LightGray)
        .font(.heebo(size: 13))
    }
}

private struct HeaderView: View {
    @ObservedObject var model: AppModel
    let title: String
    let showsBackButton: Bool

    var body: some View {
        HStack(spacing: 12) {
            if showsBackButton {
                Button {
                    model.currentView = .browser
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help("Back")
            }

            Text(title)
                .font(.heebo(size: 14, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            if let downloadStatus = model.downloadStatus {
                HStack(spacing: 6) {
                    Text(downloadStatus)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.65)
                }
                .frame(maxWidth: 260, alignment: .trailing)
            }

            if model.monitor.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.65)
            }

            Menu {
                Button("Account Settings") {
                    model.currentView = .login
                }

                Button("Refresh OP-1") {
                    model.refreshOP1()
                }

                Button("Select OP-1 Disk") {
                    model.associateOP1Disk()
                }

                Divider()

                Button("Quit") {
                    model.quit()
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Color.op1Dark)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(height: 1)
        }
    }
}

private struct LoginView: View {
    @ObservedObject var model: AppModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                model: model,
                title: "op1.fun.app",
                showsBackButton: model.isLoggedIn
            )

            HStack(alignment: .top, spacing: 34) {
                VStack(alignment: .leading, spacing: 12) {
                    OP1BundleImage("op1")
                        .frame(width: 108, height: 42)

                    Text("op1.fun.app")
                        .font(.heebo(size: 23, weight: .bold))
                        .foregroundStyle(.white)

                    Text("v 1.0")
                        .font(.heebo(size: 13))
                }
                .frame(width: 210, alignment: .leading)

                VStack(alignment: .leading, spacing: 18) {
                    if model.isLoggedIn {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Logged in as")
                                .labelStyleText()
                            Text(model.email)
                                .foregroundStyle(.white)
                                .textSelection(.enabled)
                        }

                        Button("Log Out") {
                            model.logOut()
                        }
                        .primaryOP1Button()
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .labelStyleText()
                            TextField("", text: $email)
                                .textFieldStyle(.plain)
                                .fieldStyle()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .labelStyleText()
                            SecureField("", text: $password)
                                .textFieldStyle(.plain)
                                .fieldStyle()
                        }

                        if !model.loginError.isEmpty {
                            Text(model.loginError)
                                .foregroundStyle(Color.op1Red)
                                .font(.heebo(size: 12, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button(model.isLoggingIn ? "Logging In" : "Log In") {
                            model.logIn(email: email, password: password)
                        }
                        .primaryOP1Button()
                        .disabled(model.isLoggingIn || email.isEmpty || password.isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(EdgeInsets(top: 58, leading: 44, bottom: 32, trailing: 44))

            Spacer()
        }
        .onAppear {
            email = model.email
        }
    }
}

private struct BrowserView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(model: model, title: "op1.fun", showsBackButton: false)

            VStack(spacing: 0) {
                if !model.hasAssociatedDisks {
                    DiskAssociationView(model: model, state: .noAssociatedDisks)
                } else if !model.monitor.isConnected {
                    DiskAssociationView(model: model, state: .noConnectedDisk)
                } else if !model.isConnectedOP1Associated {
                    DiskAssociationView(model: model, state: .unassociatedConnectedDisk)
                } else {
                    HStack(spacing: 0) {
                        SidebarView(model: model)

                        Rectangle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 1)

                        PatchListView(
                            model: model,
                            patches: model.patches(for: model.selectedCategory)
                        )
                    }
                }

                if let message = model.message {
                    Text(message)
                        .font(.heebo(size: 12))
                        .foregroundStyle(Color.op1LightGray)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.18))
                }
            }
        }
    }
}

private enum DiskAssociationState {
    case noAssociatedDisks
    case noConnectedDisk
    case unassociatedConnectedDisk
}

private struct DiskAssociationView: View {
    @ObservedObject var model: AppModel
    let state: DiskAssociationState

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 62, weight: .light))
                .foregroundStyle(Color.op1LightGray.opacity(0.9))

            VStack(spacing: 7) {
                Text(title)
                    .font(.heebo(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                if let detail {
                    Text(detail)
                        .font(.heebo(size: 13))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.op1LightGray)
                        .frame(maxWidth: 340)
                }
            }

            Button("Select OP-1 Disk") {
                model.associateOP1Disk()
            }
            .primaryOP1Button()

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconName: String {
        switch state {
        case .noAssociatedDisks, .unassociatedConnectedDisk:
            return "externaldrive.badge.plus"
        case .noConnectedDisk:
            return "cable.connector"
        }
    }

    private var title: String {
        switch state {
        case .noAssociatedDisks:
            return "Select your OP-1 disk"
        case .noConnectedDisk:
            return "No OP-1 connected"
        case .unassociatedConnectedDisk:
            return "New OP-1 detected"
        }
    }

    private var detail: String? {
        switch state {
        case .noAssociatedDisks:
            return nil
        case .noConnectedDisk:
            return nil
        case .unassociatedConnectedDisk:
            if let mountPoint = model.monitor.mountPoint {
                return "\(mountPoint.lastPathComponent) looks like an OP-1, but it has not been associated with op1.fun yet."
            }

            return "This OP-1 has not been associated with op1.fun yet."
        }
    }
}

private struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(PatchCategory.allCases) { category in
                Button {
                    model.selectedCategory = category
                } label: {
                    HStack(spacing: 10) {
                        OP1CategoryIcon(category: category, color: sidebarForeground(for: category))
                            .frame(width: 22, height: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.title)
                                .font(.heebo(size: 20, weight: .light))
                                .textCase(.uppercase)

                            Text("\(model.patches(for: category).count) of \(category.limit)")
                                .font(.heebo(size: 12))
                                .foregroundStyle(sidebarSubtitleColor(for: category))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 66)
                    .foregroundStyle(sidebarForeground(for: category))
                    .background(sidebarBackground(for: category))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
            }

            Spacer()
        }
        .frame(width: 200)
    }

    private func sidebarBackground(for category: PatchCategory) -> Color {
        guard model.selectedCategory == category else {
            return .clear
        }

        switch category {
        case .synth: return .op1Blue
        case .drum: return .op1Green
        case .sampler: return .white
        }
    }

    private func sidebarForeground(for category: PatchCategory) -> Color {
        if model.selectedCategory == category {
            return category == .sampler ? .op1Black : .white
        }

        return category.tint
    }

    private func sidebarSubtitleColor(for category: PatchCategory) -> Color {
        if model.selectedCategory == category {
            return category == .sampler ? .op1Black.opacity(0.7) : .white.opacity(0.78)
        }

        return .op1LightGray
    }
}

private struct PatchListView: View {
    @ObservedObject var model: AppModel
    let patches: [OP1Patch]

    var body: some View {
        Group {
            if patches.isEmpty {
                ConnectedEmptyView(model: model)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(patches.groupedByPack()) { group in
                            if let packName = group.packName, let packDirectory = group.packDirectory {
                                Button {
                                    if let mountPoint = model.monitor.mountPoint {
                                        model.showInFinder(mountPoint.appendingPathComponent(packDirectory))
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        OP1FolderIcon()
                                            .stroke(model.selectedCategory.tint, lineWidth: 1)
                                            .frame(width: 15, height: 15)
                                        Text(packName)
                                            .font(.heebo(size: 14, weight: .medium))
                                            .textCase(.uppercase)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                    }
                                    .foregroundStyle(model.selectedCategory.tint)
                                    .padding(.horizontal, 10)
                                    .frame(height: 30)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .rowSeparator()
                            }

                            ForEach(group.patches) { patch in
                                Button {
                                    model.showInFinder(patch.url)
                                } label: {
                                    Text(patch.name)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, group.packName == nil ? 10 : 34)
                                        .padding(.trailing, 10)
                                        .frame(height: 27)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PatchRowButtonStyle())
                                .rowSeparator()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ConnectedEmptyView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 15) {
            Spacer()

            Image(systemName: "externaldrive")
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(Color.op1LightGray.opacity(0.9))

            VStack(spacing: 6) {
                Text("OP-1 connected")
                    .font(.heebo(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text(statusText)
                    .font(.heebo(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.op1LightGray)
                    .frame(maxWidth: 300)
            }

            if let mountPoint = model.monitor.mountPoint {
                Button("Open OP-1") {
                    model.showInFinder(mountPoint)
                }
                .primaryOP1Button()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusText: String {
        let categoryName = model.selectedCategory.title.lowercased()

        if let mountPoint = model.monitor.mountPoint {
            return "Mounted as \(mountPoint.lastPathComponent). No \(categoryName) patches found outside the user folder."
        }

        return "No \(categoryName) patches found outside the user folder."
    }
}

private struct DisconnectedView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            OP1BundleImage("op1-com")
                .frame(width: 240, height: 78)

            Text("Please connect your OP-1 and put it in disk mode.")
                .font(.heebo(size: 16, weight: .thin))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.op1LightGray)
                .frame(maxWidth: 280)

            Button("Retry") {
                model.refreshOP1()
            }
            .primaryOP1Button()

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PatchRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Color.op1Black : Color.op1LightGray)
            .background(configuration.isPressed ? Color.op1LightGray : Color.clear)
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(Color.op1Field)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(Color.op1LightGray)
    }

    func labelStyleText() -> some View {
        self
            .font(.heebo(size: 14))
            .textCase(.uppercase)
            .foregroundStyle(Color.op1LightGray)
    }

    func primaryOP1Button() -> some View {
        self
            .buttonStyle(OP1PrimaryButtonStyle())
    }

    func rowSeparator() -> some View {
        self
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
            }
    }
}

private struct OP1PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.heebo(size: 20))
            .textCase(.uppercase)
            .foregroundStyle(foregroundColor(configuration: configuration))
            .padding(.horizontal, 24)
            .frame(height: 42)
            .background(backgroundColor(configuration: configuration))
            .overlay {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.op1Green.opacity(isEnabled ? 1 : 0.45), lineWidth: 3)
            }
    }

    private func foregroundColor(configuration: Configuration) -> Color {
        if !isEnabled {
            return Color.op1Green.opacity(0.45)
        }

        return configuration.isPressed ? Color.op1Black : Color.op1Green
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        guard isEnabled, configuration.isPressed else {
            return .clear
        }

        return .op1Green
    }
}

extension Color {
    static let op1Blue = Color(red: 0.412, green: 0.557, blue: 1.0)
    static let op1Green = Color(red: 0.016, green: 0.796, blue: 0.506)
    static let op1Red = Color(red: 1.0, green: 0.227, blue: 0.365)
    static let op1Dark = Color(red: 0.145, green: 0.145, blue: 0.173)
    static let op1Black = Color(red: 0.224, green: 0.227, blue: 0.271)
    static let op1LightGray = Color(red: 0.792, green: 0.808, blue: 0.839)
    static let op1Field = Color(red: 0.282, green: 0.282, blue: 0.325)
}
