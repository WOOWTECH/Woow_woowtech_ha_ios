# Phase 4 模擬器驗證報告(2026-08-16)

環境:iPhone 17 Simulator(iOS 26.5)/ Debug build(`com.woowtech.home.dev`,dev 精簡 entitlements)
伺服器:`https://woowtech-ha.woowtech.io`(HA,使用者 admin)

| # | 項目 | 結果 |
|---|---|---|
| 1 | Onboarding 品牌畫面 | ✅ woowtech 標誌、#6183FC、全文案(`phase4-woowtech-onboarding.png`) |
| 2 | 連線 + OAuth + 登入 | ✅ 手動輸入 server → **授權頁顯示自建 client_id `woowtech.github.io/woow_ha_ios/ios`,伺服器接受** → admin 登入 → `woowhome://auth-callback` redirect 回 app |
| 3 | Dashboard WebView | ✅ 總覽載入(辦公區實體,`phase4-woowtech-dashboard.png`) |
| 4 | 深連結 | ✅ `woowhome://navigate/lovelace/0` → 系統框「woowtech Home Δ」→ app 解析導向總覽 |

備註:UI 自動化 idb tap;OAuth 帳密由使用者提供並授權輸入。
