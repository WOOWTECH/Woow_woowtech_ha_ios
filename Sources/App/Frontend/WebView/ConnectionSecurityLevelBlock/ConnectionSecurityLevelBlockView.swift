import PromiseKit
import SFSafeSymbols
import Shared
import SwiftUI

struct ConnectionSecurityLevelBlockView: View {
    @StateObject private var viewModel: ConnectionSecurityLevelBlockViewModel

    @State private var showHomeNetworkSettings = false
    @State private var showConnectionSecurityPreferences = false

    let server: Server

    private let learnMoreLink = AppConstants.WebURLs.companionAppConnectionSecurityLevel

    init(server: Server) {
        self._viewModel = .init(wrappedValue: ConnectionSecurityLevelBlockViewModel(server: server))
        self.server = server
    }

    var body: some View {
        NavigationView {
            ScrollView {
                content
            }
            .navigationViewStyle(.stack)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        reload()
                    } label: {
                        Image(systemSymbol: .arrowClockwise)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.requirements.isEmpty {
                        Link(destination: learnMoreLink) {
                            Image(systemSymbol: .questionmark)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
            .onAppear {
                viewModel.loadRequirements()
            }
            #if targetEnvironment(macCatalyst)
            .fullScreenCover(isPresented: $showHomeNetworkSettings) {
                homeNetworkView
            }
            .fullScreenCover(isPresented: $showConnectionSecurityPreferences) {
                connectionPreferencesView
            }
            #else
            .sheet(isPresented: $showHomeNetworkSettings) {
                    homeNetworkView
                }
                .sheet(isPresented: $showConnectionSecurityPreferences) {
                    connectionPreferencesView
                }
            #endif
                .onReceive(NotificationCenter.default.publisher(for: .locationPermissionDidChange)) { notification in
                    if let userInfo = notification.userInfo {
                        let state = LocationPermissionState(userInfo: userInfo)
                        switch state {
                        case .notDetermined:
                            Current.Log.info("Location permission not determined")
                        case .denied, .restricted:
                            // ⚠️ 不能在這裡自己開 iOS 設定。這個通知可能來自使用者剛在系統對話框按
                            //    「不允許」,也可能是 CLLocationManager 自己觸發的授權回呼,兩者都不是
                            //    「使用者要去設定」。自動跳過去違反 App Store 審查指南 5.1.1(iv)
                            //    (Apple 2026-09-23 以同一條退件)。只更新畫面,由使用者自己按位置那一列。
                            viewModel.loadRequirements()
                        case .authorizedWhenInUse, .authorizedAlways:
                            // Handle permission change - reload requirements to update UI
                            viewModel.loadRequirements()
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
    }

    private var content: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .lockFill)
                .resizable()
                .foregroundStyle(.haPrimary)
                .scaledToFit()
                .frame(width: 80, height: 80)
            Text(L10n.ConnectionSecurityLevelBlock.title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(L10n.ConnectionSecurityLevelBlock.body)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spaces.two)

            if viewModel.requirements.isEmpty {
                Link(destination: learnMoreLink) {
                    Text(L10n.ConnectionSecurityLevelBlock.Requirement.LearnMore.title)
                }
                .buttonStyle(.secondaryButton)
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                    Text(L10n.ConnectionSecurityLevelBlock.Requirement.title)
                        .font(DesignSystem.Font.callout.bold())
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.requirements, id: \.self) { requirement in
                        requirementItem(systemSymbol: requirement.systemSymbol, title: requirement.title)
                            .onTapGesture {
                                switch requirement {
                                case .homeNetworkMissing:
                                    showHomeNetworkSettings = true
                                case .locationPermission:
                                    // 權限「在按下之前」就已被拒:這是使用者自己按了這一列,
                                    // 系統對話框也不會再出現,才帶去 iOS 設定。其餘情況交給系統對話框。
                                    switch Current.location.permissionStatus {
                                    case .denied, .restricted:
                                        URLOpener.shared.open(
                                            URL(string: UIApplication.openSettingsURLString)!,
                                            options: [:],
                                            completionHandler: nil
                                        )
                                    default:
                                        Current.locationManager.requestLocationPermission()
                                    }
                                case .notOnHomeNetwork:
                                    Current.Log.info("No action for notOnHomeNetwork requirement")
                                }
                            }
                    }
                }
                .frame(maxWidth: DesignSystem.Button.maxWidth)
                .padding(.top)
            }
            tipView
        }
        .padding(DesignSystem.Spaces.three)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private var tipView: some View {
        Text(L10n.ConnectionSecurityLevelBlock.tip)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignSystem.Spaces.two)
            .padding(.top, DesignSystem.Spaces.two)
    }

    private func openSettings() {
        // The coordinator handles Catalyst (separate Settings window) vs. the in-app Settings sheet.
        Current.sceneManager.appCoordinator.done { $0.showSettings() }
    }

    private func requirementItem(systemSymbol: SFSymbol, title: String) -> some View {
        HStack {
            Spacer()
            Image(systemSymbol: systemSymbol)
                .font(DesignSystem.Font.title2)
            Text(title)
                .font(DesignSystem.Font.callout)
            Spacer()
        }
        .foregroundStyle(.haPrimary)
        .frame(minHeight: 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spaces.one)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }

    private var bottomButtons: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Button(action: {
                openSettings()
            }) {
                Text(L10n.ConnectionSecurityLevelBlock.OpenSettings.title)
            }
            .buttonStyle(.primaryButton)
            Button(action: {
                showConnectionSecurityPreferences = true
            }) {
                Text(L10n.ConnectionSecurityLevelBlock.ChangePreference.title)
            }
            .buttonStyle(.secondaryButton)
        }
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.top)
    }

    private var homeNetworkView: some View {
        NavigationView(content: {
            HomeNetworkInputView(onNext: { context in
                server.update { info in
                    if let ssid = context.networkName {
                        info.connection.internalSSIDs = [ssid]
                    }
                    if let hardwareAddress = context.hardwareAddress {
                        info.connection.internalHardwareAddresses = [hardwareAddress]
                    }

                    showHomeNetworkSettings = false
                }
            })
            .navigationViewStyle(.stack)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        showHomeNetworkSettings = false
                    }
                }
            }
        })
        .onDisappear {
            reload()
        }
    }

    private var connectionPreferencesView: some View {
        NavigationView {
            OnboardingPermissionsNavigationView(
                onboardingServer: server,
                steps: [.localAccess, .updatePreferencesSuccess],
                onDismiss: { showConnectionSecurityPreferences = false }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        showConnectionSecurityPreferences = false
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .onDisappear {
            reload()
        }
    }

    private func reload() {
        Current.sceneManager.webViewControllerPromise.done { webView in
            webView.refresh()
        }
    }
}

#Preview {
    ConnectionSecurityLevelBlockView(server: ServerFixture.standard)
}
