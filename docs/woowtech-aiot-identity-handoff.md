# woowtech aiot test-candidate handoff

Branch: `feat/woowtech-aiot-brand-support`, baseline `ab1906ae6272efce5f3e97cf6d9a8231451487c7`.
Current authority: `/Users/elmolin/WOOW-mobile-app-analysis/research/woowtech-test-candidate-phase.json`.
**Candidate status: BLOCKED — no new installable artifact or installation evidence.** This wave implements native commissioning removal and accepted brand corrections; it does not certify a runtime build. HA Cloud/Nabu Casa remote access remains supported; older claims requiring its removal are superseded.

This is a new application identity, **not an upgrade** of `com.woowtech.home`. Existing installations, keychains, App Groups, widgets, notification registrations and Watch pairing must not be assumed to migrate. No signing, uploads, store operations, customer Home Assistant access or credentials are needed for the offline checks.

## Target matrix (source configuration, not provisioning evidence)

Release root: `com.woowtech.aiot`; Debug root: `com.woowtech.aiot.dev`.
Every child appends the suffix below to its root. Both configurations use `woowtech://auth-callback`; do not install Debug and Release together for callback testing because they register the same scheme.

| Target / role | Suffix | State |
| --- | --- | --- |
| App, including Catalyst | none | Retained; release display name `woowtech aiot`, debug adds `Δ` |
| Widgets / controls / Live Activities | `.Widgets` | Retained |
| Notification service (APNs attachments) | `.APNSAttachmentService` | Retained |
| Notification content | `.NotificationContentExtension` | Retained |
| Local push provider | `.PushProvider` | Retained |
| Siri legacy Intents | `.Intents` | Retained |
| Share | `.ShareExtension` | Retained |
| Watch app | `.watchkitapp` | Retained; companion ID derives from new root |
| Watch extension | `.watchkitapp.watchkitextension` | Retained; Watch app ID derives from new root |
| Matter extension | Removed | Native target, embed/dependency wiring, source and scheme removed |
| Catalyst helpers | `.MacBridge`, `.Launcher` | Retained |
| Frameworks / tests | `.Shared`, `.SharedTesting`, `.SharedTests`, `.HomeAssistantTests`, `.HomeAssistantUITests` | New root, module/type names preserved |
| CarPlay | No separate app bundle | Existing App scene, settings and entitlements retained |

All 12 app/extension entitlement templates (root, dev and release; iOS and Catalyst) derive groups from `group.$(BUNDLE_ID_PREFIX).$(BRAND_BUNDLE_BASE)$(BUNDLE_ID_SUFFIX)` and keychain groups from `$(AppIdentifierPrefix)` plus that root. Runtime App Group and keychain derivation remains unchanged. Release app capabilities are preserved except dedicated native Matter/Thread commissioning wiring. **Baseline dev templates already omit APNs, associated domains, NFC and Siri**; simulator results cannot certify those capabilities. Existing team/profile switches are untouched and are not proof of woowtech authorization. Local ignored overrides were not inspected and may affect effective build settings.

## Auth and push boundaries

Authorize, token exchange and refresh now share `AppConstants.OAuth.clientID`; callback scheme and URI are shared constants. Embedded login accepts only the exact callback scheme and host, not arbitrary prefixed schemes or navigation links. After this lane finished, the parent deployed the real client page `https://aiot.woowtech.io/ios` and updated the shared constant plus its Swift/Python assertions to use it. Public curl and aiohttp/HomeAssistant User-Agent probes return 200 with a head `rel=redirect_uri` link to `woowtech://auth-callback`; some clients redirect to `/en/ios`, while default Python-urllib User-Agent gets 403. No old GitHub page was modified. Actual HA authorization/token/refresh and OS callback end-to-end validation is still required; metadata HTTP checks alone do not prove login. The parent re-ran all 9 offline checks, targeted SwiftFormat lint and git diff --check successfully.

Local push parser registration derives `app_id` from `AppConstants.BundleID`. The vendored relay default APNs topic is `com.woowtech.aiot`, with its existing `APNS_TOPIC` override retained. No relay was deployed. New app registration/APNs topic, Firebase, credentials and relay ownership remain release blockers. The upstream relay URL and rate-limit API, parser promotion logic, and camera WebRTC STUN were deliberately not removed or redirected: **push relay is not Home Cloud**. No Firebase/service file or signing override was read or fabricated.

## Support and content

The centralized native links use parent-owned published Odoo post routes: 364 quick start, 365 connection troubleshooting (including connection-security-level anchor), 366 contact support, 367 notifications, 368 Local Push/WebSocket, 369 actionable notifications/sounds/Live Activities with corresponding anchors, 371 iOS Widgets anchor, and 373 NFC anchor. Settings and Catalyst Help now open quick start, not the marketing homepage. The final parent manifest reports all 11 articles anonymously HTTP 200 with matching content; this lane did not repeat remote verification. Sensors, shortcuts and camera articles have no existing corresponding native help-link consumer in the audited iOS catalog; no speculative UI was added. Error Discord/GitHub links are consolidated into one correctly labelled Contact support button with an SF help icon, avoiding disclosure of error-domain data to a fake search endpoint. Labs feedback uses contact support. About retains acknowledgements, website, documentation and contact; unavailable beta/rating/translation/forum/social/source-link rows are omitted by approval. The StoreKit rating functionality elsewhere is untouched.

English resources distinguish `woowtech aiot` (the app) from `Home Assistant` (the server, protocol and upstream project). English intent strings and generated SwiftGen accessors are synchronized. The English Siri vocabulary now says “Share focus in woowtech aiot”; the offline test covers this plist. `Tools/brand/woowtech-ios.conf` now agrees with runtime OAuth client ID and a direct equality assertion prevents drift; the bulk generator was not rerun. The phase explicitly authorizes correcting misleading HA Cloud error branding in translations: 32 `woowtech Home Cloud` literals (including Traditional Chinese) now name `Home Assistant Cloud`; Turkish uses `Home Assistant Bulut`, consistent with its neighboring error. Other externally managed translations and non-English store metadata remain unchanged and need localization-owner review. No icon replacement is claimed. English store name/description/support/marketing and Fastlane app destination are updated, not uploaded.

**Not ready for store submission:** the existing privacy metadata is still upstream and must be replaced only after approved factual policy publication; no unrelated support page is substituted for a policy. Store record/numeric ID, beta links, legal owner, marketing claims, screenshots and localized metadata require owner review. Existing source provenance and licenses remain in `LICENSE`, repository history, acknowledgements metadata and upstream source comments. Upstream source is available at https://github.com/home-assistant/iOS; this is not the woowtech customer issue destination. Removing a broken customer source button does not remove license obligations. Release owner must provide the source-distribution/access mechanism required by the applicable licenses.

Other unresolved destinations include Apple Watch docs, OS support announcement, demo, invitation landing, NFC tag/universal link functional endpoints, AASA, updater/release feed and alert JSON. Watch documentation is not silently redirected to an unrelated general article. Do not redirect functional endpoints or unrelated topics to the homepage. The parent owns publication and anonymous HTTP/content verification; static URL checks do not prove pages are publicly readable.

## Native commissioning removal (implemented source slice)

Consumer trace: external-bus capability advertisements and three requests → `Current.matter` / Thread credential UI → Shared services / SettingsStore credential accessors → Matter request extension. Debug settings provided the other entry point. Dedicated source and old Thread-only tests are deleted; replacement bridge tests assert unavailable capabilities, unsupported correlated responses, failure finish events, and no overlay even with old or malformed payloads. Barcode scanning, NFC read/write, camera player, Assist, Improv, connection status and HA server WebView controls remain.

- All four native commissioning/credential flags are false. Raw request names remain **only to reject stale frontend calls**, not as working native APIs. Matter also sends `matter/commission/finish` with `success: false`; credential calls with IDs receive terminal failure results without accessing keychain data.
- Removed Matter extension target, product/embed, dependencies, dedicated build phases/configurations, scheme, Podfile target declaration, MatterSupport link, ThreadNetwork weak links, Thread entitlement injection/config switches and `_matter._tcp` discovery entry. Existing HA discovery, Improv Bluetooth, camera/mic and NFC permissions remain.
- Removed native-only credential property accessors, not persisted records: there is **no keychain/defaults migration or deletion**. Old stored values are neither read nor written. HA Cloud/remoteUI/cloudhook, Internal/direct External selection and onboarding defaults were not changed.
- 77 dedicated Xcode project objects removed via narrow text edits. Parsed pre/post object comparison proves all 3816 retained objects are unchanged except references to deleted objects. Shared package definitions, camera/Watch frameworks, app extension embeds and unrelated source references remain.
- **Cached Pods/support files and SDK frameworks are not physically removed.** CocoaPods generation and Podfile.lock checksum regeneration were not run; stale unused Matter support metadata remains in the ignored Pods sandbox. Do not claim dependency/cache removal or hand-edit dependency locks. Regenerate with the existing pinned environment only after setup/resource approval.
- Inert translated commissioning strings and shared image assets remain; they expose no entry point. Upstream namespaces, licenses and HA server-side Matter entity/control data remain valid.

## Validation, environment and reviewer entry points

Evidence: `/Users/elmolin/WOOW-mobile-app-analysis/research/review-artifacts/test-candidate-ios/`.
`pre-wave-state.txt` / `pre-wave.diff` preserve intentional prior work; `wave.diff` isolates this wave; `actual.diff` includes the full current tracked diff and explicitly selected new source/test/docs. Inventories distinguish prior changes and this wave. No staging, commits, push, signing, HA instance access or cleanup occurred.

- `python3 Tools/brand/test_woowtech_aiot.py`: **12/12 offline source contracts pass**, including OAuth config/runtime equality, English Siri, translated HA Cloud names, retained capabilities, absent native sources and target/reference/embed graph.
- Updated XCTest entry points: `WebViewExternalBusMessageTests` and `WebViewExternalMessageHandlerTests` (with script history in `MockWebViewController`). Existing barcode/camera/Assist cases retained. **XCTest not executed this wave.** Existing focused auth and Widget authenticity tests remain required.
- `xcrun swiftc -frontend -parse` passes on nine modified Swift files; targeted installed SwiftFormat autocorrection/lint passes. This is syntax only, **not typechecking/linking**. Installed SwiftGen regeneration to evidence matches the checked-in English accessor file byte-for-byte.
- `plutil`, shell/Ruby syntax and `git diff --check` are offline checks, not native build success. Project graph proof: `validate-project.py` and `project-validation.log`; review the full native bridge, DebugView, SettingsStore, project diff, entitlement script and Podfile together.
- Existing system and Homebrew Ruby cannot directly load `xcodeproj`. Homebrew CocoaPods libexec contains xcodeproj 1.28.1 but activation fails due to missing compatible rexml (>=3.3.6, <4). Supervisor authorized narrow text edits plus plutil/object graph verification instead; no dependency installation or alternate agent mode. Full Fastlane autocorrect/lint was not attempted after this setup failure; targeted formatting uses already installed Pods tools only.
- Preflight: Xcode 26.6 (17F113), Swift 6.3.3, about **6.4 GiB free initially, 5.4 GiB at final preflight**. Supervisor prohibits heavy builds at this limit. Previous wave's `Tests-Unit` attempt timed out compiling dependencies after 180 seconds; that is not a test pass.
- Latest relevant cache: `~/Library/Developer/Xcode/DerivedData/HomeAssistant-cksnfekihgzqlsbyytclbwoiuxbw`. Its `Debug-iphonesimulator/woowtech aiot Δ.app` contains only Frameworks/PlugIns directories, **no executable or Info.plist**. Exclude it from all downloads; no old binary was packaged. Other branded build directories are unrelated/old and cannot certify this source.
- Parent's public signing preflight found one Development identity, no Distribution identity, and **zero of 29 profiles matching com.woowtech.aiot**. This worker did not inspect profiles or private signing material. Device candidate signing/extension mapping requires owner action and approval.

## Smallest concrete candidate-build next action (NOT RUN)

1. Obtain explicit resource/build approval and sufficient free disk without deleting caches in this wave. Reconcile the existing Ruby/CocoaPods dependency environment and regenerate target support/lock metadata under separate approval; do not install toolchains or silently omit Watch/extensions to fit disk.
2. Reuse the latest dependency cache for **unsigned simulator App-Debug**, not an archive or full Tests-Unit build. After the gate, from this repo:

```sh
xcodebuild build -workspace HomeAssistant.xcworkspace -scheme App-Debug \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /Users/elmolin/Library/Developer/Xcode/DerivedData/HomeAssistant-cksnfekihgzqlsbyytclbwoiuxbw \
  -disableAutomaticPackageResolution -skipPackageUpdates -jobs 2 \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

3. Verify a newly generated executable/Info.plist, target IDs, embedded Widgets/push/Watch products and absence of Matter extension. Record source diff hash, build log, artifact hash and build timestamp, then install the **new** app on an approved simulator and capture launch/feature evidence. An unsigned simulator app is not installable on an iPhone. A dev-device candidate requires separately approved matching app/child provisioning; no TestFlight/Ad Hoc/public release is authorized.
4. Run focused `Tests-Unit` suites for the two bridge classes plus `AppConstantsTests`, onboarding auth and Widget authenticity, then device/service tests below. Do not run the historical brand preflight or bulk rebrand generator as a substitute.

## Per-feature candidate test/rating sheet

Ratings are **NOT TESTED** until a new artifact is installed; source-contract passes do not earn runtime quality scores. After installation, record device/OS, artifact hash, expected/actual result, screenshot/log, pass/fail and tester rating (1 unusable–5 works as expected). A blocked prerequisite is BLOCKED, not a zero-quality score or pass.

| Feature | Source status | Required installed check | Current rating |
| --- | --- | --- | --- |
| Install / identity | Config checked; artifact absent | Fresh install, display name, bundle IDs, separate old identity | BLOCKED |
| OAuth / direct LAN & External / HA Cloud | Identity checked; routing retained | Authorized HA login/token/refresh and LAN/External/Cloud switching | NOT TESTED |
| Native Matter/Thread removal | Source/graph checked | No commissioning/debug credential UI; stale requests fail; server entities still controllable | NOT TESTED |
| Camera / microphone / barcode | Preserved | Live stream, microphone permissions, generic scan/open/close | NOT TESTED |
| NFC | Preserved | Read/write tags and HA event delivery on device | NOT TESTED |
| Widgets / Live Activities | Preserved | Configure/update/action; local and remote Live Activity delivery | NOT TESTED |
| APNs / local WebSocket notifications | Preserved | Both delivery flows, action/sound/attachments and registration | NOT TESTED |
| Sensors / background location | Preserved | Permissions, updates, background movement and server state | NOT TESTED |
| Siri / Shortcuts / Assist | English Siri corrected; functions preserved | Example discovery, action execution, voice session | NOT TESTED |
| Watch | Targets/embeds preserved | New identity pairing, sync, actions/complications/notifications | NOT TESTED |
| CarPlay | Scene/capability wiring preserved | Scene launch, quick actions, Assist/audio | NOT TESTED |
| Support / localization | Links/source names checked | English/Traditional Chinese screens and actual mobile help content | NOT TESTED |

Independent review and device/service evidence are outstanding. Store/privacy/AASA/push ownership and other release boundaries above remain unresolved; preserving HA Cloud is intentional and **not** a blocker requiring removal.
