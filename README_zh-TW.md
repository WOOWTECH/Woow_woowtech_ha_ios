<p align="center">
  <img src="docs/screenshots/icon.png" alt="woowtech Home" width="120"/>
</p>

<h1 align="center">woowtech Home — iOS App</h1>

<p align="center">
  <strong>woowtech Home 生態系的白牌 Home Assistant 隨行 App</strong><br/>
  <a href="https://github.com/WOOWTECH/woow_ha_app">woow_ha_app</a>(Android)的 iOS 對應版
</p>

<p align="center">
  <a href="#總覽">總覽</a> &bull;
  <a href="#架構">架構</a> &bull;
  <a href="#截圖">截圖</a> &bull;
  <a href="#編譯">編譯</a> &bull;
  <a href="#驗證狀態">驗證</a> &bull;
  <a href="README.md">English</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-16.4+-blue?logo=apple" alt="iOS 16.4+"/>
  <img src="https://img.shields.io/badge/Bundle%20ID-com.woowtech.home-6183FC" alt="com.woowtech.home"/>
  <img src="https://img.shields.io/badge/上游-release%2F2026.7.3%2F2026.2546-purple" alt="Upstream pin"/>
  <img src="https://img.shields.io/badge/License-Apache%202.0-green" alt="Apache 2.0"/>
</p>

---

## 總覽

**woowtech Home iOS** 是官方
[Home Assistant Companion](https://github.com/home-assistant/iOS) 的白牌版本,
由共用基底 [`woow_ha_ios`](https://github.com/WOOWTECH/woow_ha_ios) 的一鍵換裝工具組
產出——與 [`Woow_simon_ha_ios`](https://github.com/WOOWTECH/Woow_simon_ha_ios)、
[`Woow_apporo_ha_ios`](https://github.com/WOOWTECH/Woow_apporo_ha_ios) 同一條管線。
原生 Swift 外殼(onboarding、OAuth、感測器、深連結、widgets)包著客戶自架伺服器
提供的 HA 網頁前端。

| | |
|---|---|
| **Bundle ID** | `com.woowtech.home`(Release)/ `com.woowtech.home.dev`(Debug)——與 Android 對齊 |
| **URL scheme** | `woowhome://`(深連結 + OAuth callback) |
| **OAuth client** | `https://woowtech.github.io/woow_ha_ios/ios`——**自建身分**;Android 版目前仍沿用上游 `homeassistant://` + 官方 client_id,建議之後跟進遷移 |
| **品牌色** | `#6183FC` |
| **上游 pin** | `home-assistant/iOS` tag `release/2026.7.3/2026.2546` |

## 架構

```mermaid
flowchart LR
    subgraph iPhone["woowtech Home app(iOS)"]
        WV["WKWebView<br/>HA 前端"] <--> BUS["JS ↔ Swift<br/>message bus"] <--> N["原生外殼<br/>onboarding · OAuth · 感測器 ·<br/>woowhome:// 深連結 · widgets"]
    end
    WV -- "HTTPS / WebSocket" --> HA["Home Assistant 伺服器<br/>(客戶自架)"]
    N -.->|"IndieAuth client 頁<br/>woowtech.github.io/woow_ha_ios/ios"| PAGE["宣告<br/>woowhome://auth-callback"]
```

client_id 頁(掛在基底 repo 的 GitHub Pages)是 HA 伺服器驗證 OAuth redirect 的
依據——已上線並宣告 `woowhome://auth-callback`。fork 拓撲、工具組設計、環境筆記
見基底 repo [README](https://github.com/WOOWTECH/woow_ha_ios/blob/main/README_zh-TW.md);
與上游的偏離記錄於 [`docs/fork-divergence.md`](docs/fork-divergence.md)。

## 截圖

| 上游基準線 | woowtech onboarding |
|---|---|
| <img src="docs/screenshots/baseline-upstream-onboarding.png" width="280"/> | <img src="docs/screenshots/woowtech-onboarding.png" width="280"/> |
| pin tag 直接編出的官方原版(工具鏈基準)。 | 一鍵換裝後:woowtech 標誌、名稱、文案、`#6183FC` 主色,原生外殼零殘留。 |

## 編譯

環境與全家族相同(細節見
[基底 repo](https://github.com/WOOWTECH/woow_ha_ios/blob/main/README_zh-TW.md#本機編譯環境)):
Xcode 26.6+、watchOS platform、brew CocoaPods(+`cocoapods-acknowledgements`)、
swiftlint/swiftformat。

```bash
pod install
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -workspace HomeAssistant.xcworkspace -scheme App-Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## 驗證狀態

| 階段 | 狀態 |
|---|---|
| 換裝(3 934 條字串 / 34 語系、79 組資產)+ preflight 66/66 | ✅ 2026-08-16 |
| 模擬器編譯 + 品牌 onboarding | ✅ 2026-08-16 |
| 實伺服器 OAuth 全鏈路、實機、8 大類冒煙 | ⏳ 待辦 |

**已知缺口**:app icon 暫以 Android 192px launcher 放大頂替——拿到 1024 原始檔後
覆蓋 `Tools/brand/assets/woowtech-icon.png` 重跑 icon 步驟即可。

## 授權與致謝

Home Assistant Companion for iOS 之修改發行版,© Home Assistant contributors——
[Apache License 2.0](LICENSE.md)。上游署名與 app 內開源致謝頁完整保留。
