import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseManager: LicenseManager
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @AppStorage("cryptoric_streamer_proof_enabled") private var streamerProofEnabled = false
    @State private var now = Date()
    @State private var copiedKey = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Cryptoric").font(.headline)
                                HStack(spacing: 3) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 8, weight: .bold))
                                    Text("PRO")
                                        .font(.system(size: 8, weight: .black))
                                }
                                .foregroundStyle(Color(red: 0.85, green: 0.60, blue: 0.10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.25)))
                            }
                            Text(language.text("common.version", appVersion))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Streamer & Privacy Protection") {
                    Toggle(isOn: $streamerProofEnabled) {
                        Label("Streamer Proof Mode", systemImage: "eye.slash.fill")
                    }
                    .tint(Color.purple)

                    HStack {
                        Label("Screen Capture Status", systemImage: "record.circle")
                        Spacer()
                        Text(UIScreen.main.isCaptured ? "CAPTURING (SHIELD ACTIVE)" : "CLEAN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(UIScreen.main.isCaptured ? Color.red : Color.green)
                    }

                    Text("When Streamer Proof is active, all cheat and patch controls are masked with an innocent device analytics screen during screen recording, Discord/Zoom screen share, or AirPlay.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("License & Access") {
                    HStack {
                        Label("Status", systemImage: "checkmark.shield.fill")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(licenseManager.isActive ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(licenseManager.isActive ? "Activated" : "Not Activated")
                                .fontWeight(.semibold)
                                .foregroundStyle(licenseManager.isActive ? Color.green : Color.red)
                        }
                    }

                    if let key = licenseManager.rememberedKey(), !key.isEmpty {
                        HStack {
                            Label("Key", systemImage: "key.fill")
                            Spacer()
                            Text(String(key.prefix(8)) + "...")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Button {
                                UIPasteboard.general.string = key
                                copiedKey = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedKey = false
                                }
                            } label: {
                                Image(systemName: copiedKey ? "checkmark" : "doc.on.doc")
                                    .font(.caption)
                                    .foregroundStyle(copiedKey ? Color.green : AppTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Label("Expires On", systemImage: "calendar")
                        Spacer()
                        Text(licenseManager.formattedExpirationDate())
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Time Left", systemImage: "clock.badge.checkmark.fill")
                        Spacer()
                        Text(licenseManager.formattedTimeRemaining(currentDate: now))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(licenseManager.isActive ? AppTheme.accent : Color.red)
                    }

                    Button {
                        licenseManager.refresh()
                    } label: {
                        HStack {
                            Label("Refresh Status", systemImage: "arrow.clockwise")
                            Spacer()
                            if licenseManager.isBusy {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }

                    Button(role: .destructive) {
                        licenseManager.deactivate()
                        dismiss()
                    } label: {
                        Label("Sign Out / Deactivate", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section(language.text("settings.language")) {
                    Picker(language.text("settings.language"), selection: $languageCode) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section(language.text("common.device")) {
                    LabeledContent(language.text("dashboard.hardware_model"), value: AppInfo.displayMachineName)
                    LabeledContent(language.text("settings.ios_version"), value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                }

                Section {
                    HStack {
                        Text(language.text("settings.current_version"))
                        Spacer()
                        Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))
                        .foregroundStyle(appState.isSupported ? Color.green : Color.red)
                    }
                    LabeledContent("iOS 15", value: ExploitSupportPolicy.verifiedIOS15Range)
                    LabeledContent("iOS 16", value: ExploitSupportPolicy.verifiedIOS16Range)
                    LabeledContent("iOS 17", value: ExploitSupportPolicy.verifiedIOS17Range)
                    LabeledContent("iOS 18", value: ExploitSupportPolicy.verifiedIOS18Range)
                    LabeledContent("iOS 26", value: ExploitSupportPolicy.verifiedIOS26Range)
                    LabeledContent("iOS 27+", value: "All beta & release builds")
                } header: {
                    Text(language.text("settings.verified_versions"))
                } footer: {
                    Text(language.text("settings.supported_versions_footer"))
                }

                Section(language.text("settings.credits")) {
                    creditsRow(
                        name: "cryptoric",
                        role: language.text("credit.yangjiii"),
                        url: "https://discord.gg/j4RydbkY8b"
                    )
                }

            }
            .tint(AppTheme.accent)
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle(language.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onReceive(timer) { input in
                self.now = input
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }

    private func versionLabel(
        _ version: (beta: Int, publicBeta: Int?, build: String)
    ) -> String {
        if let publicBeta = version.publicBeta {
            return language.text(
                "settings.developer_public_beta_build",
                Int64(version.beta),
                Int64(publicBeta),
                version.build
            )
        }
        return language.text(
            "settings.developer_beta_build",
            Int64(version.beta),
            version.build
        )
    }

    @ViewBuilder
    private func creditsRow(name: String, role: String, url: String) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 28, height: 28)
                }
                .contentShape(Rectangle())
            }
            .accessibilityLabel(language.text("accessibility.open_profile", name))
        }
    }
}
