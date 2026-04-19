# Sakura Sky - Tauri Desktop Screensaver

桜の花びらがデスクトップを舞う、macOS常駐アプリ。

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
sakura-sky/
├── src/                          # フロントエンド（静的ファイル）
│   ├── index.html                # fullscreen canvas。透明背景。
│   ├── sakura.js                 # 桜アニメーション（200枚の花瓣 + sparkle + 桜の木）
│   └── icons/
│       └── tray-icon.png         # （未使用）
│   └── tray-icon.png             # （未使用）
├── src-tauri/                    # バックエンド（Rust + Tauri v2）
│   ├── Cargo.toml                # tauri="2"、features: macos-private-api, tray-icon, image-png
│   ├── build.rs                  # ビルドスクリプト（tauri_build::build()）
│   ├── Info.plist                # macOSエージェント宣言（LSUIElement=true）
│   ├── tauri.conf.json           # Tauri設定
│   ├── capabilities/
│   │   └── default.json          # core:default, core:event:allow-listen, core:event:allow-emit
│   ├── icons/
│   │   ├── icon.icns             # app bundle用アイコン
│   │   ├── icon.png              # trayアイコンとして使われる
│   ├── src/
│   │   ├── main.rs               # エントリーポイント
│   │   └── lib.rs                # 📍 重要ファイル。トレイ＋window設定
│   └── target/
├── package.json
└── PROJECT_NOTES.md
```

## 重要な設定

### tauri.conf.json のポイント
- `identifier`: `com.sakurasky`
- `productName`: `Sakura Sky`
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
sakura-sky/
├── src/                          # フロントエンド（静的ファイル）
│   ├── index.html                # 簡素なHTML。fullscreen canvas。透明背景。
│   ├── sakura.js                 # 桜アニメーション（120枚のベジェカーブ petals）
│   └── icons/
│       └── tray-icon.png         # （未使用）
│   └── tray-icon.png             # （未使用）
├── src-tauri/                    # バックエンド（Rust + Tauri v2）
│   ├── Cargo.toml                # crate manifest。tauri="2"、features: macos-private-api, tray-icon, image-png
│   ├── build.rs                  # ビルドスクリプト（tauri_build::build()）
│   ├── Info.plist                # macOSエージェント宣言（LSUIElement=true）
│   ├── tauri.conf.json           # Tauri設定（後述参照）
│   ├── capabilities/
│   │   └── default.json          # core:default permission
│   ├── icons/
│   │   ├── icon.icns             # app bundle用アイコン
│   │   ├── icon.png              # 1024x1024 PNG。トレイアイコンとして使われる
│   │   ├── 32x32.png             # 32x32
│   │   ├── 128x128.png           # 128x128
│   │   └── 128x128@2x.png        # 256x256
│   ├── src/
│   │   ├── main.rs               # エントリーポイント（5行）
│   │   └── lib.rs                # 📍 重要ファイル。トレイ＋window設定
│   └── target/                   # ビルド成果物（git ignoreしてない）
├── package.json
└── PROJECT_NOTES.md              # このファイル
```

## 重要な設定

### tauri.conf.json のポイント
- `identifier`: `com.sakurasky`（⚠️ `.app` extension と衝突するので注意）
- `productName`: `Sakura Sky`（スペース含む！）
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
- `.app`: `src-tauri/target/release/bundle/macos/Sakura Sky.app`
- `.dmg`: `src-tauri/target/release/bundle/dmg/Sakura Sky_1.0.0_aarch64.dmg`
- バイナリ: `src-tauri/target/release/sakura-sky`

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
   open "src-tauri/target/release/bundle/macos/Sakura Sky.app"
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
src-tauri/target/release/bundle/macos/Sakura Sky.app
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

- Developer ID署名・notarizationは費用がかかるため、現時点では未対応方針。
  - 未署名配布として、起動できない環境があることは保証外にする。
- トレイメニューに以下を追加。
  - `設定を初期化`: 停止状態・夜桜・モード・演出の強さを初期値に戻す。
  - `葉桜ラボを開く`: `https://hazakuralab.pages.dev` をブラウザで開く。
  - `このアプリについて`: Sakura Sky / 葉桜ラボの簡単な説明ダイアログを表示。
- 前回設定の保存を追加。
  - 保存対象: 夜桜背景、モード、演出の強さ。
  - 保存先: Tauriの app config directory 配下 `settings.json`。
  - 次回起動時にトレイメニューのチェック状態と表示状態へ反映する。
