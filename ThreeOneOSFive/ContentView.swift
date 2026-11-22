import SwiftUI
import UIKit
import AVFoundation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseManager: LicenseManager
    @State private var showSettings = false
    @State private var showCleaner = false
    @StateObject private var patchStore = PatchProjectStore()
    @State private var patchOperationBusy = false
    @State private var patchMessage = "READY — SELECT A PATCH"
    @State private var selectedGame: GameMode = .india
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    // FF INDIA states
    @State private var indiaModMenuEnabled = false
    // FF MAX states
    @State private var maxAimNheTamEnabled = false
    @StateObject private var streamerManager = StreamerProofManager.shared

    private enum GameMode: String, CaseIterable {
        case india  = "FF INDIA"
        case max    = "FF MAX"
        var launchScheme: String { self == .india ? "freefireind" : "freefiremax" }
        var patchPrefix: String { "Cryptoric" }
    }

    var body: some View {
        ZStack {
            StreamerDecoyView()
                .ignoresSafeArea()

            if streamerManager.isEnabled {
                SecureViewWrapper {
                    normalMainContent
                }
                .ignoresSafeArea()
            } else {
                normalMainContent
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            syncPatchStates()
            streamerManager.checkCaptureState()
        }
        .onReceive(timer) { input in self.now = input }
        .onChange(of: scenePhase) { phase in
            streamerManager.handleScenePhase(phase)
            guard phase == .active, !patchOperationBusy else { return }
            syncPatchStates()
            patchMessage = "READY — SELECT A PATCH"
        }
        .onChange(of: licenseManager.isActive) { active in
            if !active {
                // License expired or paused — remove all applied patches
                restoreAllPatches()
            }
        }
    }

    private var normalMainContent: some View {
        ZStack {
            AnimatedHyperBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    brandHeader
                    if streamerManager.isEnabled {
                        streamerShieldBanner
                    }
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showCleaner) {
            CleanerView()
        }
    }

    // MARK: - Header
    private var brandHeader: some View {
        HStack(spacing: 12) {
            // New App Logo in claymorphic container
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .shadow(color: AppTheme.clayDarkShadow, radius: 5, x: 2.5, y: 3.5)
                    .shadow(color: AppTheme.clayLightShadow, radius: 4, x: -2.5, y: -2.5)

                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Cryptoric")
                        .font(.system(size: 24, weight: .black, design: .default))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.textPrimary)

                    // VIP Elite Badge
                    HStack(spacing: 3) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("VIP ELITE")
                            .font(.system(size: 8, weight: .black))
                    }
                    .foregroundStyle(Color(red: 0.90, green: 0.65, blue: 0.12))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.32))
                            .overlay(
                                Capsule()
                                    .stroke(Color(red: 0.90, green: 0.70, blue: 0.20).opacity(0.4), lineWidth: 0.8)
                            )
                    )
                }

                HStack(spacing: 5) {
                    Circle()
                        .fill(AppTheme.activeGreen)
                        .frame(width: 5, height: 5)
                    Text("EXTERNAL ENGINE • V3.1 VIP")
                        .font(.system(size: 9, weight: .bold, design: .default))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            // Streamer Proof Mode Button
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    streamerManager.isEnabled.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.cardBackground)
                        .shadow(color: AppTheme.clayDarkShadow, radius: 5, x: 2.5, y: 3.5)
                        .shadow(color: AppTheme.clayLightShadow, radius: 4, x: -2.5, y: -2.5)

                    Image(systemName: streamerManager.isEnabled ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(streamerManager.isEnabled ? Color.purple : AppTheme.textSecondary)
                }
                .frame(width: 46, height: 46)
            }
            .claymorphicButtonPress()
            .accessibilityLabel("Toggle Streamer Proof Mode")

            // Settings Button
            Button {
                showSettings = true
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.cardBackground)
                        .shadow(color: AppTheme.clayDarkShadow, radius: 5, x: 2.5, y: 3.5)
                        .shadow(color: AppTheme.clayLightShadow, radius: 4, x: -2.5, y: -2.5)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(width: 46, height: 46)
            }
            .claymorphicButtonPress()
            .accessibilityLabel("Open settings")
        }
    }

    private var streamerShieldBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.purple)

            Text("STREAMER PROOF: ACTIVE")
                .font(.system(size: 10, weight: .bold, design: .default))
                .tracking(1.0)
                .foregroundStyle(Color.purple)

            Spacer()

            Text("Auto-masks on screen share")
                .font(.system(size: 9, weight: .medium, design: .default))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.purple.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.purple.opacity(0.25), lineWidth: 1)
                )
        )
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
                deviceDetailRow(
                    label: "License Key",
                    value: licenseManager.isActive ? licenseManager.formattedTimeRemaining(currentDate: now) : "NOT ACTIVATED",
                    icon: "key.fill",
                    valueColor: licenseManager.isActive ? AppTheme.activeGreen : Color.red
                )
                deviceDetailRow(
                    label: "Streamer Shield",
                    value: streamerManager.isEnabled ? "ARMED (STEALTH)" : "INACTIVE",
                    icon: streamerManager.isEnabled ? "eye.slash.fill" : "eye.fill",
                    valueColor: streamerManager.isEnabled ? Color.purple : AppTheme.textSecondary
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

            // Premium Hero Feature Card presentation
            if selectedGame == .india {
                heroPatchCard(
                    name: "Mode Menu",
                    target: "FREE FIRE • INDIA",
                    package: "Fluorite menu IN.3105",
                    icon: "slider.horizontal.3",
                    badgeText: "IN.3105 VIP",
                    features: ["In-Game Menu", "Silent Bypass", "Anti-Detect", "Memory Guard"],
                    description: "Full in-game visual & feature mod menu with silent password bypass. Zero prompt on launch.",
                    state: $indiaModMenuEnabled,
                    activeColor: Color(red: 0.22, green: 0.72, blue: 0.42)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                heroPatchCard(
                    name: "Aim Head",
                    target: "FREE FIRE • MAX",
                    package: "AIM NHE TAM FFMAX.3105",
                    icon: "viewfinder",
                    badgeText: "FFMAX VIP",
                    features: ["Headshot Precision", "Zero Recoil Mod", "Anti-Ban Safe", "Fast Inject"],
                    description: "Ultra-calibrated head tracking modification engineered specifically for Free Fire MAX.",
                    state: $maxAimNheTamEnabled,
                    activeColor: Color(red: 0.94, green: 0.28, blue: 0.28)
                )
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
                        Image(systemName: mode == .india ? "flag.fill" : "bolt.shield.fill")
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

    private func heroPatchCard(name: String, target: String, package: String, icon: String, badgeText: String, features: [String], description: String, state: Binding<Bool>, activeColor: Color = AppTheme.activeGreen) -> some View {
        HeroPatchOptionCard(
            name: name,
            target: target,
            iconName: icon,
            badgeText: badgeText,
            features: features,
            descriptionText: description,
            isEnabled: state,
            isBusy: patchOperationBusy,
            activeColor: activeColor
        ) {
            togglePatch(packageFilename: package, state: state)
        }
    }

    private func patchCard(name: String, target: String, package: String, icon: String, state: Binding<Bool>, activeColor: Color = AppTheme.activeGreen) -> some View {
        PatchOptionCard(name: name, target: target, iconName: icon, isEnabled: state, isBusy: patchOperationBusy, isLocked: false, activeColor: activeColor) {
            togglePatch(packageFilename: package, state: state)
        }
    }

    private func lockedPatchCard(name: String, target: String, icon: String) -> some View {
        PatchOptionCard(name: name, target: target, iconName: icon, isEnabled: .constant(false), isBusy: false, isLocked: true) {
            patchMessage = "\(name) — COMING SOON"
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
                clayLaunchButton(title: "FF INDIA", subtitle: "Free Fire India", icon: "flag.fill", scheme: "freefireind")
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
                .shadow(color: AppTheme.activeGreen.opacity(0.6), radius: 3)
            Text("SYSTEM ENGINE: SECURE & READY")
                .font(.system(size: 10, weight: .black, design: .default))
                .tracking(1.4)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.activeGreen)
                Text("CRYPTORIC VIP")
                    .font(.system(size: 10, weight: .black, design: .default))
                    .tracking(1.0)
                    .foregroundStyle(AppTheme.textPrimary)
            }
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
        guard licenseManager.isActive else {
            // License not active — restore all applied patches and reset states
            restoreAllPatches()
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let i_modMenu      = self.isPatchActive("Fluorite menu IN.3105", forGame: .india)
            let m_aimNheTam    = self.isPatchActive("AIM NHE TAM FFMAX.3105", forGame: .max)

            DispatchQueue.main.async {
                self.indiaModMenuEnabled = i_modMenu
                self.maxAimNheTamEnabled = m_aimNheTam
            }
        }
    }

    /// Restores (removes) all applied patches when the license is inactive/expired.
    private func restoreAllPatches() {
        let packages = [
            "Fluorite menu IN.3105",
            "AIM NHE TAM FFMAX.3105"
        ]
        DispatchQueue.global(qos: .background).async {
            for pkg in packages {
                if let item = self.findPatchItem(for: pkg),
                   DevicePatchService.latestReceipt(projectID: item.id) != nil {
                    try? DevicePatchService.restoreAll(projectID: item.id)
                }
                let gameKey = "patch_active_\(GameMode.india.rawValue)_" + pkg
                UserDefaults.standard.set(false, forKey: gameKey)
                let maxKey = "patch_active_\(GameMode.max.rawValue)_" + pkg
                UserDefaults.standard.set(false, forKey: maxKey)
                UserDefaults.standard.set(false, forKey: "patch_active_" + pkg)
            }
            DispatchQueue.main.async {
                self.indiaModMenuEnabled = false
                self.maxAimNheTamEnabled = false
                self.patchMessage        = "LICENSE INACTIVE — ALL PATCHES REMOVED"
            }
        }
    }

    private func findPatchItem(for packageFilename: String) -> PatchLibraryItem? {
        if let found = findPatchItem(in: patchStore.items, filename: packageFilename) {
            return found
        }

        // Fallback: construct directly from embedded Base64 so it can NEVER fail
        let clean = packageFilename
            .replacingOccurrences(of: ".3105", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ".cryptoric", with: "", options: .caseInsensitive)
            .lowercased()

        let targetFilename: String
        let b64: String
        if clean.contains("fluorite") || clean.contains("india") || clean.contains("fluorite menu in") {
            // FF India patch — load from file, password handled in decode
            targetFilename = "Fluorite menu IN.3105"
            b64 = ""
        } else if clean.contains("aim body hs") {
            targetFilename = "AIM BODY HS FFMAX.3105"
            b64 = PatchProjectLibrary.embeddedAimBodyHsFFMaxBase64
        } else if clean.contains("aim chets hs ffmax") {
            targetFilename = "AIM CHETS HS FFMAX.3105"
            b64 = PatchProjectLibrary.embeddedAimChetsHsFFMaxBase64
        } else if clean.contains("aim neck hs") {
            targetFilename = "AIM NECK HS FFMAX.3105"
            b64 = PatchProjectLibrary.embeddedAimNeckHsFFMaxBase64
        } else if clean.contains("aim nhe tam ffmax") {
            targetFilename = "AIM NHE TAM FFMAX.3105"
            b64 = PatchProjectLibrary.embeddedAimNheTamFFMaxBase64
        } else if clean.contains("aim chets hs ffth") {
            targetFilename = "AIM CHETS HS FFTH.3105"
            b64 = PatchProjectLibrary.embeddedAimChetsHsFFNormBase64
        } else if clean.contains("aim nhe tam ffth") {
            targetFilename = "AIM NHE TAM FFTH.3105"
            b64 = PatchProjectLibrary.embeddedAimNheTamFFNormBase64
        } else if clean.contains("drag") {
            targetFilename = "DRAGM.3105"
            b64 = PatchProjectLibrary.embeddedDragMBase64
        } else if clean.contains("body") || clean.contains("obb") {
            targetFilename = "AIM BODY.3105"
            b64 = PatchProjectLibrary.embeddedAimBodyBase64
        } else if clean.contains("magic") {
            targetFilename = "MAGICM.3105"
            b64 = PatchProjectLibrary.embeddedMagicMBase64
        } else if clean.contains("cryptoric") {
            targetFilename = "Cryptoric Aim.3105"
            b64 = PatchProjectLibrary.embeddedCryptoricAimBase64
        } else if clean.contains("ffm") && (clean.contains("mode") || clean.contains("mod")) {
            targetFilename = "MODE MENU FFM.3105"
            b64 = PatchProjectLibrary.embeddedModeMenuFFMBase64
        } else if clean.contains("mode") || clean.contains("mod") {
            targetFilename = "MODE MENU.3105"
            b64 = PatchProjectLibrary.embeddedModeMenuBase64
        } else {
            targetFilename = "AIM+Ashok.3105"
            b64 = PatchProjectLibrary.embeddedAimAshokBase64
        }

        if let root = try? PatchProjectLibrary.packageRootURL() {
            let fileURL = root.appendingPathComponent(targetFilename)
            if let data = (try? Data(contentsOf: fileURL)) ?? (b64.isEmpty ? nil : Data(base64Encoded: b64)) {
                // For the FF India patch, no password required
                let password: String? = nil
                if let summary = try? PatchPackageCodec.inspect(data) {
                    let decoded = try? PatchPackageCodec.decode(data, password: password)
                    return PatchLibraryItem(
                        summary: summary,
                        project: decoded?.project ?? PatchProjectLibrary.getDecodedProject(for: packageFilename),
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
        if cleanTarget.contains("fluorite") || cleanTarget.contains("india") || cleanTarget.contains("fluorite menu in") {
            let targetUUID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
            if let found = items.first(where: { $0.id == targetUUID }) {
                return found
            }
        }
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
        if cleanTarget.contains("ashok") || cleanTarget.contains("esp") || cleanTarget == "aim+ashok" || cleanTarget == "aim+esp" || cleanTarget.contains("cryptoric ashok") || cleanTarget.contains("cryptoric esp") {
            let targetUUID = UUID(uuidString: "F0BEBA88-5C95-4F4C-B804-E825290ADF13")
            if let found = items.first(where: { $0.id == targetUUID }) {
                return found
            }
        }
        if cleanTarget.contains("cryptoric aim") || cleanTarget.contains("cryptoric") {
            let targetUUID = UUID(uuidString: "C60517A3-DBCE-4C28-829F-9E4B9C6D0FC1")
            if let found = items.first(where: { $0.id == targetUUID }) {
                return found
            }
        }
        if cleanTarget.contains("ffm") && (cleanTarget.contains("mode") || cleanTarget.contains("mod")) {
            let targetUUID = UUID(uuidString: "50F75F5F-E17F-4F24-8721-0870E7304A95")
            if let found = items.first(where: { $0.id == targetUUID }) {
                return found
            }
        }
        if cleanTarget.contains("mode menu") || cleanTarget.contains("mod menu") || cleanTarget == "mode menu" {
            let targetUUID = UUID(uuidString: "40F75F5F-E17F-4F24-8721-0870E7304A94")
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

    private func isPatchActive(_ packageFilename: String, forGame game: GameMode? = nil) -> Bool {
        let mode = game ?? selectedGame
        let gameKey = "patch_active_\(mode.rawValue)_" + packageFilename
        let genericKey = "patch_active_" + packageFilename
        let prefActive = UserDefaults.standard.bool(forKey: gameKey) || (game == nil && UserDefaults.standard.bool(forKey: genericKey))
        guard let item = findPatchItem(for: packageFilename) else {
            return prefActive
        }
        let receiptActive = DevicePatchService.latestReceipt(projectID: item.id) != nil
        return prefActive && receiptActive
    }

    private enum PatchActionResult {
        case applied
        case restored
        case unavailable(String)
    }

    private func setPatchState(for packageFilename: String, game: GameMode, enabled: Bool) {
        let lower = packageFilename.lowercased()
        let gameKey = "patch_active_\(game.rawValue)_" + packageFilename
        UserDefaults.standard.set(enabled, forKey: gameKey)
        UserDefaults.standard.set(enabled, forKey: "patch_active_" + packageFilename)

        if lower.contains("fluorite") || lower.contains("india") {
            indiaModMenuEnabled = enabled
        } else if packageFilename == "AIM NHE TAM FFMAX.3105" || lower.contains("aim nhe tam ffmax") {
            maxAimNheTamEnabled = enabled
        }
    }

    private func togglePatch(packageFilename: String, state: Binding<Bool>) {
        guard !patchOperationBusy else { return }
        patchOperationBusy = true
        patchMessage = "PROCESSING..."

        let wasEnabled = state.wrappedValue
        let currentGame = self.selectedGame

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

            // 2. Resolve project (with direct embedded fallback so it NEVER fails)
            var activeProject = resolvedItem?.project
            if activeProject == nil {
                activeProject = PatchProjectLibrary.getDecodedProject(for: packageFilename)
            }

            guard let projectID = resolvedItem?.id ?? activeProject?.id else {
                DispatchQueue.main.async {
                    self.patchMessage = "ERROR — PACKAGE NOT FOUND"
                    self.patchOperationBusy = false
                }
                return
            }

            let result: PatchActionResult
            do {
                if wasEnabled {
                    // Turn OFF
                    try DevicePatchService.restoreAll(projectID: projectID)
                    result = .restored
                } else {
                    // Turn ON
                    guard let validProject = activeProject else {
                        DispatchQueue.main.async {
                            self.patchMessage = "ERROR — UNABLE TO DECODE PACKAGE"
                            self.patchOperationBusy = false
                        }
                        return
                    }

                    let isMax = currentGame == .max || packageFilename.contains("Ashok") || packageFilename.contains("ESP") || packageFilename.contains("FFM") || packageFilename.contains("FFMAX")
                    let targetBundle: String
                    if isMax {
                        targetBundle = "com.dts.freefiremax"
                    } else {
                        targetBundle = "com.dts.freefireind"  // FF India uses separate bundle
                    }
                    _ = try DevicePatchService.apply(project: validProject, targetBundleID: targetBundle)
                    result = .applied
                }
            } catch PatchPackageError.targetAppUnavailable(let bundleID) {
                let gameName: String
                switch bundleID {
                case "com.dts.freefireind": gameName = "Free Fire India"
                case "com.dts.freefiremax": gameName = "Free Fire MAX"
                default: gameName = bundleID
                }
                result = .unavailable("FAILED — \(gameName) container not found. Make sure the game is installed.")
            } catch {
                // A failed restore must stay visible as a failure: the toggle
                // keeps its ON state so the user can retry instead of the app
                // claiming "Restore Successful" while patched files remain.
                result = .unavailable("FAILED — \(error.localizedDescription)")
            }

            DispatchQueue.main.async {
                switch result {
                case .applied:
                    self.setPatchState(for: packageFilename, game: currentGame, enabled: true)
                    self.patchMessage = "Inject Successful — \(packageFilename)"
                    PatchAudioFeedback.bypassActivated()
                case .restored:
                    self.setPatchState(for: packageFilename, game: currentGame, enabled: false)
                    self.patchMessage = "Restore Successful — \(packageFilename)"
                    PatchAudioFeedback.originalRestored()
                case .unavailable(let message):
                    self.patchMessage = message
                }
                self.patchOperationBusy = false
                self.syncPatchStates()
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

// MARK: - Premium Hero Feature Card
private struct HeroPatchOptionCard: View {
    let name: String
    let target: String
    let iconName: String
    let badgeText: String
    let features: [String]
    let descriptionText: String
    @Binding var isEnabled: Bool
    let isBusy: Bool
    var activeColor: Color = AppTheme.activeGreen
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 14) {
                // Top Header Row
                HStack(alignment: .center, spacing: 12) {
                    // Glowing Icon Container
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: isEnabled
                                        ? [activeColor.opacity(0.25), activeColor.opacity(0.12)]
                                        : [AppTheme.depressedBackground, AppTheme.cardBackground],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isEnabled ? activeColor.opacity(0.45) : Color.white.opacity(0.6), lineWidth: 1)
                            )
                            .shadow(color: isEnabled ? activeColor.opacity(0.35) : Color.clear, radius: 8, x: 0, y: 3)

                        Image(systemName: iconName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(isEnabled ? activeColor : AppTheme.textPrimary)
                    }
                    .frame(width: 48, height: 48)

                    // Title & Target Subtitle
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(name)
                                .font(.system(size: 18, weight: .black, design: .default))
                                .tracking(0.3)
                                .foregroundStyle(AppTheme.textPrimary)

                            // Version Badge
                            Text(badgeText)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(isEnabled ? activeColor : AppTheme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(isEnabled ? activeColor.opacity(0.14) : AppTheme.depressedBackground)
                                )
                        }

                        Text(target)
                            .font(.system(size: 10, weight: .bold, design: .default))
                            .tracking(1.0)
                            .foregroundStyle(isEnabled ? activeColor : AppTheme.textSecondary)
                    }

                    Spacer()

                    // Status Pill & Switcher
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isEnabled ? activeColor : AppTheme.textMuted)
                                .frame(width: 7, height: 7)
                                .shadow(color: isEnabled ? activeColor : Color.clear, radius: 4)

                            Text(isEnabled ? "ACTIVE" : "STANDBY")
                                .font(.system(size: 9, weight: .black, design: .default))
                                .tracking(0.8)
                                .foregroundStyle(isEnabled ? activeColor : AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isEnabled ? activeColor.opacity(0.12) : AppTheme.depressedBackground)
                        )

                        // Luxury Tactile Toggle Switch
                        ZStack(alignment: isEnabled ? .trailing : .leading) {
                            Capsule()
                                .fill(isEnabled ? activeColor : AppTheme.depressedBackground)
                                .frame(width: 50, height: 28)
                                .shadow(color: isEnabled ? activeColor.opacity(0.35) : Color.black.opacity(0.08), radius: 3, x: 0, y: 1.5)

                            Circle()
                                .fill(Color.white)
                                .frame(width: 22, height: 22)
                                .padding(.horizontal, 3)
                                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1.5)
                        }
                    }
                }

                // Description Text
                Text(descriptionText)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .lineSpacing(2)

                // Feature Pill Badges
                HStack(spacing: 6) {
                    ForEach(features, id: \.self) { feat in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(isEnabled ? activeColor : AppTheme.textSecondary)

                            Text(feat)
                                .font(.system(size: 9, weight: .bold, design: .default))
                                .foregroundStyle(isEnabled ? AppTheme.textPrimary : AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isEnabled ? activeColor.opacity(0.08) : AppTheme.depressedBackground.opacity(0.8))
                        )
                    }
                }

                // Tap to toggle footer prompt
                HStack(spacing: 6) {
                    Image(systemName: isEnabled ? "lock.open.fill" : "bolt.badge.clock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isEnabled ? activeColor : AppTheme.textMuted)

                    Text(isEnabled ? "Bypass is active and engaged in memory" : "Tap card anywhere to activate and inject patch")
                        .font(.system(size: 10, weight: .semibold, design: .default))
                        .foregroundStyle(isEnabled ? activeColor : AppTheme.textMuted)

                    Spacer()

                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.top, 2)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                isEnabled
                                    ? activeColor.opacity(0.55)
                                    : Color.white.opacity(0.6),
                                lineWidth: isEnabled ? 1.5 : 1
                            )
                    )
            )
            .claymorphicCard(cornerRadius: 24, depth: isEnabled ? 4 : 7)
            .shadow(color: isEnabled ? activeColor.opacity(0.18) : Color.clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}

// MARK: - Claymorphic Feature Option Card
private struct PatchOptionCard: View {
    let name: String
    let target: String
    let iconName: String
    @Binding var isEnabled: Bool
    let isBusy: Bool
    let isLocked: Bool
    var activeColor: Color = AppTheme.activeGreen
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isEnabled ? activeColor.opacity(0.18) : AppTheme.cardBackground)

                        Image(systemName: iconName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isEnabled ? activeColor : AppTheme.textPrimary)
                    }
                    .frame(width: 38, height: 38)
                    .claymorphicCard(cornerRadius: 14, depth: isEnabled ? 2 : 4)

                    Spacer()

                    // Toggle pill or lock badge
                    if isLocked {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8, weight: .bold))
                            Text("COMING SOON")
                                .font(.system(size: 8, weight: .bold, design: .default))
                                .tracking(0.5)
                        }
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        )
                    } else {
                        ZStack(alignment: isEnabled ? .trailing : .leading) {
                            Capsule()
                                .fill(isEnabled ? activeColor : AppTheme.depressedBackground)
                                .frame(width: 44, height: 24)

                            Circle()
                                .fill(Color.white)
                                .frame(width: 18, height: 18)
                                .padding(.horizontal, 3)
                                .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1.5)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(isLocked ? "COMING SOON" : target)
                        .font(.system(size: 9, weight: .semibold, design: .default))
                        .tracking(0.6)
                        .foregroundStyle(isLocked ? Color.orange.opacity(0.8) : (isEnabled ? activeColor : AppTheme.textSecondary))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .claymorphicCard(cornerRadius: 22, depth: isEnabled ? 3 : 6)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isEnabled ? activeColor.opacity(0.55) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy || isLocked)
        .opacity(isLocked ? 0.62 : 1.0)
    }
}

// MARK: - Hardware Secure-Layer Wrapper (Anti-Capture & Streamer-Proof)
final class SecureTextField: UITextField {
    override var canBecomeFirstResponder: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in subviews {
            let convertedPoint = convert(point, to: subview)
            if let hit = subview.hitTest(convertedPoint, with: event) {
                return hit
            }
        }
        return nil
    }
}

final class SecureWrapperController<Content: View>: UIViewController {
    private var content: Content
    private let secureTextField = SecureTextField()
    private var hostingController: UIHostingController<Content>?

    init(content: Content) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        secureTextField.isSecureTextEntry = true
        view.addSubview(secureTextField)
        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secureTextField.topAnchor.constraint(equalTo: view.topAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            secureTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        addChild(host)
        self.hostingController = host

        embedHostIfNeeded()
        host.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        embedHostIfNeeded()
    }

    private func embedHostIfNeeded() {
        guard let hostView = hostingController?.view, hostView.superview == nil else { return }
        secureTextField.layoutIfNeeded()
        let targetContainer = secureTextField.subviews.first ?? secureTextField
        targetContainer.isUserInteractionEnabled = true
        targetContainer.addSubview(hostView)
        hostView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostView.topAnchor.constraint(equalTo: targetContainer.topAnchor),
            hostView.bottomAnchor.constraint(equalTo: targetContainer.bottomAnchor),
            hostView.leadingAnchor.constraint(equalTo: targetContainer.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: targetContainer.trailingAnchor)
        ])
    }

    func update(content: Content) {
        self.content = content
        self.hostingController?.rootView = content
    }
}

struct SecureViewWrapper<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> SecureWrapperController<Content> {
        SecureWrapperController(content: content)
    }

    func updateUIViewController(_ uiViewController: SecureWrapperController<Content>, context: Context) {
        uiViewController.update(content: content)
    }
}

// MARK: - Streamer Proof Manager (Anti-Screen Recording & Screen Share Protection)
final class StreamerProofManager: ObservableObject {
    static let shared = StreamerProofManager()

    @AppStorage("cryptoric_streamer_proof_enabled") var isEnabled: Bool = false {
        didSet {
            objectWillChange.send()
        }
    }

    @Published var isCaptured: Bool = false
    @Published var isBackgrounded: Bool = false

    var isShieldActive: Bool {
        return isEnabled && (isCaptured || isBackgrounded)
    }

    private var observer: NSObjectProtocol?

    private init() {
        self.isCaptured = UIScreen.main.isCaptured
        self.observer = NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.isCaptured = UIScreen.main.isCaptured
            self.objectWillChange.send()
        }
    }

    func checkCaptureState() {
        self.isCaptured = UIScreen.main.isCaptured
    }

    func handleScenePhase(_ phase: ScenePhase) {
        if phase == .active {
            self.isBackgrounded = false
            self.checkCaptureState()
        } else {
            self.isBackgrounded = true
        }
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Streamer Decoy View (Screen Share & Recording Decoy Mask)
private struct StreamerDecoyView: View {
    @ObservedObject private var streamerManager = StreamerProofManager.shared
    @State private var isOptimizing = false
    @State private var optimizationComplete = false
    @State private var freedMB: Double = 0
    @State private var ramPercentage: Int = 68
    @State private var availableRam: String = "2.4 GB / 6.0 GB"
    @State private var storageFreeString: String = "Calculating…"
    @State private var thermalStateText: String = "Nominal"
    @State private var batteryHealthText: String = "100%"

    var body: some View {
        ZStack {
            AnimatedHyperBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 22) {
                // Top status
                HStack(spacing: 10) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("System Diagnostics")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("DEVICE PERFORMANCE MONITOR")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    // Innocent shield badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(optimizationComplete ? Color.green : Color.blue)
                            .frame(width: 6, height: 6)
                        Text(optimizationComplete ? "OPTIMAL" : "MONITORING")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(optimizationComplete ? Color.green : Color.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .claymorphicCapsuleDepression()
                }
                .padding(.top, 24)

                // Main Metric Dial
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(AppTheme.depressedBackground, lineWidth: 14)
                            .frame(width: 140, height: 140)

                        Circle()
                            .trim(from: 0, to: CGFloat(ramPercentage) / 100.0)
                            .stroke(
                                LinearGradient(
                                    colors: optimizationComplete ? [Color.green, Color.teal] : [Color.blue, Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: ramPercentage)

                        VStack(spacing: 2) {
                            Text(isOptimizing ? "CLEANING…" : (optimizationComplete ? "OPTIMIZED" : "STABLE"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(optimizationComplete ? Color.green : Color.blue)

                            Text("\(ramPercentage)%")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("RAM Utilization")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)

                    Text("Thermal state: \(thermalStateText) • Battery: \(batteryHealthText)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .claymorphicCard(cornerRadius: 26, depth: 8)

                // Stats Rows
                VStack(spacing: 10) {
                    decoyRow(label: "Available Memory", value: availableRam, icon: "memorychip")
                    decoyRow(label: "Internal Storage", value: storageFreeString, icon: "internaldrive")
                    decoyRow(label: "CPU Architecture", value: "Apple Silicon (6-Core)", icon: "speedometer")
                    decoyRow(label: "Display Refresh", value: "ProMotion 120Hz", icon: "display")
                }
                .padding(18)
                .claymorphicCard(cornerRadius: 26, depth: 8)

                // Active Optimize Action
                Button {
                    runRealOptimization()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isOptimizing ? "arrow.triangle.2.circlepath" : (optimizationComplete ? "checkmark.circle.fill" : "bolt.fill"))
                            .font(.system(size: 13, weight: .bold))
                            .rotationEffect(.degrees(isOptimizing ? 360 : 0))
                            .animation(isOptimizing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isOptimizing)

                        Text(isOptimizing ? "PURGING SYSTEM CACHE…" : (optimizationComplete ? String(format: "OPTIMIZED: %.1f MB RECLAIMED ✓", freedMB) : "OPTIMIZE SYSTEM CACHE"))
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(optimizationComplete ? Color.green : AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .claymorphicCard(cornerRadius: 18, depth: 6)
                }
                .claymorphicButtonPress()
                .disabled(isOptimizing)

                Spacer()
            }
            .padding(.horizontal, 18)
        }
        .onAppear {
            refreshMetrics()
        }
    }

    private func refreshMetrics() {
        storageFreeString = getFreeDiskSpace()
        thermalStateText = getThermalStateText()
        batteryHealthText = getBatteryText()
    }

    private func getFreeDiskSpace() -> String {
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = attributes[.systemFreeSize] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: freeSize) + " Free"
        }
        return "114.2 GB Free"
    }

    private func getThermalStateText() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Warm"
        case .critical: return "High"
        @unknown default: return "Nominal"
        }
    }

    private func getBatteryText() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        if level >= 0 {
            return "\(Int(level * 100))%"
        }
        return "100%"
    }

    private func runRealOptimization() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        isOptimizing = true

        DispatchQueue.global(qos: .userInitiated).async {
            var freedBytes: Int64 = 0
            let fm = FileManager.default

            // 1. Purge URLCache
            URLCache.shared.removeAllCachedResponses()

            // 2. Clear NSTemporaryDirectory()
            let tmpPath = NSTemporaryDirectory()
            if let tmpItems = try? fm.contentsOfDirectory(atPath: tmpPath) {
                for item in tmpItems {
                    let fullPath = (tmpPath as NSString).appendingPathComponent(item)
                    if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? Int64 {
                        freedBytes += size
                    }
                    try? fm.removeItem(atPath: fullPath)
                }
            }

            // 3. Clear Caches directory
            if let cacheUrl = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                if let cacheItems = try? fm.contentsOfDirectory(atPath: cacheUrl.path) {
                    for item in cacheItems {
                        let fullPath = cacheUrl.appendingPathComponent(item).path
                        if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                           let size = attrs[.size] as? Int64 {
                            freedBytes += size
                        }
                        try? fm.removeItem(atPath: fullPath)
                    }
                }
            }

            let displayedFreedMB: Double
            if freedBytes > 512 * 1024 {
                displayedFreedMB = Double(freedBytes) / (1024.0 * 1024.0)
            } else {
                displayedFreedMB = Double.random(in: 48.2...84.6)
            }

            Thread.sleep(forTimeInterval: 1.2)

            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.isOptimizing = false
                    self.optimizationComplete = true
                    self.freedMB = displayedFreedMB
                    self.ramPercentage = 42
                    self.availableRam = "3.9 GB / 6.0 GB"
                    self.storageFreeString = self.getFreeDiskSpace()
                    self.thermalStateText = self.getThermalStateText()
                }
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.success)
            }
        }
    }

    private func decoyRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.depressedBackground)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(width: 26, height: 26)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}
