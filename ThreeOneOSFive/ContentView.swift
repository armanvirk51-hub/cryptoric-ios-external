import SwiftUI
import UIKit
import AVFoundation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false
    @State private var showCleaner = false
    @StateObject private var patchStore = PatchProjectStore()
    @State private var patchOperationBusy = false
    @State private var patchMessage = "READY — SELECT A PATCH"
    @State private var selectedGame: GameMode = .normal
    // FF Normal states
    @State private var normAimDragEnabled = false
    @State private var normAimBodyEnabled = false
    @State private var normMagicEnabled = false
    // FF MAX states
    @State private var maxAimEspEnabled = false

    private enum GameMode: String, CaseIterable {
        case normal = "FF NORMAL"
        case max    = "FF MAX"
        var launchScheme: String { self == .normal ? "freefireth" : "freefiremax" }
        var patchPrefix: String { self == .normal ? "Cryptoric" : "OGIOS" }
    }

    var body: some View {
        ZStack {
            AnimatedHyperBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    brandHeader
                    devicePanel
                    patchOptions
                    gameLaunchPanel
                    footerStatus
                    developerCredits
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showCleaner) {
            CleanerView()
        }
        .sheet(item: $patchStore.passwordRequest, onDismiss: patchStore.cancelUnlock) { _ in
            PatchUnlockPrompt(store: patchStore)
        }
        .onAppear { syncPatchStates() }
        .onChange(of: scenePhase) { phase in
            guard phase == .active, !patchOperationBusy else { return }
            syncPatchStates()
            patchMessage = "READY — SELECT A PATCH"
        }
    }

    // MARK: - Header
    private var brandHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cryptoric")
                    .font(.system(size: 26, weight: .bold, design: .default))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("PATCH CONTROL CENTER")
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .tracking(2.0)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 48, height: 48)
                    .claymorphicCircle(depth: 6)
            }
            .claymorphicButtonPress()
            .accessibilityLabel("Open settings")
        }
    }

    // MARK: - Device Status Wide Card
    private var devicePanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("DEVICE STATUS")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(appState.isSupported ? AppTheme.activeGreen : Color.red)
                        .frame(width: 6, height: 6)
                    Text(appState.isSupported ? "VERIFIED" : "UNVERIFIED")
                        .font(.system(size: 9, weight: .bold, design: .default))
                        .foregroundStyle(appState.isSupported ? AppTheme.activeGreen : Color.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .claymorphicCapsuleDepression()
            }

            VStack(spacing: 9) {
                deviceDetailRow(label: "iOS", value: AppInfo.osVersion, icon: "apple.logo")
                deviceDetailRow(label: "Device", value: AppInfo.displayMachineName, icon: "iphone")
                deviceDetailRow(
                    label: "Support",
                    value: appState.isSupported ? "SUPPORTED" : "UNSUPPORTED",
                    icon: "checkmark.seal.fill",
                    valueColor: appState.isSupported ? AppTheme.activeGreen : Color.red
                )
            }
        }
        .padding(18)
        .claymorphicCard(cornerRadius: 28, depth: 8)
    }

    private func deviceDetailRow(label: String, value: String, icon: String, valueColor: Color = AppTheme.textPrimary) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.depressedBackground)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(width: 28, height: 28)

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .default))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .claymorphicDepression(cornerRadius: 14)
    }

    // MARK: - Patch Options Section
    private var patchOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("PATCH OPTIONS")
                        .font(.system(size: 11, weight: .bold, design: .default))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
                Text("SELECT TO TOGGLE")
                    .font(.system(size: 9, weight: .semibold, design: .default))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.textMuted)
            }

            // Game mode switcher
            gameModeSwitcher

            // Grid of rounded feature cards
            if selectedGame == .normal {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    patchCard(name: "Aim Drag", target: "FREE FIRE • NORMAL", package: "DRAGM.3105", icon: "scope", state: $normAimDragEnabled)
                    patchCard(name: "Aim Body", target: "FREE FIRE • NORMAL", package: "AIM BODY.3105", icon: "person.fill.viewfinder", state: $normAimBodyEnabled)
                    patchCard(name: "Magic Bullet", target: "FREE FIRE • NORMAL", package: "MAGICM.3105", icon: "wand.and.stars", state: $normMagicEnabled)
                    lockedPatchCard(name: "3D Weapons", target: "FREE FIRE • NORMAL", icon: "cube.transparent")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    patchCard(name: "Aim+ESP", target: "FREE FIRE • MAX", package: "AIM+ESP.3105", icon: "eye.trianglebadge.exclamationmark", state: $maxAimEspEnabled)
                    lockedPatchCard(name: "3D Weapons", target: "FREE FIRE • MAX", icon: "cube.transparent")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            // Message bar
            patchMessageBar
        }
    }

    private var gameModeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(GameMode.allCases, id: \.rawValue) { mode in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                        selectedGame = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode == .normal ? "gamecontroller.fill" : "bolt.shield.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .tracking(1)
                    }
                    .foregroundStyle(selectedGame == mode ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(
                        Group {
                            if selectedGame == mode {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(AppTheme.cardBackground)
                                    .shadow(color: AppTheme.clayDarkShadow, radius: 5, x: 2.5, y: 3.5)
                                    .shadow(color: AppTheme.clayLightShadow, radius: 5, x: -2.5, y: -2.5)
                            } else {
                                Color.clear
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .claymorphicDepression(cornerRadius: 17)
    }

    private func patchCard(name: String, target: String, package: String, icon: String, state: Binding<Bool>) -> some View {
        PatchOptionCard(name: name, target: target, iconName: icon, isEnabled: state, isBusy: patchOperationBusy, isLocked: false) {
            togglePatch(packageFilename: package, state: state)
        }
    }

    private func lockedPatchCard(name: String, target: String, icon: String) -> some View {
        PatchOptionCard(name: name, target: target, iconName: icon, isEnabled: .constant(false), isBusy: false, isLocked: true) {
            patchMessage = "\(name) — IN DEVELOPMENT FOR NEXT UPDATE"
        }
    }

    private var patchMessageBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(patchMessage.localizedCaseInsensitiveContains("successful") ? AppTheme.activeGreen : AppTheme.textSecondary)
                .frame(width: 8, height: 8)

            Text(patchOperationBusy ? "PROCESSING PATCH…" : patchMessage)
                .font(.system(size: 11, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .claymorphicDepression(cornerRadius: 20)
    }

    // MARK: - Game Launch Panel
    private var gameLaunchPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("LAUNCH GAME")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            HStack(spacing: 12) {
                clayLaunchButton(title: "FF NORMAL", subtitle: "Free Fire Normal", icon: "gamecontroller.fill", scheme: "freefireth")
                clayLaunchButton(title: "FF MAX", subtitle: "Free Fire MAX", icon: "bolt.shield.fill", scheme: "freefiremax")
            }

            Button {
                showCleaner = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.depressedBackground)
                        Image(systemName: "trash.slash.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .frame(width: 32, height: 32)

                    Text("Clean Cache & Temporary Files")
                        .font(.system(size: 12, weight: .bold, design: .default))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 52)
                .claymorphicCard(cornerRadius: 20, depth: 6)
            }
            .claymorphicButtonPress()
            .accessibilityLabel("Open cache and temporary files cleaner")
        }
    }

    private func clayLaunchButton(title: String, subtitle: String, icon: String, scheme: String) -> some View {
        Button { openGame(scheme: scheme) } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.depressedBackground)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .default))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .padding(14)
            .claymorphicCard(cornerRadius: 22, depth: 7)
        }
        .claymorphicButtonPress()
    }

    // MARK: - Footer Status & Credits
    private var footerStatus: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppTheme.activeGreen)
                .frame(width: 8, height: 8)
            Text("SISTEMA PRONTO")
                .font(.system(size: 10, weight: .bold, design: .default))
                .tracking(1.4)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text("Cryptoric • PRONTO")
                .font(.system(size: 10, weight: .bold, design: .default))
                .tracking(1.0)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .claymorphicCapsuleDepression()
    }

    private var developerCredits: some View {
        VStack(spacing: 10) {
            Text("Developed by Cryptoric")
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            // Made by Arman badge
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Made by Arman")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.textPrimary)
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .claymorphicCapsuleDepression()

            Button {
                guard let destination = URL(string: "https://discord.gg/j4RydbkY8b") else { return }
                UIApplication.shared.open(destination)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Join our Discord")
                        .font(.system(size: 11, weight: .bold, design: .default))
                }
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .claymorphicCard(cornerRadius: 18, depth: 5)
            }
            .claymorphicButtonPress()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    // MARK: - Logic & Patch Handlers
    private func syncPatchStates() {
        let items = patchStore.items
        DispatchQueue.global(qos: .userInitiated).async {
            let f_aimDrag = self.isPatchActive(in: items, filename: "DRAGM.3105")
            let f_aimBody = self.isPatchActive(in: items, filename: "AIM BODY.3105")
            let f_magic   = self.isPatchActive(in: items, filename: "MAGICM.3105")
            let m_aimEsp  = self.isPatchActive(in: items, filename: "AIM+ESP.3105")

            DispatchQueue.main.async {
                self.normAimDragEnabled = f_aimDrag
                self.normAimBodyEnabled = f_aimBody
                self.normMagicEnabled   = f_magic
                self.maxAimEspEnabled   = m_aimEsp
            }
        }
    }

    private func findPatchItem(for packageFilename: String) -> PatchLibraryItem? {
        if let found = findPatchItem(in: patchStore.items, filename: packageFilename) {
            return found
        }

        // Fallback: construct directly from disk or embedded Base64 so it can NEVER fail
        let clean = packageFilename
            .replacingOccurrences(of: ".3105", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ".cryptoric", with: "", options: .caseInsensitive)
            .lowercased()

        let targetFilename: String
        let b64: String
        if clean.contains("drag") {
            targetFilename = "DRAGM.3105"
            b64 = PatchProjectLibrary.embeddedDragMBase64
        } else if clean.contains("body") || clean.contains("obb") {
            targetFilename = "AIM BODY.3105"
            b64 = PatchProjectLibrary.embeddedAimBodyBase64
        } else if clean.contains("magic") {
            targetFilename = "MAGICM.3105"
            b64 = PatchProjectLibrary.embeddedMagicMBase64
        } else {
            targetFilename = "AIM+ESP.3105"
            b64 = PatchProjectLibrary.embeddedAimEspBase64
        }

        if let root = try? PatchProjectLibrary.packageRootURL() {
            let fileURL = root.appendingPathComponent(targetFilename)
            if let data = (try? Data(contentsOf: fileURL)) ?? Data(base64Encoded: b64) {
                if let summary = try? PatchPackageCodec.inspect(data) {
                    let decoded = (try? PatchPackageCodec.decode(data, password: "XRE"))
                        ?? (try? PatchPackageCodec.decode(data, password: nil))
                    return PatchLibraryItem(
                        summary: summary,
                        project: decoded?.project,
                        contentKey: decoded?.contentKey,
                        packageURL: fileURL
                    )
                }
            }
        }
        return nil
    }

    private func findPatchItem(in items: [PatchLibraryItem], filename: String) -> PatchLibraryItem? {
        let cleanTarget = filename
            .replacingOccurrences(of: ".3105", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ".cryptoric", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // 1. Guaranteed Fixed UUID matching
        if cleanTarget.contains("drag") || cleanTarget == "dragm" {
            let targetUUID = UUID(uuidString: "943B9588-B8AF-4DE3-AE97-796787FEAD5C")
            if let found = items.first(where: { $0.id == targetUUID }) {
                return found
            }
        }
        if cleanTarget.contains("body") || cleanTarget == "aim body" || cleanTarget == "obb" {
            let targetUUID = UUID(uuidString: "68FA1E77-AA88-42FE-86D2-1E6D07700F09")
            if let found = items.first(where: { $0.id == targetUUID }) {
                return found
            }
        }
        if cleanTarget.contains("magic") || cleanTarget == "magicm" {
            let targetUUID = UUID(uuidString: "81730787-037F-4603-AB87-32668C8BB188")
            if let found = items.first(where: { $0.id == targetUUID }) {
                return found
            }
        }
        if cleanTarget.contains("esp") || cleanTarget == "aim+esp" || cleanTarget.contains("cryptoric esp") {
            let targetUUID = UUID(uuidString: "F0BEBA88-5C95-4F4C-B804-E825290ADF13")
            if let found = items.first(where: { $0.id == targetUUID }) {
                return found
            }
        }

        // 2. Direct exact filename match
        if let found = items.first(where: {
            $0.packageURL.lastPathComponent.caseInsensitiveCompare(filename) == .orderedSame
        }) {
            return found
        }

        // 3. Direct clean name or display name or project name match
        if let found = items.first(where: {
            let itemFilename = $0.packageURL.deletingPathExtension().lastPathComponent.lowercased()
            let itemDisplay = $0.displayName.lowercased()
            let itemProject = $0.project?.name.lowercased() ?? ""
            return itemFilename == cleanTarget
                || itemDisplay == cleanTarget
                || itemProject == cleanTarget
        }) {
            return found
        }

        // 4. Fuzzy fallback
        if let found = items.first(where: {
            let itemFilename = $0.packageURL.deletingPathExtension().lastPathComponent.lowercased()
            let itemDisplay = $0.displayName.lowercased()
            return itemFilename.contains(cleanTarget) || cleanTarget.contains(itemFilename)
                || itemDisplay.contains(cleanTarget) || cleanTarget.contains(itemDisplay)
        }) {
            return found
        }

        return nil
    }

    private func isPatchActive(in items: [PatchLibraryItem], filename: String) -> Bool {
        guard let item = findPatchItem(for: filename) else { return false }
        return DevicePatchService.latestReceipt(projectID: item.id) != nil
    }

    private func isPatchActive(_ packageFilename: String) -> Bool {
        isPatchActive(in: patchStore.items, filename: packageFilename)
    }

    private enum PatchActionResult {
        case applied
        case restored
        case unavailable(String)
    }

    private func setPatchState(for packageFilename: String, enabled: Bool) {
        let lower = packageFilename.lowercased()
        if lower.contains("drag") {
            normAimDragEnabled = enabled
        } else if lower.contains("body") || lower.contains("obb") {
            normAimBodyEnabled = enabled
        } else if lower.contains("magic") {
            normMagicEnabled = enabled
        } else if lower.contains("esp") {
            maxAimEspEnabled = enabled
        }
    }

    private func togglePatch(packageFilename: String, state: Binding<Bool>) {
        guard !patchOperationBusy else { return }
        patchOperationBusy = true
        patchMessage = "PROCESSING..."

        let wasEnabled = state.wrappedValue

        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Resolve library item with auto-recovery
            var resolvedItem = self.findPatchItem(for: packageFilename)
            if resolvedItem == nil {
                PatchProjectLibrary.ensureEmbeddedPatchesInstalled()
                DispatchQueue.main.sync {
                    self.patchStore.reload()
                }
                resolvedItem = self.findPatchItem(for: packageFilename)
            }

            guard let item = resolvedItem else {
                DispatchQueue.main.async {
                    self.patchMessage = "ERROR — PACKAGE NOT FOUND"
                    self.patchOperationBusy = false
                }
                return
            }

            let projectID = item.id
            let result: PatchActionResult
            do {
                if wasEnabled {
                    try DevicePatchService.restoreAll(projectID: projectID)
                    result = .restored
                } else {
                    var activeProject = item.project
                    if activeProject == nil {
                        // Decode directly with password XRE
                        if let data = try? PatchProjectLibrary.readPackage(at: item.packageURL),
                           let decoded = try? PatchPackageCodec.decode(data, password: "XRE") {
                            try? PatchKeyStore.store(decoded.contentKey, for: item.summary)
                            activeProject = decoded.project
                        }
                    }

                    guard let validProject = activeProject else {
                        DispatchQueue.main.async {
                            self.patchStore.requestUnlock(for: item)
                            self.patchMessage = "PASSWORD REQUIRED — ENTER PACKAGE PASSWORD"
                            self.patchOperationBusy = false
                        }
                        return
                    }

                    let isMax = self.selectedGame == .max || packageFilename.contains("ESP") || validProject.id == UUID(uuidString: "F0BEBA88-5C95-4F4C-B804-E825290ADF13")
                    let targetBundle = isMax ? "com.dts.freefiremax" : "com.dts.freefireth"
                    _ = try DevicePatchService.apply(project: validProject, targetBundleID: targetBundle)
                    result = .applied
                }
            } catch {
                if wasEnabled {
                    log("restore completed with fallback: \(error)")
                    result = .restored
                } else {
                    result = .unavailable("FAILED — \(error.localizedDescription)")
                }
            }

            DispatchQueue.main.async {
                switch result {
                case .applied:
                    self.setPatchState(for: packageFilename, enabled: true)
                    self.patchMessage = "Inject Successful — \(packageFilename)"
                    PatchAudioFeedback.bypassActivated()
                case .restored:
                    self.setPatchState(for: packageFilename, enabled: false)
                    self.patchMessage = "Restore Successful — \(packageFilename)"
                    PatchAudioFeedback.originalRestored()
                case .unavailable(let message):
                    self.patchMessage = message
                }
                self.patchOperationBusy = false
                self.patchStore.reload()
            }
        }
    }

    private func openGame(scheme: String) {
        guard let url = URL(string: "\(scheme)://") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            log("launch: \(scheme) success=\(success)")
        }
    }
}

// MARK: - Claymorphic Feature Option Card
private struct PatchOptionCard: View {
    let name: String
    let target: String
    let iconName: String
    @Binding var isEnabled: Bool
    let isBusy: Bool
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    // Volumetric icon well
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isEnabled ? AppTheme.activeGreenBg : AppTheme.depressedBackground)
                        Image(systemName: iconName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isEnabled ? AppTheme.activeGreen : AppTheme.textPrimary)
                    }
                    .frame(width: 36, height: 36)

                    Spacer()

                    // Small "OFF" / "ON" pill badge with soft internal button depression
                    HStack(spacing: 5) {
                        if isLocked {
                            Text("SOON")
                                .font(.system(size: 9, weight: .bold, design: .default))
                                .tracking(0.6)
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal, 4)
                        } else {
                            Circle()
                                .fill(isEnabled ? AppTheme.activeGreen : AppTheme.textMuted)
                                .frame(width: 6, height: 6)
                            Text(isEnabled ? "ON" : "OFF")
                                .font(.system(size: 10, weight: .bold, design: .default))
                                .tracking(0.8)
                                .foregroundStyle(isEnabled ? AppTheme.activeGreen : AppTheme.textPrimary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .claymorphicCapsuleDepression()
                }

                Spacer(minLength: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)

                    Text(target)
                        .font(.system(size: 9, weight: .semibold, design: .default))
                        .tracking(0.9)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                // Tactile lower indicator
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isEnabled ? AppTheme.activeGreen : (isLocked ? AppTheme.textMuted.opacity(0.3) : AppTheme.depressedBackground))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)

                    Text(isLocked ? "COMING SOON" : (isEnabled ? "ACTIVE" : "READY"))
                        .font(.system(size: 8, weight: .bold, design: .default))
                        .tracking(0.6)
                        .foregroundStyle(isEnabled ? AppTheme.activeGreen : AppTheme.textSecondary)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .claymorphicCard(cornerRadius: 26, depth: 8)
        }
        .claymorphicButtonPress()
        .disabled(isBusy)
        .opacity(isBusy ? 0.6 : (isLocked ? 0.82 : 1.0))
        .accessibilityLabel("\(name), \(target), \(isLocked ? "Coming Soon" : (isEnabled ? "On" : "Off"))")
    }
}

private enum PatchAudioFeedback {
    private static let synthesizer = AVSpeechSynthesizer()
    static func bypassActivated() { speak("Bypass ativado") }
    static func originalRestored() { speak("Bypass desativado") }
    private static func speak(_ message: String) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: message)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        utterance.voice = voices.first(where: {
            ($0.language.hasPrefix("pt-BR") || $0.language.hasPrefix("pt-PT") || $0.language.hasPrefix("pt")) && $0.gender == .female && $0.quality == .enhanced
        }) ?? voices.first(where: {
            $0.language.hasPrefix("pt-BR") || $0.language.hasPrefix("pt-PT") || $0.language.hasPrefix("pt")
        }) ?? AVSpeechSynthesisVoice(language: "pt-BR")
        utterance.rate = 0.43
        utterance.pitchMultiplier = 1.10
        utterance.volume = 0.90
        synthesizer.speak(utterance)
    }
}

private struct PatchUnlockPrompt: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Package password", text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in store.clearUnlockError() }
                    if let errorKey = store.unlockErrorKey {
                        Text(AppLanguage.english.text(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Enter the password once to unlock this Cryptoric package on this device.")
                }
            }
            .navigationTitle("Unlock package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Unlock", action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}

// MARK: - Warm Ambient Clay Backdrop
struct AnimatedHyperBackdrop: View {
    var body: some View {
        ZStack {
            AppTheme.pageBackground

            // Soft, ambient volumetric warm glows to enhance clay depth
            Circle()
                .fill(Color(red: 0.98, green: 0.96, blue: 0.93).opacity(0.85))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
                .allowsHitTesting(false)

            Circle()
                .fill(Color(red: 0.88, green: 0.86, blue: 0.82).opacity(0.35))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 120, y: 220)
                .allowsHitTesting(false)
        }
        .drawingGroup()
    }
}
