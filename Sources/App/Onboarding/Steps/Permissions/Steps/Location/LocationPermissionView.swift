import Shared
import SwiftUI

/// 上線流程的位置權限說明頁。
///
/// ⚠️ 這一頁**刻意只有一個動作**。App Store 審查指南 5.1.1(iv) 要求:系統權限對話框
///    之前的自訂說明頁,不能讓使用者關掉說明並延後/跳過權限請求 ——
///    看完說明後必須總是進入系統對話框。
///
///    先前這裡有一顆「Do not share my location」次要按鈕會直接跳到下一步,
///    系統對話框從未出現,Apple 於 2026-09-21 以 5.1.1(iv) 退件。
///
///    使用者仍然握有拒絕權:在系統對話框按「不允許」即可,屆時
///    OnboardingPermissionsNavigationViewModel 會關閉位置感測器並推進流程;
///    之後也可在「設定 → 連線設定」的 locationPrivacy 重新開啟。
///
///    **不要把次要按鈕加回來。**
struct LocationPermissionView: View {
    let primaryAction: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.world)
            },
            title: L10n.Onboarding.LocationAccess.title,
            primaryDescription: L10n.Onboarding.LocationAccess.primaryDescription,
            secondaryDescription: L10n.Onboarding.LocationAccess.secondaryDescription,
            primaryActionTitle: L10n.Onboarding.LocationAccess.PrimaryAction.title,
            primaryAction: {
                primaryAction()
            }
        )
    }
}

#Preview {
    LocationPermissionView {}
}
