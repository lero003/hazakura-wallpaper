# Hazakura Wallpaper Project Notes

桜の花びらがデスクトップを舞う、macOS常駐アプリ。

## 2026-05-24 Swift native rewrite

公開品質へ寄せるため、Swift/AppKit 版を追加した。

- `Package.swift` を追加し、公開実行product `HazakuraWallpaper`、内部app target `SakuraSky`、`SakuraSkyCore` テスト可能コアを分離。
- メニューバー制御は `NSStatusItem`、透明オーバーレイは `NSWindow` + `NSView` + CoreGraphics 描画へ移行。
- status item には VoiceOver 用の accessibility label / help を付け、AppKit secure restorable state を明示する。
- 現行 Tauri 版の主要仕様を維持しつつ、公開名を Hazakura Wallpaper に変更: 停止/再開、夜桜背景、SAKURA/Magic/Spark/Hazakura/Breeze/Hotaru、強度、設定永続化、マウス風。
- 複数ディスプレイに透明オーバーレイを作成。
- `scripts/build_app.sh` で `dist/Hazakura Wallpaper.app` を生成し、可能なら ad-hoc codesign する。
- `SakuraSky.xcodeproj` を追加し、公開用 `.app` は Xcode Release product から `dist/` へコピーする方針に変更。
- `package.json` の通常 scripts は Swift/AppKit 版の build / dev / preview / verify / release:candidate へ向け、旧Tauri導線は `legacy:*` に退避した。`scripts/check_workflow_aliases.sh` と release gate で検査し、`npm run build` や未prefixの `npm run tauri` が旧実装を公開版として扱わないようにする。
- Swift公開用の `icon.icns` / `icon.png` は `Resources/` に置く。Xcode project と SwiftPM fallback bundle は legacy `src-tauri/icons` に依存しない。
- `SakuraSkyRenderer` を分離し、全モードのオフスクリーン描画 smoke test を追加。
- 停止状態は永続化せず、次回起動時は必ず描画状態から始める。
- macOS の Reduce Motion が有効な場合、保存設定は変えずに描画時だけ intensity を quiet 相当に落とし、描画とカーソルサンプリングのタイマーも低頻度へ張り替える。
- 設定永続化は `SakuraSkyCore.EffectSettingsStore` に切り出し、保存、破損データ時のデフォルト復帰、初期化をテストで確認する。
- 設定読み込みは部分的な不正値でも有効な項目を維持し、夜桜フラグの型不一致でも他設定を落とさず、旧Tauri由来の `night` / `focus` キーも受け入れる。
- Swift側の UserDefaults 設定が未作成または壊れている場合は、旧Tauri版の `Application Support/com.sakurasky/settings.json` または `Application Support/Hazakura Wallpaper/settings.json` から一度だけ設定を取り込み、Swift側へ保存する。旧設定もない状態でSwift設定が壊れている場合は、既定値を保存し直して次回起動時に同じ破損データを読み続けない。
- メニュー操作の意味論と表示状態は `SakuraSkyCore.EffectSettingsCommand` / `EffectSettingsMenuState` に切り出し、停止/再開、夜桜、モード、強度の挙動をテストで確認する。
- smoke用の自動終了設定は `SakuraSkyCore.SmokeExitConfiguration` に切り出し、環境変数の解釈と最小delay clampをテストで確認する。実際のタイマー登録は `SakuraSkyApp.main` の一箇所に限定する。
- オーバーレイ描画とカーソル追跡の周期は `SakuraSkyCore.OverlayTimingConfiguration` に切り出し、実行時タイマーは `.common` run loop mode に登録する。
- overlay window の content view はスクリーンのグローバル座標ではなく、ローカル原点の content frame を使う。`SakuraSkyCore.OverlayWindowGeometry` で、負座標ディスプレイでも canvas frame とマウス座標変換が破綻しないことをテストする。
- マルチディスプレイ時の非アクティブ画面では、画面外ローカル座標から風向きを計算しない。`SakuraSkyCore.PointerMotionState` に切り出し、非アクティブ画面は既定風に戻し、次にアクティブになった初回サンプルへ画面外ジャンプ速度を持ち込まないことをテストで確認する。
- `OverlayController.start()` は多重呼び出しを無視し、停止中に再作成された `SakuraCanvasView` は再開まで描画タイマーを起動しない。window close / view detach 時には display timer を明示停止する。停止後に遅れて届いた画面構成変更通知やcursor timer callbackも overlay を再生成しない。
- 停止中は描画タイマーだけでなく cursor sampling timer も止める。常駐アプリとして、停止状態では不要なマウス反応更新による wakeup を避ける。
- `SakuraCanvasView.init(coder:)` は `fatalError` せず、default settingsで復元する。通常経路ではprogrammatic生成だが、公開版に不要なクラッシュ経路を残さない。
- `葉桜ラボを開く` メニュー操作は `SakuraSkyCore.AppExternalLinks` の検証済みURLを使う。URL生成失敗時は何もせず、公開版の通常メニュー経路から強制unwrapによるクラッシュを除き、`NSWorkspace.open` 失敗時は MenuBar telemetry に記録する。
- `このアプリについて` はbundle metadataからapp名、version/build、copyrightを表示する。LSUIElementのメニューバーappでもalertを見失いにくいよう、modal表示前に `NSApp.activate()` でappを前面化する。
- `OSLog.Logger` による軽量telemetryを追加し、Lifecycle / Settings / Overlay / MenuBar の主要イベントを `com.hazakuralab.hazakurawallpaper` subsystemで追えるようにした。`script/build_and_run.sh --telemetry` は通常macOSセッションで対象subsystemの unified logs をstreamする。
- `SakuraSkyPreview` と `scripts/render_previews.sh` を追加し、全モードと夜桜の 960x540 PNG プレビューを生成できるようにした。
- `SakuraSkyPreview` は `qa-matrix-day.png` と `qa-matrix-night.png` も生成し、全モード・全強度の視覚QAを一覧できる。
- `SakuraSkyPreview` は固定seedで描画し、renderer / preview logicを意図的に変えない限り、QA用PNGと `dist/SHA256SUMS` のpreview checksumが再現される。
- `SakuraScene.resize(to:)` は実描画サイズに合わせて粒子群を再初期化する。初回描画時に 1440x900 初期配置の粒子が小さいプレビューや小型ディスプレイから外れて薄くなる問題を避ける。
- `SakuraScene` の `orbitSpeed` 系アニメーションは旧 canvas 実装の requestAnimationFrame millisecond 前提に合わせ、Swift の秒単位時刻から明示変換する。花びらと Magic light の周期運動が静止気味になる移植ズレを避ける。
- renderer の deterministic random seed は `nonisolated(unsafe)` な共有staticではなくthread-local seed boxで管理する。preview checksum再現性を維持しつつ、ネストしたseed scopeの復元もテストする。
- Swift公開用iconは `Resources/icon.icns` / `Resources/icon.png` だけを正とし、runtime loader と SwiftPM fallback bundle から legacy `src-tauri/icons` fallback を削除した。`scripts/check_swift_asset_boundaries.sh` を release gate に入れ、Swift公開ビルド経路が旧Tauri iconに戻らないようにする。
- `scripts/check_release_metadata.sh` を追加し、`package.json`、`package-lock.json`、`Resources/Info.plist`、Xcode project の version/build がズレたまま公開候補を作れないようにした。同時に、公開用Xcode app targetのSources build phaseが `Sources/SakuraSky` / `Sources/SakuraSkyCore` / `Sources/SakuraSkyRenderer` の配布Swiftソースを取りこぼしていないこと、配布対象ソースのbasenameが重複していないこと、また配布対象外のSwiftソースを含んでいないことも検査する。
- `scripts/check_preview_artifacts.sh` を追加し、単体プレビューが 960x540、QA matrix が 1440x1824 のPNGであることに加え、透明な空画像や真っ黒な壊れた画像ではないことを visible alpha pixel / nonzero color channel の下限で検証する。
- `scripts/check_swift_safety.sh` を追加し、公開用 Swift ソースとテストに `fatalError`、`preconditionFailure`、`try!`、`as!`、強制アンラップ、`nonisolated(unsafe)`、`@unchecked Sendable` が残らないことを release gate で検査する。guard test はfixture pathを渡して強制アンラップ入りSwiftファイルが実際に拒否されることも確認する。
- `scripts/check_app_lifecycle_safety.sh` を追加し、AppKit常駐overlayのTimer closureが `[weak self]` を使うこと、timer invalidate/nil化、NotificationCenter observer removal、window close前の `prepareForClose()` が残っていることをrelease gateで静的検査する。実行時memory smokeと通常セッション `leaks --atExit` 証跡だけに頼らず、ライフサイクル退行を公開前に止める。
- `SakuraSkyMemorySmoke` と `scripts/check_renderer_memory_smoke.sh` を追加し、Swift renderer を複数モードで多数フレーム描画して可視pixelと最大RSSを証跡化する。通常セッションの `leaks --atExit` 証跡は最終共有ゲートに残しつつ、自動化環境でも描画ループのメモリ暴走を release gate で検出できるようにした。
- `scripts/check_preview_determinism.sh` を追加し、previewを2回レンダリングしてSHA-256が一致することを `dist/release-evidence/preview-determinism.txt` に記録する。
- `scripts/verify_release.sh` を追加し、テスト、Xcode `.app` 生成、Info.plist、Mach-O最低macOS、codesign、release executable smoke、プレビュー生成と寸法検証を一括確認する。
- `scripts/package_zip.sh` を追加し、`hdiutil` が使えない制限環境でも `dist/Hazakura Wallpaper.zip` を作れるようにした。ZIPは一時ファイルへ作成し、ZIP content検査に通ったものだけ正本の `dist/Hazakura Wallpaper.zip` へ昇格する。途中失敗時はZIP / SHA256SUMS / manifest / ZIP content証跡を削除し、壊れた公開候補を残さない。
- `scripts/package_zip.sh` は公開名変更前の `dist/Sakura Sky.app` / `dist/Sakura Sky.zip` も候補作成時に削除し、手元の `dist/` から旧名artifactを誤って共有しないようにする。
- `scripts/write_github_release_notes.sh` / `scripts/check_github_release_notes.sh` を追加し、現在のZIP SHA、DMG有無、Gatekeeper回避、install doc、publish/share commands、privacy/security linksを含む `dist/release-evidence/GITHUB_RELEASE_DRAFT.md` を生成・検査する。`scripts/check_publish_readiness.sh` は、GitHub Release本文が現在artifactとズレた候補を拒否する。
- `scripts/package_dmg.sh` は既存appを no-write distribution readiness で検査し、DMG作成後に `hdiutil verify` を通し、`dist/release-evidence/dmg-info.txt` と `dist/SHA256SUMS` / manifest / GitHub Release draft にDMG SHAを記録する。通常のfresh build経路では同じappからZIPも作り直してからDMGを作り、最後にrelease evidenceとGitHub Release draftを再検査するため、DMGだけ新しくZIP/manifest/release draftが古い候補を残さない。`HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1` は既存app/ZIPペアを保つが、その場合もrelease evidenceまたはGitHub Release draftが不整合なら失敗し、作成したDMGとDMG証跡を削除して不整合な公開artifactを残さない。legacy alias として `SAKURA_SKY_PACKAGE_EXISTING_APP=1` も受け付ける。`scripts/package_zip.sh` は古いDMGとDMG証跡を削除し、前回app由来のDMGを公開候補へ混ぜない。
- `scripts/notarize_release_zip.sh` からZIPを作るときは、Developer ID署名検証済みの `dist/Hazakura Wallpaper.app` を再ビルドせずにpackageする。これにより、notary提出前に検証したappと提出ZIP内のappが同一導線になる。
- `scripts/build_app.sh` は Xcode product を `dist/` へコピー後に検査して再署名する。公開用成果物から `get-task-allow` は外れ、hardened runtime は維持される。同時実行時は `.build/build_app.lock` で `dist/Hazakura Wallpaper.app` への競合書き込みを避ける。
- Xcode Release設定は `ARCHS = "$(ARCHS_STANDARD)"` と `ONLY_ACTIVE_ARCH = NO` に固定し、`scripts/check_release_metadata.sh` がこの設定を検査する。`scripts/build_app.sh` のXcode公開ビルドも既定で `arm64 x86_64` のUniversal appを作る。`scripts/check_distribution_readiness.sh` と release evidence は `lipo -archs` の結果を検査し、公開候補が片方のCPU architectureだけになった場合は失敗する。
- `scripts/check_distribution_readiness.sh` を追加し、bundle構造、bundle ID / 表示名 / development region / InfoDictionaryVersion / icon key / category / supported platform / copyright、menu-bar app metadata、app icon / status icon resource、Mach-O最低macOS、codesign、hardened runtime、entitlements不在、Developer ID署名有無を確認できるようにした。
- `scripts/check_distribution_readiness.sh` は `SAKURA_SKY_WRITE_DISTRIBUTION_EVIDENCE=0` の no-write mode を持つ。一時展開したZIP内appを検査するときはこのモードを使い、`dist/release-evidence/` の正本証跡を一時app pathで上書きしない。
- `scripts/write_release_manifest.sh` を追加し、ZIP作成時に `dist/SHA256SUMS` と `dist/release-evidence/RELEASE_MANIFEST.md` を生成する。manifest は署名状態と最終notarized ZIP検証状態を明示し、manifest / SHA256SUMS は一時ファイルからatomic renameで更新する。
- ZIP再作成時は古い notarization / Gatekeeper / final ZIP / bundle open / visual QA 証跡を削除し、manifest は現在のZIPが最終検証済みで、かつ bundle-open / visual QA 証跡が現在の bundle ID / version / build / architectures / CDHash / ZIP SHA とちょうど1個ずつ一致し、UTC timestamp、operator/reviewer provenance、専用記録コマンド、visual QA checklist完了とchecklist SHAも一意に揃うときだけ最終notarization証跡とbundle-open / visual QA証跡を列挙する。
- manifest の Required External Checks は、現在の最終ZIPに一致する bundle-open / visual QA 証跡が揃うまで通常セッションbundle-open確認と最終ZIP視覚QAを未達項目として明示し、証跡が揃った後は未達項目から外す。unsigned GitHub/DMG配布では、任意の通常セッション `leaks --atExit` 証跡がない場合も外部確認推奨項目として明示する。
- manifest の `Final notarized ZIP verified: yes` は、現在のZIP archive path、ZIP SHA、Developer ID署名、ちょうど1個の `status: Accepted` 行のnotarytool証跡、ちょうど1個の厳密なstapler成功行、ちょうど1個の `path: accepted` 形式のGatekeeper評価内容、展開後final ZIPの identity / CDHash / 成功marker / codesign validity / designated requirement / stapler / Gatekeeper 検証が揃う場合だけ出す。偽または古い final ZIP log 単体、空または失敗内容のcodesign / stapler / Gatekeeper証跡では yes にしない。
- `scripts/write_release_manifest.sh` の final ZIP 判定は helper 関数定義後に行う。final notarization 証跡が揃った公開直前経路で、未定義関数呼び出しにより manifest 更新が壊れないようにする。
- `scripts/check_zip_contents.sh` を追加し、配布ZIPを展開して中のappが現在の `dist/Hazakura Wallpaper.app` と一致すること、`__MACOSX`、AppleDouble、`.DS_Store` sidecar が混入していないこと、トップレベルが `Hazakura Wallpaper.app` だけであること、app bundle内が想定された最小構成だけであること、ソース / scripts / docs / 依存 / Xcode project / legacy Tauri 資産や開発メタデータ / editor state / local env / debug symbol / build output が混入していないことを `dist/release-evidence/zip-contents.txt` に記録する。
- `scripts/check_release_evidence.sh` を追加し、manifest、現在の `.app` identity / signature / entitlements / CDHash、`dist/SHA256SUMS`、実ZIP SHA、プレビュー証跡、preview determinism証跡、ZIP content証跡、codesign / Mach-O / 現在app pathに紐づくspctl証跡、最終ZIP検証ログ、notarytool Accepted証跡、存在するbundle-open / visual QA証跡の整合を検証する。`dist/SHA256SUMS` はZIP、DMG、preview artifactごとに対応checksum行がちょうど1個であることを要求し、preview determinism証跡もpreviewごとのchecksum行がちょうど1個であることを要求する。検査時点でもZIPを再展開し、ZIP内appと現在の `dist/Hazakura Wallpaper.app` が一致することを再確認する。署名証跡の正本は `dist/release-evidence/` のみとし、古いトップレベル `dist/codesign-*` 証跡が残っている場合は失敗する。
- `dist/release-evidence/release-evidence-check.txt` は `Final notarized ZIP verified` の状態を明示し、pre-final候補では final-only evidence が存在しないこと、final候補では notarization / stapler / post-notarization Gatekeeper / final ZIP verification 証跡が揃うことを人間が確認できるようにする。
- `dist/release-evidence/release-evidence-check.txt` は、unsigned GitHub/DMG 配布ではrelease evidence上の blocker を出さず、Gatekeeper回避、optional notarization、通常セッションbundle-open、人間のvisual QAを注意事項として列挙する。`HAZAKURA_WALLPAPER_REQUIRE_NOTARIZATION=1 ./scripts/check_publish_readiness.sh` は Developer ID / notarization / final human evidence を要求する。legacy alias として `SAKURA_SKY_REQUIRE_NOTARIZATION=1` も受け付ける。
- manifest は `dist/release-evidence/release-evidence-check.txt` を常に列挙し、公開QAで読む最終照合レポートが任意証跡扱いにならないようにする。
- `scripts/check_release_evidence.sh` は、final notarized ZIP verification が完了していない状態で最終専用notarization / bundle-open / visual QA 証跡ファイルが存在、またはmanifestに列挙されると失敗する。最終証跡が存在する場合も、現在の bundle ID / version / build / architectures / CDHash / ZIP SHA とちょうど1個ずつ一致すること、timestamp が `YYYY-MM-DDTHH:MM:SSZ` 形式のUTCでちょうど1個であること、operator/reviewer が単一行かつ非空白でちょうど1個であること、専用記録スクリプトの command 行、bundle-open の app / executable / anchored process match、visual QA の checklist完了 / checklist SHA が一意に残っていることを検査する。手書きや古い最終証跡の混入を公開前に止める。
- `scripts/test_release_evidence_guards.sh` を追加し、空白/複数行のoperator/reviewer、重複した `dist/SHA256SUMS` のZIP checksum行、重複したpreview determinism checksum行、古い icon CDHash 証跡、偽の最終専用manifest列挙、final ZIP log、notary evidence、bundle-open証跡、visual QA証跡が拒否されることを回帰検出する。`scripts/prepare_release_candidate.sh` はこのguard testも実行する。guard test は pre-final 専用で、final notarization証跡が揃った後は実行を拒否する。public source hygiene の失敗fixtureは `check_public_source_hygiene.sh <fixture>` の targeted mode で検査し、repo root に一時ZIPを作らない。targeted mode は Git repository discovery に依存せず、自己検査スクリプトだけを明示検査した場合も内容スキャン範囲を意図外に広げない。
- `scripts/test_release_evidence_guards.sh` の失敗診断用 stdout/stderr は `dist/release-evidence/` ではなく一時ディレクトリ側へ出す。guard test 自体の失敗や中断で canonical release evidence が補助ログに汚染されないようにする。
- `scripts/record_bundle_open_verification.sh` を追加し、通常macOSセッションで既存の `dist/Hazakura Wallpaper.app` を開けることと `Contents/MacOS/HazakuraWallpaper` プロセスがanchored executable-path matchで残ることを、bundle ID、app version/build、CDHash、ZIP SHA、operator、app path、executable pathに紐づけて記録できるようにした。
- `scripts/record_bundle_open_verification.sh` は manifest が現在のZIPについて `Final notarized ZIP verified: yes` を証明し、final ZIP検証ログが現在の bundle ID / version / build / architectures / CDHash / ZIP SHA と一致するまで、bundle-open証跡を書かない。
- `scripts/record_bundle_open_verification.sh` と `scripts/record_visual_qa_acceptance.sh` は、final ZIP検証ログに `Verified archive: dist/Hazakura Wallpaper.zip` と現在の bundle ID / version / build / architectures / CDHash / ZIP SHA がそれぞれちょうど1個ずつあることを要求する。人間証跡の記録前に、どのarchiveを最終確認したかを明示させる。
- `scripts/record_bundle_open_verification.sh` の `SAKURA_SKY_BUNDLE_OPEN_SETTLE_SECONDS` は正の数だけ受け入れる。`0` や非数値は証跡作成前に exit 2 で拒否する。`--operator` は単一行かつ非空白の人間識別子だけを受け入れる。証跡書き込み後は manifest を再生成し、release evidence check を再実行する。
- `scripts/record_visual_qa_acceptance.sh` を追加し、人間の視覚QA受理をnotarized final ZIPのbundle ID、app version/build、architectures、CDHash、ZIP SHA、timestamp、reviewer、checklistに紐づけて記録できるようにした。実書き込みはfinal ZIP検証証跡が現在の bundle ID / version / build / architectures / CDHash / ZIP SHA と一致するまで拒否する。
- `scripts/record_visual_qa_acceptance.sh` は明示的な `--checklist-complete` と `docs/RELEASE_QA.md` のSHA-256も証跡へ記録する。公開ゲートは checklist complete 行や現在のchecklist SHAと一致しない視覚QA受理を拒否し、どのチェックリスト内容を承認したのかが曖昧にならないようにする。
- `scripts/record_visual_qa_acceptance.sh` の `--reviewer` は単一行かつ非空白の人間識別子だけを受け入れる。証跡書き込み後は manifest を再生成し、release evidence check を再実行する。
- `scripts/record_unsigned_bundle_open_verification.sh`、`scripts/record_unsigned_visual_qa_acceptance.sh`、`scripts/record_unsigned_memory_check.sh` を追加し、Developer ID / notarization を使わない既定のGitHub/DMG配布でも、通常セッションbundle-open確認、人間visual QA受理、`leaks --atExit` メモリ確認を現在の bundle ID / version / build / architectures / CDHash / ZIP SHA / checklist SHA に紐づけて任意記録できるようにした。ZIP再作成時はこれらのunsigned証跡も削除する。
- `scripts/check_public_source_hygiene.sh` を追加し、GitHub公開対象になる tracked / untracked かつ ignore されていないソース面に、ローカルパス、ローカルユーザー名、生成物、バックアップ、credential風ファイル名、秘密鍵/証明書/token風marker、明示notarytool credential引数が混じると失敗するようにした。`scripts/check_publish_readiness.sh` はこの検査を先に実行する。
- `scripts/check_public_source_hygiene.sh` は、ルート直下などに誤って置かれたZIP/pkg/tar系リリースアーカイブ、xcarchive、dSYM、`.DS_Store` も publishable source として検出した場合に失敗する。macOS標準bashでも失敗内容を表示できるよう、bash 4 nameref依存は避ける。
- `scripts/check_public_artifact_hygiene.sh` を追加し、GitHub / CI artifact として公開する release evidence を allowlist 化した。公開対象はZIP、CIで作成できた場合のDMG、release draft、manifest、checksums、DMG evidence、preview evidence、ZIP content、guard test、renderer memory smoke に限定し、raw `codesign` / `spctl` / Mach-O / icon 証跡のようにローカル絶対パスを含み得るファイルはCI artifact wildcardで公開しない。公開artifact内のローカルパス、ローカルユーザー名、秘密鍵/certificate/token風marker、明示notarytool credential引数も拒否する。
- 公開手順で使う環境変数は `HAZAKURA_WALLPAPER_*` prefix を正とし、既存の `SAKURA_SKY_*` prefix は互換aliasとして残す。SwiftPM package名と `package.json` name は `hazakura-wallpaper`、公開実行product / bundle executable は `HazakuraWallpaper`、内部Swift app target / module名は `SakuraSky` のままにする。README / install docs も source package / repository name として `hazakura-wallpaper` を明示し、`scripts/check_release_metadata.sh` と `scripts/check_public_repository_docs.sh` で退行を止める。
- `scripts/check_script_executable_bits.sh` を追加し、GitHub/source-build workflowで `./scripts/...` がそのまま実行できるよう、`scripts/*.sh` と `script/*.sh` の実行権限を release gate と CI で検証する。
- `scripts/check_legacy_tauri_boundary.sh` を追加し、legacy Tauri資料は `docs/legacy-tauri/` の下だけに残せるようにした。publishable source のトップレベル `src/`、`src-tauri/`、または `Cargo.toml` / `Cargo.lock` / `tauri.conf.json` が戻ると release gate と CI が失敗する。
- `.gitattributes` を追加し、Swift / shell / Markdown / plist / project / JSON/YAML/TOML/HTML/JS はLF、画像/アーカイブはbinaryとして扱う。`scripts/check_text_normalization.sh` は publishable text files の CR/CRLF を検出し、release gate と CI で実行する。
- `CHANGELOG.md`、`CONTRIBUTING.md`、`SECURITY.md`、`PRIVACY.md`、`docs/INSTALL.md` と `scripts/check_public_repository_docs.sh` を追加し、GitHub公開時の変更履歴、貢献/検証手順、署名/配布境界、報告導線、ローカル設定、network/logging挙動、DMG/ZIP/source build/Gatekeeper/uninstall手順、license未選択状態を明示する。`scripts/check_publish_readiness.sh` と CI は、この公開リポジトリ文書が揃っていない候補を拒否する。
- `scripts/check_publish_readiness.sh` を追加し、既定では unsigned GitHub/DMG 配布向けにZIP、manifest、checksum、app metadata、preview、ZIP content、release evidence整合、public source hygiene が揃えば通過する。`HAZAKURA_WALLPAPER_REQUIRE_NOTARIZATION=1` の場合だけ、古いApple ID/password notarization環境変数を拒否し、Developer ID署名、notarization / stapler / Gatekeeper証跡の成功内容、live stapler / Gatekeeper検証、最終ZIP検証、通常セッションbundle open証跡、人間の視覚QA受理、operator/reviewer provenance、専用記録スクリプトの command 行、bundle-open の app / executable / anchored process match、visual QA の checklist完了 / checklist SHA、SHA整合を要求する。legacy alias として `SAKURA_SKY_REQUIRE_NOTARIZATION=1` も受け付ける。
- `scripts/check_share_readiness.sh` を追加し、実際にユーザーへ渡す直前の共有ゲートを `check_publish_readiness.sh` より厳しくした。publish readiness に加え、現在のDMG、DMG証跡、通常セッションbundle-open証跡、通常セッション `leaks --atExit` 証跡、人間visual QA証跡が揃うまで失敗する。
- `scripts/check_unsigned_share_prerequisites.sh` / `npm run share:preflight` / `npm run share:preflight:strict` を追加し、既存の unsigned 候補、release evidence / publish readiness、通常セッション共有で必要な `hdiutil`、`leaks`、`open`、`osascript` などのツールを事前確認できるようにした。strict alias は小さな一時DMGの create / verify / mount / detach まで試し、`npm run share:unsigned` はこの厳密プリフライトを最初に実行する。
- `scripts/finalize_unsigned_share.sh` / `npm run share:unsigned` を追加し、通常macOSセッションで視覚QA完了後に既存の unsigned 候補を検証し、同じ app / ZIP からDMG作成、LaunchServices bundle-open証跡、`leaks --atExit` 証跡、人間visual QA証跡、share readiness を一括実行できるようにした。視覚確認済み候補を作り直さないため、`npm run release:candidate` は視覚QA前に実行する。`--operator`、`--reviewer`、`--accepted`、`--checklist-complete` が揃わない場合は拒否する。
- `scripts/test_release_evidence_guards.sh` は unsigned share finalizer が strict preflight、既存候補からのDMG作成、bundle-open証跡、memory証跡、visual QA証跡、最後の `check_share_readiness.sh` を含むことも静的に検査する。通常セッション共有の一括導線から最終share gateが抜ける退行を防ぐ。
- `scripts/package_dmg.sh` はDMG作成後に `hdiutil verify` だけでなく、read-only / nobrowse でDMGをマウントし、マウント内の `Hazakura Wallpaper.app` を no-write distribution readiness で検証し、source app と mounted app の bundle ID / version / build / CDHash が一致し、release evidence と GitHub Release draft が現在artifactと一致する場合だけDMG証跡を残す。失敗時は未検証DMGと `dmg-info.txt` を削除し、manifest / GitHub Release draft も再生成して、過去のDMG成功時の記載が残らないようにする。
- `.github/workflows/ci.yml` を追加し、push / pull request / manual dispatch で shell syntax、public source hygiene、`npm run release:candidate`、unsigned publish readiness、CI上の unsigned DMG packaging、`npm run share:preflight`、share gate が通常セッション証跡待ちで失敗することを確認し、ZIP / DMG / checksum / preview / public-safe release evidence だけを workflow artifact としてアップロードする。raw `codesign` / `spctl` / Mach-O / icon 証跡はローカル絶対パスを含み得るため、CI artifact wildcard では公開しない。
- `scripts/notarize_release_zip.sh` と `docs/RELEASE_QA.md` を追加し、Developer ID署名、notarytool keychain profile、preview determinism、ZIP content検査、notarytool Accepted証跡、stapler検証、Gatekeeper評価、人間の視覚確認を公開前導線として固定した。notary提出証跡には提出ZIP SHA-256を64桁hexでちょうど1個、UTC提出時刻、profile名を伏せた提出コマンド、提出時のbundle ID / version / build / architectures / CDHashを記録し、release evidence / publish readiness はそれらの提出フィールドが一意で現在appのidentityと一致しないAccepted証跡を拒否する。notarization script 自体も、正本証跡へ昇格する前にnotary Accepted、stapler成功、Gatekeeper accepted、最終ZIP内appの成功marker / codesign validity / designated requirement / stapler / Gatekeeper成功行がそれぞれちょうど1個であることを確認する。notarize後に作り直す最終ZIPも一時ファイルとして作成してから展開し、verified archive path、codesign / stapler / spctl とbundle identity / CDHashを再確認した後にだけ正本の `dist/Hazakura Wallpaper.zip` へ昇格する。canonicalな最終証跡は全工程成功後だけ `.log` / `.txt` 名へ昇格し、final ZIP経路が未完了で落ちた場合はZIP / SHA / manifest / ZIP content証跡 / canonical final証跡 / 人間final証跡を削除する。途中失敗は `.failed` 証跡として残す。release evidence / publish readiness は `.attempt` / `.failed` notarization証跡が残る候補を拒否する。Apple ID / password を環境変数からコマンド引数へ渡す導線は使わない。
- `scripts/notarize_release_zip.sh` は ad-hoc、Apple Development、その他 `Developer ID Application:` で始まらない `SIGN_IDENTITY` をビルド前に拒否する。notarization用の入口で誤った署名identityを使って時間を浪費したり、不完全な公開証跡を残したりしない。
- `scripts/prepare_release_candidate.sh` を追加し、verify、ZIP作成、SHA256検証、ZIP展開後のapp検証、GitHub release draft検証、public artifact hygiene検証を一括実行できるようにした。
- `script/build_and_run.sh --verify` の bundle executable smoke は、Xcodeが作った `dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper` を一時実行ファイルへコピーしてwatchdog付きで実行する。LaunchServicesが制限環境で `.app` を開けない場合でも、SwiftPMの別成果物ではなく配布bundle由来の実行ファイルを検査する。`SAKURA_SKY_EXECUTABLE_SMOKE_TIMEOUT` は正の整数のみ許可し、入力不正はビルド前に exit 2 で止める。
- 2026-05-26 時点で `npm run release:candidate --silent` と `./scripts/check_publish_readiness.sh` は unsigned GitHub/DMG 配布条件で通過。`dist/Hazakura Wallpaper.zip` も展開後の Info.plist、bundle ID / 表示名 / development region / InfoDictionaryVersion / executable `HazakuraWallpaper` / icon key / category / supported platform / copyright、Mach-O architecture、Mach-O最低macOS、codesign、entitlements不在、アイコン形式、プレビュー寸法と可視内容、preview visual diversity、preview determinism、release evidence guard test証跡、script executable bits、AppKit lifecycle safety、privacy/security boundary、renderer memory smoke、GitHub release draft、public artifact hygiene、ZIP content、release evidence整合検証が通過。現在のZIP SHA-256: `6ea02acef3291e0c3e6121529387ec664721f3d833d873bd93dc3166374cac6a`。
- 2026-05-25 の公開前確認で、Swift safety gate は force unwrap / `nonisolated(unsafe)` / backup file 混入を検査し、`SakuraCanvasView` の timer main-actor 更新、`shouldAnimateOverlay` と実DisplayLink timerの同期、close 前 cleanup、`OverlayController` の observer cleanup、renderer cache の main-actor 化を確認済み。`OverlayController.stop()` は画面IDキャッシュもリセットし、同一プロセス内の stop→start で同じ画面構成でもoverlay windowを再生成できるようにした。`.codex/` と `*.bak` は `.gitignore` で公開対象外にした。
- `OverlayController` / `SakuraCanvasView` / `StatusBarController` は main actor 上の `deinit` cleanup fallback を持つ。通常終了時は `AppDelegate.applicationWillTerminate` が明示 stop 後に controller 参照を nil 化し、`StatusBarController.stop()` は多重呼び出しを無視する。`scripts/check_app_lifecycle_safety.sh` はこの cleanup fallback と status item removal の退行も検査する。
- 現在の署名は ad-hoc のため `scripts/check_distribution_readiness.sh` は `Notarization-ready signing: no` と報告する。Developer ID署名を必須にする場合は `SAKURA_SKY_REQUIRE_DEVELOPER_ID=1` を付ける。
- 同環境で `npm run share:preflight:strict --silent` は一時DMG作成時に通常セッションではないことを明示して失敗する。`HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 ./scripts/package_dmg.sh` も `hdiutil: create failed - 装置が構成されていません` により失敗し、未検証DMG / DMG証跡が残らないことを確認済み。通常macOSセッションで再検証すること。
- 現在の制限: この自動化環境では LaunchServices の `open` が `kLSNoExecutableErr` を返す。bundle内実行ファイル、Info.plist、codesign、Mach-O の `minos 14.0` は検証済みだが、`lsregister -f` も `-10822 from spotlight` で失敗する。bundle内実行ファイルを `.app` コンテキストで直接起動すると HIServices `_RegisterApplication` 付近で `abort()` する一方、同じ配布bundle内実行ファイルを一時パスへコピーした smoke は通るため、制限環境のLaunchServices/HIServices制約として扱う。`./scripts/record_unsigned_bundle_open_verification.sh --operator "Codex"` も `kLSNoExecutableErr` により canonical 証跡を書かなかった。公開前に通常ユーザー環境で unsigned 配布なら `./scripts/record_unsigned_bundle_open_verification.sh --operator "Operator Name"`、notarized final配布なら `./scripts/record_bundle_open_verification.sh --operator "Operator Name"` を実行し、現在のZIP SHAと確認者に紐づくbundle-open証跡を作ること。
- 現在の制限: この自動化環境では `./scripts/record_unsigned_memory_check.sh --operator "Codex"` が `leaks[...]: [fatal] Couldn't get task port for pid ... immediately after launch` で失敗する。証跡は書かれていない。公開前に通常ユーザー環境で `./scripts/record_unsigned_memory_check.sh --operator "Operator Name"` を実行し、`leaks --atExit` が通った場合だけ current ZIP に紐づく `dist/release-evidence/unsigned-memory-check.txt` を残すこと。
- `src/` と `src-tauri/` は `docs/legacy-tauri/` 以下にアーカイブした。

## Legacy Tauri reference notes

以下は 2026-04-19 の Tauri 版作業ログとして残す。該当ファイルは `docs/legacy-tauri/` 以下にアーカイブ済み。2026-05-24 以降の現行公開手順は Swift/AppKit 版を正とし、README、`docs/RELEASE_QA.md`、`scripts/prepare_release_candidate.sh`、`scripts/check_publish_readiness.sh` を参照すること。

> 作成日: 2026-04-19
> 最新ビルド日: 2026-04-19

---

## 環境

| ツール | バージョン |
|--------|-----------|
| rustc | 1.95.0 |
| cargo | 1.95.0 |
| Tauri CLI | 2.10.1 |
| Tauri (rust crate) | 2.10.3 |
| @tauri-apps/cli | ^2.0.0 |
| @tauri-apps/api | ^2.0.0 |
| Node.js npm | 11.12.1 |

## プロジェクト構造

```
hazakura-wallpaper/
├── docs/legacy-tauri/
│   ├── src/                      # フロントエンド（静的ファイル）
│   │   ├── index.html            # fullscreen canvas。透明背景。
│   │   ├── sakura.js             # 桜アニメーション
│   │   └── icons/
│   │       └── tray-icon.png     # （未使用）
│   │   └── tray-icon.png         # （未使用）
│   └── src-tauri/                # バックエンド（Rust + Tauri v2）
│       ├── Cargo.toml
│       ├── build.rs
│       ├── Info.plist
│       ├── tauri.conf.json
│       ├── capabilities/
│       │   └── default.json
│       ├── icons/
│       │   ├── icon.icns
│       │   └── icon.png
│       └── src/
│           ├── main.rs
│           └── lib.rs
├── package.json
└── PROJECT_NOTES.md
```

## 重要な設定

### tauri.conf.json のポイント
- `identifier`: `com.sakurasky`
- `productName`: `Hazakura Wallpaper`
- `frontendDist`: `../src`
- macOS: `macOSPrivateApi: true`
- Window: 1920x1080, `transparent: true`, `decorations: false`, `skipTaskbar: true`, `alwaysOnTop: true`, `devtools: true`
- アイコン: `icons/icon.icns` のみ指定
- リソース: `"resources": ["icons/icon.png"]`（トレイアイコンとして bundle Resources/ にコピー）

### capabilities/default.json
```json
{
  "permissions": [
    "core:default",
    "core:event:allow-listen",
    "core:event:allow-emit"
  ]
}
```

**重要**: `core:event:allow-listen` を追加しないと、JS側で Tauri v2 の `listen()` がエラーになる。

### Info.plist
```xml
<key>LSUIElement</key>
<true/>
<key>NSHighResolutionCapable</key>
<true/>
```
`LSUIElement=true` でDockにアイコンを出さない（メニューバー常駐アプリ）。

## 機能

### 桜アニメーション (sakura.js) — リッチ演出
- **200枚のベジェカーブ petals**（+120→200）
- **10色のピンクグラデーション**（+7色→10色）
- **夜桜背景のグラデーション** — 透明→暗い桜色グラデーション（#1a0a15→#0a0510）
- **sparkle光の粒子** — 60個の十字架光＋グローが舞う
- **桜の木シルエット** — 左右端に枝+花clusterを配置
- **花瓣に陰影効果** — shadowBlur + 中央の筋（ベニス）
- **揺れ・転倒・落下落差** — より自然な movement oscillation
- Retina対応（`devicePixelRatio` スケール）
- マウス風向: マウス座標が風向を変える
  - `windX = 0.3 + mouseXNorm * 1.8`
  - `windY = fallSpeed + (-mouseYNorm * 1.0)`
- `requestAnimationFrame` ループ
- `paused` フラグ付き（アニメーション停止/再開対応）

| ツール | バージョン |
|--------|-----------|
| rustc | 1.95.0 |
| cargo | 1.95.0 |
| Tauri CLI | 2.10.1 |
| Tauri (rust crate) | 2.10.3 |
| @tauri-apps/cli | ^2.0.0 |
| @tauri-apps/api | ^2.0.0 |
| Node.js npm | 11.12.1 |

## プロジェクト構造

```
hazakura-wallpaper/
├── docs/legacy-tauri/
│   ├── src/                      # フロントエンド（静的ファイル）
│   │   ├── index.html
│   │   ├── sakura.js
│   │   └── icons/
│   │       └── tray-icon.png
│   │   └── tray-icon.png
│   └── src-tauri/                # バックエンド（Rust + Tauri v2）
│       ├── Cargo.toml
│       ├── build.rs
│       ├── Info.plist
│       ├── tauri.conf.json
│       ├── capabilities/
│       │   └── default.json
│       ├── icons/
│       │   ├── icon.icns
│       │   ├── icon.png
│       │   ├── 32x32.png
│       │   ├── 128x128.png
│       │   └── 128x128@2x.png
│       └── src/
│           ├── main.rs
│           └── lib.rs
├── package.json
└── PROJECT_NOTES.md              # このファイル
```

## 重要な設定

### tauri.conf.json のポイント
- `identifier`: `com.sakurasky`（⚠️ `.app` extension と衝突するので注意）
- `productName`: `Hazakura Wallpaper`（スペース含む！）
- `frontendDist`: `../src`
- macOS: `macOSPrivateApi: true`（署名槍が不要）
- Window: 1920x1080, `transparent: true`, `decorations: false`, `skipTaskbar: true`, `alwaysOnTop: true`
- アイコン: `icons/icon.icns` のみ指定（⚠️ PNG一覧を指定するとバンドルに失敗）
- リソース: `"resources": ["icons/icon.png"]`（トレイアイコンとして bundle Resources/ にコピー）

### Info.plist
```xml
<key>LSUIElement</key>
<true/>
<key>NSHighResolutionCapable</key>
<true/>
```
`LSUIElement=true` でDockにアイコンを出さない（メニューバー常駐アプリ）。

## 機能

### 桜アニメーション (sakura.js)
- 120枚のベジェカーブ花瓣
- 7色のピンクグラデーション（white center → pink edges の radial gradient）
- Retina対応（`devicePixelRatio` スケール）
- マウス風向: マウス座標が画面中心から -1〜1 にndし、風向を変える
  - `windX = 0.5 + mouseXNorm * 1.5`（0.5〜2.0の範囲に）
  - `windY = fallSpeed + (-mouseYNorm * 0.9)`（マウス上が押す）
- `requestAnimationFrame` ループ
- 画面外に出たら `reset()` → 再配置

### バックエンド設定 (lib.rs)
1. `ActivationPolicy::Accessory` メニューバー常駐。Dockにアイコン出さない。
2. Window初期: `set_ignore_cursor_events(true)` → クリック透過
3. トレイアイコン: PNG画像（`icons/icon.png`）を `Image::from_path()` で読み込み `TrayIconBuilder::icon()` に設定
4. トレイメニュー:
    - 停止ボタン: id = `"stop"`
    - 終了ボタン: id = `"quit"`
    - `app.on_menu_event()` で受付 + `window.emit("sakura-toggled", ())` でJSに送信
    - 終了は `std::process::exit(0)`

## ビルド

```bash
npm run dev                    # 開発モード
npm run build                  # releaseビルド
```

### ビルド成果物
- `.app`: `src-tauri/target/release/bundle/macos/Hazakura Wallpaper.app`
- `.dmg`: `src-tauri/target/release/bundle/dmg/Hazakura Wallpaper_1.0.0_aarch64.dmg`
- バイナリ: `src-tauri/target/release/hazakura-wallpaper`

## ⚠️ 既知の問題と回避策（作業ログ）

### 1. アイコン PNG → `.icns` 変更が必要（解決）
**問題**: `tauri.conf.json` でPNG一覧を指定すると `No matching IconType` でバンドルが失敗。
**解決**: `icons/icon.icns` だけを指定する。

### 2. bundle identifierの `.app` 衝突（解決）
**問題**: `identifier` に `.app` extention がつくと衝突。
**解決**: `identifier`: `com.sakurasky` に変更。

### 3. tray icon の画像設定（解決）
**解決**: 
- `Cargo.toml` に `"image-png"` feature
- `tauri.conf.json` に `"resources": ["icons/icon.png"]`
- `lib.rs` で `Image::from_path()` + `TrayIconBuilder::icon()`

### 4. `ActivationPolicy::Accessory` の設定タイミング
`tauri::Builder::setup()` **の先頭**で設定。

### 5. `focus: true` の削除
Tauri v2の `focus: true` はwindowが常にfocusを奪ってくる。削除。

### 6. `.gitignore` がない
`node_modules/`, `target/`, `.DS_Store` がgit管理。作成かどうかは後続。

### 7. MenuItemの新しいシグネチャ（解決済み）
- **正しい（現在）**: `MenuItem::with_id(app, "stop", "停止", true, None::<String>)`

### 8. Manager traitのimport
`get_webview_window()` には `use tauri::Manager;` が必要。

### 9. `.icns` は Tauri::Image で読めない（解決）
`Image::from_path()` は PNG と ICO のみ。トレイにはPNGを使う。

### 10. Tray menu event が動作しない（解決）
**原因の特定（2026-04-19）**:
- `MenuItem::new` ではなく `MenuItem::with_id` で明示的にidを指定
- `app.on_menu_event()` callbackで `item.id.as_ref()` の文字列比較で判定
- macOS Tray menuイベントは `muda::MenuEvent` に流れる

## 動作確認手順

1. `.app` を起動:
   ```bash
   open "src-tauri/target/release/bundle/macos/Hazakura Wallpaper.app"
   ```

---

## 2026-04-19 引き継ぎ作業ログ

### 完了したブラッシュアップ
- フロントエンドを透明デスクトップ表示ベースに戻し、トレイから「夜桜背景」を重ねられるように変更。
- トレイメニューを「停止/再開」「夜桜背景を表示/隠す」「終了」に整理。
- Tauri v2 のイベント受信を、静的HTMLでも動く `window.__TAURI__.event.listen` 優先の実装へ変更。
- ウィンドウを現在のモニタサイズへ合わせ、全ワークスペース表示を試みるように変更。
- `devtools: true` を本番設定から削除。
- `.gitignore` を追加し、`node_modules/`, `src-tauri/target/`, `.DS_Store` などの生成物を今後追跡しないようにした。

### 発生した問題と対応

#### DMG作成が失敗
**現象**: `bundle.targets: "all"` の状態で `npm run build` すると、`.app` 作成後に `bundle_dmg.sh` で失敗。

**対応**: macOSアプリ本体の完成を優先し、`tauri.conf.json` の `bundle.targets` を `["app"]` に変更。これにより `npm run build` は成功し、成果物は以下に生成される。

```bash
src-tauri/target/release/bundle/macos/Hazakura Wallpaper.app
```

**補足**: 配布用DMGが必要な場合は、`targets` に `dmg` を戻した上で `bundle_dmg.sh` の詳細ログを取り、macOSの `hdiutil` / Finder装飾処理まわりを追加調査する。

### 確認済み
```bash
npm run build
```

結果: release build と `.app` bundle 作成に成功。

---

## 2026-04-19 追加ブラッシュアップログ

### 回収した要望
- 桜の花びら形状を、先端に割れ込みのある桜らしい形へ変更。
- 花びらに加えて、少量の若葉を混ぜた「葉桜」らしい表情を追加。
- 5枚花びらの小さな桜花オブジェクトを追加。
- マウス位置に応じて風向きが変わるように調整。
- マウスに近い花びら・花・若葉が逃げる反応を追加。
- マウスが通った後に淡い余韻リングと流れ跡が出るようにした。
- 夜桜背景をよりリッチにし、月明かり、ビネット、枝先の花の光を追加。
- トレイメニューとHTMLメタ情報に「葉桜ラボ - とことんAIで遊ぶ研究所」を明記。

### 実装メモ
クリック透過ウィンドウではフロントエンドの `mousemove` だけだとマウス位置が取れないことがあるため、Rust側で `window.cursor_position()` を定期取得し、`sakura-cursor-moved` イベントでJSへ送る方式にした。JS側の `mousemove` は、ブラウザ単体確認時のフォールバックとして残している。

### 確認済み
```bash
node --check src/sakura.js
npm run build
```

結果: JavaScript構文チェック、release build、`.app` bundle 作成に成功。

---

## 2026-04-19 モードチェン追加ログ

### 回収した要望
- トレイメニューに「モード: SAKURA / Magic」を追加。
- `SAKURA` モードでは桜花・花びら・若葉が舞う従来表現を表示。
- `Magic` モードでは魔法の光のような粒子へ入れ替える表現を追加。
- マウス周りの枠線・軌跡表現を削除。
- マウス周りは薄いピンクまたは魔法色の上品な光だけに調整。

### 実装メモ
Rust側のトレイメニューでモード状態を保持し、`sakura-mode-changed` イベントで `sakura` / `magic` をJSへ送信。JS側は描画ループ内でモードに応じて `SakuraDrift` と `MagicLight` を切り替えている。マウス反発ロジックは維持しつつ、可視の線や軌跡は出さない。

### 追加修正
- モード表記を `Magic` に統一。
- SAKURA側を軽量な `SakuraDrift` ベースに作り直し、従来の重い花びら/花オブジェクト大量描画を描画ループから外した。
- Magic側と共通スパークルから、線っぽく見える硬い十字表現を削除し、柔らかい発光だけに変更。
- モード切り替えをトグルからチェック付き選択式に変更。`SAKURA` / `Magic` / `Spark` から選べる。
- Magic側の光点に出ていた黒っぽい外周対策として、円形クリップ描画をやめ、矩形のラジアルグラデーションで柔らかく発光させる方式に変更。
- 十字・線っぽい光は `Spark` モードとして分離。
- 「停止」を押したときはアニメーション停止だけでなく、canvasを即時クリアして画面上の表現を消すように変更。
- 2026-04-19追加: Sparkを含むモード選択を `CheckMenuItem` に変更し、選択中モードだけチェックが付くようにした。
- 2026-04-19追加: Magic/Sparkの発光で透明黒に落ちる可能性がある描画を避けるため、発光は `drawSoftGlow()` で矩形グラデーションとして描く方針に統一。
- 2026-04-19追加: サイトの桜色×新緑パレットに合わせた `Hazakura` モードを追加。
- 2026-04-19追加: 演出強度を `控えめ` / `標準` / `遊びすぎ` から選べるFocus設定として追加。描画数、透明度、反発、速度、サイズをまとめて調整する。
- 2026-04-19追加: 黒枠対策として、Magic以外の月光・花クラスタ・花芯の円形描画も `drawSoftGlow()` に寄せ、半透明円の境界が出にくい描画へ変更。

### 確認済み
```bash
node --check src/sakura.js
npm run build
```

結果: JavaScript構文チェック、release build、`.app` bundle 作成に成功。
   画面に桜の花びらが降り始め、メニューバーに桜アイコンが表示される。

2. メニューバーメニュー:
   - 停止: アニメーション停止/再開（currently broken! see issue #11）
   - 終了: app を終了

3. デスクトップでマウスを動かすと、風向が変わる。

## 停止ボタンイベントフロー（設計）

```
トレイメニュー「停止」クリック
  └→ Rust: `app.on_menu_event` callback
      └→ `window.emit("sakura-toggled", ())`
          └→ JS: `listen("sakura-toggled", ...)` で受信
              └→ `paused` フリップ → アニメーション停止/再開
```

## 🔴 現在の未解決問題（2026-04-19追加）

### 11. Tauri v2 イベント受信が動かない（**未解決 — 最重要**）

**症状**:
- トレイメニュー「停止」クリック → アニメーションが止まらない
- もう一度「停止」クリック → 再開しない
- Rust側ではイベント受信確認済み（ターミナルに `Tray menu event received: id=stop` が出る）
- **JS側はイベントを受信できない**

**確認済み**:
- ✅ イベントフロー: `MenuItem::with_id(app, "stop", ...)` でid="stop"
- ✅ Rust側イベント受信: `app.on_menu_event` callback が呼ばれてる
- ✅ Rust側emit: `window.emit("sakura-toggled", ())` を通して送信
- ✅ `devtools: true` 設定済み
- ✅ `capabilities/default.json` に `core:event:allow-listen` 追加済み

**デバッグの障害**:
- ❌ DevToolsが開かない — `Cmd+Option+I` が効かない
- ❌ JS側のエラーが確認できない
- ❌ `window.__TAURI__` が存在するか確認できない
- ❌ `listen()` がエラーになってるか確認できない

**試したJS受信コード**（指す全て動作せず）:
1. `window.addEventListener("sakura-toggled")` — Tauri v1方式。deprecated。
2. `import('@tauri-apps/api/event').then(({ listen }) => ...)` — v2方式だが動かない
3. `window.__TAURI__.event.listen()` — `withGlobalTauri` 方式。確認できず。

**考えられる原因**:
1. **`devtools: true` が効いていない** — releaseビルドには`devtools` featureが必要かも
2. **`withGlobalTauri: true` がบาง原因で効いてない** — `window.__TAURI__` undefined
3. **`listen()` に엄격한何もかもがない** — permissionまだ足りてない
4. **Rustの `window.emit()` が特定windowに届いてない** — 「main」ラベルのwindowが存在しない？
5. **macOS.private.api + transparent** の組み合わせが特殊

**次のステップ**:
- DevToolsを開ける方法を見つける（`cargo build` debugビルドで試す？or `tauri dev`）
- Rust側で `window.eval()` を使ってJSを実行し、DevToolsを使わずにデバッグする
- debugビルドで試す（releaseではなく）

### 12. 桜演出のリッチ化（完了 ✅）

**追加した要素**:
- 夜桜背景グラデーション — `#1a0a15→#2a1025→#1e0e20→#0a0510`
- 光の粒子（sparkle）60個 — 十字型光＋中心グロー
- 桜の木シルエット — 左右端に枝+花clusters
- 花瓣200枚（+120→200）
- 10色グラデーション（+7色→10色）
- 花瓣陰影 + 中央の筋
- より自然な movement oscillation

---

## 🔍 DevToolsを開く方法の調査中

**試したこと**:
- `tauri.conf.json` の `windows[].devtools: true` を設定
- `Cmd+Option+I` でキーボードショートカット実行
- → **DevToolsが開かない**

**候補**:
1. Releaseビルドではdevtoolsがデフォルトで無効。`features = ["devtools"]` が必要かも？
2. Transparent window + transparent background の組み合わせでTSF
3. 別のキーコンビネーションかも

## 2026-04-19 追加修正: Spark黒枠とメニュー階層感

- Sparkモードの十字演出は `ctx.stroke()` の線描画をやめ、小さな発光点を並べる塗りベースの描画に変更。
  - 透明ウィンドウ合成時に白背景で黒っぽい縁が出にくいようにした。
  - まだ残る場合は、次の手として半透明canvasへ直接描くのではなく、事前合成した小さな発光スプライトを描画する方式を検討する。
- トレイメニューに区切り線と「操作」見出しを追加。
  - 葉桜ラボのブランド表示の下に、操作 / モード / 演出の強さ / 終了が分かれる構成にした。

## 2026-04-19 追加修正: Spark再調整と黒線原因メモ

- Sparkの点列化は表現として弱く、壊れた印象が出たため再調整。
  - 星型の見た目に戻しつつ、`stroke()` / `globalCompositeOperation = 'lighter'` / 大きな透明グラデーション矩形を使わない実装に変更。
  - 現在は半透明の塗りパスと中心円だけで構成している。
- 黒っぽい縁が残る原因候補:
  1. 透明WebView + canvas半透明ピクセルの premultiplied alpha 合成由来。
  2. `lighter` 合成や透明グラデーション終端がmacOS側の合成で暗く見えるケース。
  3. 描画コードではなく、透明ウィンドウの合成レイヤー側で発生している可能性。
- まだ残る場合の次案:
  - Sparkをcanvas直描きではなく、明るい背景の上で事前合成した小さなPNG/WebPスプライトとして描く。
  - もしくは全canvasに極薄の白/ピンク下地を敷いて透明合成の暗い縁を抑える。ただし画面全体が少し霞む副作用あり。

## 2026-04-19 追加修正: マウス影響範囲由来の黒線対策

- ユーザー観察: 黒っぽい線はマウスカーソルの影響範囲を作り始めた頃から発生した可能性がある。
- 対応:
  - `drawPointerAura()` の可視描画を停止し、マウス周辺の薄い円形グローを完全に出さないようにした。
  - マウスによる風向き変化・逃げる挙動は維持。
  - Rust側で `window.set_shadow(false)` を追加し、透明オーバーレイウィンドウの影も明示的に無効化。
  - canvasに `pointer-events: none` を追加し、見た目以外でもカーソル干渉を避ける。
- これで残る場合は、Tauri/WebView/macOS の透明レイヤー合成仕様、または各パーティクルの半透明エッジが主因の可能性が高い。

## 2026-04-19 追加修正: Sakura / Hazakura 軽量化

- Sakura / Hazakura の重さ対策として、花びら・桜花・葉を毎フレーム直接描く方式から、事前生成した小さなcanvasスプライトを `drawImage()` で描く方式へ変更。
  - 毎フレームの `bezierCurveTo` / `ellipse` / `radialGradient` / `stroke` 生成を大幅に削減。
  - 見た目の桜らしさはスプライト側に持たせ、動き・回転・透明度だけをフレームごとに更新。
- Retina環境での全画面透明canvas負荷を抑えるため、描画DPRを最大1.5に制限。
- Sakura / Hazakura の基礎粒子数を少し整理。
  - Sakura: 152 → 122
  - Hazakura: 152 → 124
- 今後さらに軽くする場合:
  - モードごとに非表示粒子の update も止める。
  - 夜桜背景や枝もオフスクリーンキャッシュ化する。
  - 低負荷モードでは `requestAnimationFrame` を間引いて 30fps 近辺で動かす。

## 2026-04-19 追加修正: 配布前の小さいUX仕上げ

- これはTauri版当時の判断。Swift公開品質版では Developer ID署名・notarization を公開前必須ゲートとして扱う。
- トレイメニューに以下を追加。
  - `設定を初期化`: 停止状態・夜桜・モード・演出の強さを初期値に戻す。
  - `葉桜ラボを開く`: `https://hazakuralab.pages.dev` をブラウザで開く。
  - `このアプリについて`: Hazakura Wallpaper / 葉桜ラボの簡単な説明ダイアログを表示。
- 前回設定の保存を追加。
  - 保存対象: 夜桜背景、モード、演出の強さ。
  - 保存先: Tauriの app config directory 配下 `settings.json`。
  - 次回起動時にトレイメニューのチェック状態と表示状態へ反映する。
