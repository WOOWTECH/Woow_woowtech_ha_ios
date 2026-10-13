# woowtech aiot 1.0 (2027)：退件處理與文字說明草稿

狀態：2026-10-12 台灣時間 14:45，1.0 (2027) 已重新送審，網頁與 API 均確認 WAITING_FOR_REVIEW。

## 重新送審完成收據

- App：6811131426 / com.woowtech.aiot。
- 版本：1.0，version ID 8acf8854-21f7-4637-8a72-dc51e0ac0bac，appStoreState=WAITING_FOR_REVIEW。
- Build：2027，ID e1fb8451-ae90-446c-8a7e-33e534c24f23，processingState=VALID，usesNonExemptEncryption=false。
- 提交：f2ba09eb-dd43-4179-9915-b982766f089e，state=WAITING_FOR_REVIEW，submittedDate=2026-10-12T06:45:53.881Z。
- 發布方式：保留既有 AFTER_APPROVAL（通過後自動發布），未修改發布方式。
- 已先更新 NFC 審查備註與送出釐清回覆，之後補入 build 2027 移除 UIBackgroundModes/audio 的 2.5.4 說明；API 回讀一致。
- API 改綁 2027 後，Chrome Extension MCP 在版本頁按「更新審查內容」，確認提交表格為 1.0 (2027)／準備審查，再按「重新提交至 App 審查」。送出後表格為 1.0 (2027)／等待審查，並以 API 再核對版本、build、提交狀態。
- 目前無 Apple 對 NFC 免影片請求的接受通知；WAITING_FOR_REVIEW 不等於已核准或免除影片要求。
- 程式修正已推 origin/port/apporo-fixes，commit 288b0d3eb。臨時 CI 分支 ci/woow-b2027-20261012 已刪除；雲端 build 來源與功能分支的 Configuration/Sources/Tests/Tools/Podfile/專案檔一致。
- 後續只需追蹤審查結果；若退件，讀取最新訊息再處理，不能依舊退件內容盲目重送。

## 2026-10-12 實際送出紀錄

- 擁有者在本對話明確指示「去推進送出上架」，授權執行先前已展示的備註與回覆。
- ASC API PATCH 審查備註 HTTP 200，GET 回讀與預定內容完全一致；原有登入說明保留，僅替換 NFC 段落。
- 透過 Chrome Extension MCP 在 WOOW 提交 f2ba09eb-dd43-4179-9915-b982766f089e 送出下列回覆。送出後頁面訊息由 3 則變為 4 則，新訊息作者為渥屋科技，全文與草稿一致。
- 未點選重新送審，未上傳 build 2027，尚無 Apple 對此次釐清的回覆。
- 原始備註備份位於本機 /private/tmp/woow-aiot-notes-before-20261012.json（0600，不提交 Git）。
- 目前內碟約 4.4 GiB；未啟動重工作。Homebrew Ruby 可執行 Bundler，但專案 fastlane 尚未安裝，autocorrect 仍未完成。

## 2026-10-12 唯讀查證

- Chrome Extension MCP：`http://127.0.0.1:12306/mcp`，與 Chrome DevTools MCP 不同。
- Apporo aiot（6812538019）ASC 即時狀態 READY_FOR_SALE；提交 bb1adac2-0f3b-499b-80c0-5b590b8eda92 COMPLETE，網頁顯示 1.0 (2028) 通過核准。
- Apporo 審查備註的 NFC 段落只有文字說明，沒有影片連結；9/23 對 build 2027 的訊息只剩 5.1.1(iv)，審查裝置 iPad Air 11-inch (M3)。頁面列出兩則 Apple 訊息，未見開發者文字回覆。歷史 RELEASE-CHECKLIST.md 記載透過 Notes 說明 NFC，沒有拍攝 NFC 影片。
- 這支持「Apporo 以文字說明後通過」；Apple 未交代免影片原因，不能把原因斷言為 iPad 或某句文案。
- WOOW（6811131426）10/08 對 build 2026 的訊息仍要求 NFC 影片，另有背景音訊 2.5.4；審查裝置同為 iPad Air 11-inch (M3)。10/07 已填入與 Apporo 幾乎相同的 NFC 說明，不能把再貼同一段視為已解決。

## 本機修改與驗證

- 10/12 已完成本機手動簽章與 App Store 匯出，經 `heavy.sh run woow-aiot-b2027-export-20261012` 執行，exit 0。
- 最終 IPA 主 App／五個擴充功能皆為 1.0 (2027)，簽章與 App Store profile 驗證通過；主 App 保留正式 APNs、App Group、NFC、associated domains，背景模式不含 audio。
- 產物位於 `/Volumes/WOOW-BUILD/woow-aiot/releases/b2027-20261012/`，GitHub artifact SHA-256 與 ZIP 完整性已核對。
- Apple `altool --validate-app` 回報 `VERIFY SUCCEEDED with no errors`／exit 0；14:39（台灣）`--upload-app` 回報 `UPLOAD SUCCEEDED with no errors`／exit 0，進入 Apple PROCESSING。本機重工作鎖已釋放。未做實機或模擬器回歸，不將檔案／簽章驗證描述為實機驗收。

- 擁有者後續指示「一直推進到重新送審」，持續授權完成環境準備、建置、簽章、上傳及重送。
- 10/12 本機內碟約 4.1 GiB、外接 WOOW-BUILD 約 4.5 GiB，不在本機完整編譯。heavy.sh status 為 free；本機匯出仍須排隊。
- 雲端封存臨時分支 `ci/woow-b2027-20261012`，run 38210392781；來源 e84ec3d645e9ae8b77e2b23635edc6372003a97b。只加入本次三個程式／設定檔及 CI workflow，未切換共用工作目錄。
- 該 run 的 Release archive 與封存品 identity/version/background modes 檢查成功，artifact 11728639204。整體 run 為 failure：後置 `fastlane autocorrect` 遞迴掃描 build/DerivedData 時遇到 SwiftFormat 不支援的 `--language-mode`，沒有取得完整格式檢查通過結果。封存早於格式整理，未使用 formatter 產生的異動。這次沒有 Swift/Ruby 原始碼修改；本機兩項相關 contract tests、plist lint、git diff --check 通過。
- 雲端不持有簽章私鑰，產出未簽章 xcarchive；本機再以既有六組有效 App Store profiles 簽章匯出。
- 前一輪 38210130862 因 CI 未建立 build 日誌目錄而在編譯前失敗，已修 CI 重跑；38210080613 為調整格式檢查順序主動取消。

- 移除 Sources/App/Resources/Info.plist 的 UIBackgroundModes/audio，取消持續背景音訊宣告；相機／語音前景播放程式未改。
- Configuration/Version.xcconfig build 2026 → 2027；Release 版本保持 1.0。
- 同步既有版本測試，於能力檢查加入不得宣告背景 audio 的斷言。
- plist 語法與兩項相關 Python contract tests 通過；尚未完整建置、封存或實機驗證，不能稱為可送審成品。
- `bundle exec fastlane autocorrect` 因目前 Ruby 找不到 Bundler 2.6.9 未能執行；未為此改 Gemfile.lock。

## NFC 文字說明策略

沿用 Apporo 的如實說明方式，請 Apple 重新確認影片要求，先不安排拍片。保留 NFC，不假稱沒有此功能。不承諾一定豁免；若 Apple 再次明確要求影片，仍需取得實機證據或由擁有者另決定產品範圍。

必須更正舊備註兩點：

- 寫入除 NDEF URL 外，容量允許時可含 Android Application Record（com.woowtech.aiot）；不能寫「只有 URL」。
- App 內「讀取標籤」開啟詳情頁，使用者按「觸發事件」才送事件；透過標籤連結開 App 是另一條流程，未核准的標籤先詢問允許。

## ASC NFC 備註替換段落（草稿，保留既有登入資訊）

Regarding Guideline 2.1 — optional NFC:

woowtech aiot connects to a user-configured hub over HTTPS. Its optional NFC feature uses ordinary writable NDEF tags. There is no proprietary NFC accessory, hardware handshake, Bluetooth pairing, or NFC pairing procedure. Writing a tag is the initial setup step.

The review device listed in your October 8 message is iPad Air 11-inch (M3). NFC read/write is unavailable on that device. On a compatible iPhone, open App Settings > Tags > NFC Read/Write.

Write Tag lets the user choose a random or manual identifier and write an NDEF URL in the form https://aiot.woowtech.io/tag/<identifier>. An Android Application Record identifying com.woowtech.aiot may also be written when the tag has sufficient capacity; it is not a hardware pairing record.

Read Tag reads the identifier and opens its details. The user can then select Fire Event to send the tag event to their configured hub. Duplicate writes the same identifier to another writable tag. When a supported tag link opens the app, an unapproved identifier prompts the user for permission before the event is sent. Previously approved identifiers can be managed in Tags > Allowed Tags.

NFC is optional; use of the dashboard does not require a tag or NFC accessory. Could you please reassess the hardware-pairing video request in light of this workflow? If an iPhone demonstration of these tag operations is still required, please confirm which operations you need shown.

## 解決方案中心回覆草稿（僅 NFC，可在新 build 前請求釐清）

Hello App Review,

Thank you for reviewing woowtech aiot. We would like to clarify the NFC workflow referenced in Guideline 2.1.

The listed review device is iPad Air 11-inch (M3), where NFC read/write is unavailable. On a compatible iPhone, App Settings > Tags > NFC Read/Write provides optional reading and writing of ordinary NDEF tags. Writing the tag is the initial setup; there is no designated NFC accessory or hardware pairing process.

Reading within the app displays the identifier, and Fire Event sends it to the user's configured hub. Opening the app through a supported tag link requests approval for an unapproved identifier before sending the event. We are also correcting our earlier wording: a tag may contain an Android Application Record in addition to its URL, and the in-app Read Tag action does not itself send the event.

Our Apporo aiot app (Apple ID 6812538019), published under the same developer account, was approved after we provided a written clarification of its optional NDEF-tag workflow. We understand each app is reviewed independently. Could you please reassess whether a hardware-pairing video is necessary for this workflow, or specify the iPhone operations that still require a demonstration?

We are separately preparing a new build to address Guideline 2.5.4 by removing the background audio declaration. That build has not yet been submitted.

Thank you.

## 後續關卡

1. 主協調者核對擁有者授權後，更新 NFC 備註並送出上述釐清請求；兩個動作完成後回讀。不可把草稿當成已送出。
2. 主協調者安排重工作時段；本機重工作經 heavy.sh，先確認磁碟至少 3 GB。完成格式檢查、建置與封存，必要時用 GitHub runner。
3. 驗證封存品版本 1.0 (2027)、背景 modes 不含 audio；實機回歸相機音訊、語音、前背景切換。
4. NFC 訊息獲回覆後再決定影片是否仍需提供；若仍要求，未提供前不能聲稱已解除阻擋。
5. 經主協調者核對送審授權後，才上傳、選取新 build、更新已驗證的 2.5.4 說明並重新送審。
