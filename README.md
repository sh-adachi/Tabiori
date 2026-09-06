# たびおり / Tabiori

旅程、チケット、行きたい場所を一冊のしおりのようにまとめる、iPhone向けの旅行計画アプリです。SwiftUIで実装し、iOS 17以降に対応しています。

バージョン1.1では、外観、新しい旅の初期値、準備リスト、経路検索、共有の設定を追加しました。

`/Users/adachi/Developer/Tabiori` にある独立したGitリポジトリです。Yumeguriへの依存はなく、既存のYumeguriリポジトリには変更を加えていません。

GitHubの非公開リポジトリ：[sh-adachi/Tabiori](https://github.com/sh-adachi/Tabiori)。

## できること

- **旅行の管理**：旅行名、行き先、日程、メモを登録・編集・削除。これからの旅行と過去の旅を切り替え、キーワードで検索。
- **日別の旅程**：予定を時間順に表示。電車、飛行機、バス、飲食店、宿泊、観光・体験、その他に対応。完了の記録も可能。
- **交通・予約のメモ**：出発地・到着地、便名・列車名、予約番号、開始・終了日時、座席や乗り場などの自由記述。
- **飲食店・施設のメモ**：予約番号、費用、食べたいものや営業時間などを記録。
- **場所と地図**：Apple Mapsの施設名・住所検索、緯度・経度の手入力。保存した場所を旅行の地図に表示し、ピンを選んで予定や住所を確認。Appleのマップで経路検索を開けます。
- **写真・PDFの添付**：写真ライブラリ、または「ファイル」から取り込み。旅行全体や特定の予定に紐づけて保存し、プレビュー・共有・削除。
- **持ち物・準備チェック**：新しい旅行に準備リストを自動追加。自動追加のオン・オフとテンプレートを設定でき、旅行ごとに項目の追加・削除・完了状態を保存。
- **予算管理**：予定の費用を合計し、種類別の内訳と残り予算を表示。
- **旅程の共有**：旅行メニューから、予定・メモ・地図リンクをテキストで共有。「予約番号」欄を含めるか設定できます（初期値はオフ）。添付ファイル本体は書類のプレビューから個別に共有できます。
- **海外旅行の設定**：旅行ごとにタイムゾーンと通貨を指定。
- **アプリの設定**：端末に合わせる・ライト・ダークの外観、新しい旅の通貨・タイムゾーン、準備リスト、優先する移動手段、予約番号の共有を保存。

初回は空の状態から始まります。「サンプルの旅を見てみる」で、京都の操作体験用の旅を追加できます。サンプルの時刻・金額・予約情報は架空で、実際の予約や時刻表ではありません。

画面例：[旅行一覧](Artifacts/trips.png)、[旅程](Artifacts/itinerary.png)、[地図](Artifacts/map.png)、[場所検索](Artifacts/search.png)、[持ち物チェック](Artifacts/checklist.png)、[予約書類](Artifacts/documents.png)、[PDFプレビュー](Artifacts/pdf-preview.png)、[写真プレビュー](Artifacts/photo-preview.png)。画面内の旅行と書類はテスト用のサンプルです。

## 起動する

Xcodeで [Tabiori.xcodeproj](Tabiori.xcodeproj) を開き、Schemeを `Tabiori`、実行先を `iPhone 17 Pro` などのiPhoneシミュレータにして、Run（⌘R）を押してください。外部ライブラリ、APIキー、バックエンドの準備は不要です。

```sh
cd /Users/adachi/Developer/Tabiori
open Tabiori.xcodeproj
```

ターミナルからビルドする場合：

```sh
xcodebuild \
  -project Tabiori.xcodeproj \
  -scheme Tabiori \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

開発用プロジェクトにはPersonal Team（`92ZKW29LWX`）を設定しています。別のApple Accountで実機に入れる場合は、Xcodeの **Signing & Capabilities** で自分のTeamを選択し、必要に応じてBundle Identifier（初期値：`dev.adachi.tabiori`）を変更します。iPhoneの開発者モードを有効にし、実行先として選んでRunしてください。実機で `CODE_SIGNING_ALLOWED=NO` は使用しません。[Appleの実機・シミュレータ実行手順](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)を参照してください。

接続したiPhoneへの署名付きビルド、インストール、起動には補助スクリプトも使えます。XcodeにTeamのApple Accountが登録され、端末との接続・信頼設定が済んでいることが前提です。

```sh
xcrun xctrace list devices
bash Scripts/deploy_iphone.sh <iPhoneのUDID>
```

## 使い方

1. 一覧の「＋」から旅行名、行き先、日程を設定して保存します。
2. 旅行を開き「＋」から予定を作成。移動なら種類を電車・飛行機・バスにすると、出発地や便名の欄が表示されます。
3. 予定の「場所を追加」で検索結果を選び、予定を保存すると「地図」に表示されます。
4. 旅行の「書類」から写真・PDFを取り込みます。「追加先の予定」を選ぶと、その予約資料として紐づけられます。
5. 「準備」で持ち物を確認。「旅の費用」で予算と内訳を確認できます。
6. 一覧左上の歯車から「設定」を開けます。変更を反映するには「保存」を押します。「キャンセル」では変更を破棄します。「たびおりについて・使い方」も設定内にあります。

設定の初期値は、外観が端末に合わせる、通貨がJPY、タイムゾーンがAsia/Tokyo、準備リストの自動追加がオン、移動手段が公共交通機関、予約番号の共有がオフです。通貨・タイムゾーン・準備リストの設定は**これから作成する旅行**に使い、既存の旅行は変更しません。準備リストのテンプレートは1行に1項目で編集できます。経路検索の移動手段は公共交通機関・徒歩・車から選べます。

予約番号の共有をオフにすると、予定の「予約番号」欄を共有テキストから省きます。**自由記述のメモや添付書類に書かれた予約情報は除去しません。**

旅行期間は最大366日です。予定の開始・終了日時は旅行期間内で指定してください。旅行期間を短くした結果、既存の予定が期間外になる場合は保存エラーを表示します。先に予定を調整してください。

予定の時刻は**旅行で設定したタイムゾーン**に統一します。異なるタイムゾーンをまたぐ便では、到着時刻もそのタイムゾーンに換算して入力してください。タイムゾーンを変更すると同じ瞬間を新しい現地時刻で表示します。費用は旅行の通貨で集計し、為替の自動換算は行いません。

## 保存と通信

旅行はアプリ専用領域の `Library/Application Support/Tabiori/trips.json`、設定は同じ領域の `settings.json`、添付ファイルは `Attachments/` に保存します。取り込むのはコピーなので、元の写真・PDFを変更しません。

JSONは入力を検証してからアトミックに書き換え、成功して初めて画面の保存状態を更新します。読み込みに失敗した場合は既存データを保護するため変更を停止し、再読み込みを案内します。添付ファイルは本体の保存後にJSONを更新し、JSON保存が失敗した場合は追加した本体を削除します。

設定も検証後にアトミックに保存します。設定の読み込みに失敗した場合は設定の変更を停止し、設定画面から再読み込みできます。

添付は1件25 MiBまで。画像はImageIOで向きを適用し、長辺2,560 px以下のJPEGに変換します。元画像のEXIF・GPS情報は引き継ぎません。Live Photosやアニメーションは静止画として保存します。PDFは元の内容を保持し、破損・空・ロックされたPDFはエラーを表示します。

保存した予定、メモ、書類はオフラインで確認できます。地図の表示・場所検索には通信が必要です。現在地の取得は行わないため、位置情報の利用許可は不要です。場所検索と地図は[MapKit](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui)、写真の選択は[PhotosPicker](https://developer.apple.com/documentation/photosui/photospicker)を使っています。

この版は**端末内保存**です。クラウドへのアップロード・同期、共同編集、予約メールやPDFからの旅程の自動抽出、運行状況の自動更新、通知、データの一括バックアップ・復元は未実装です。アプリを削除するとアプリ内のデータも削除されます。App Storeへの公開は行っていません。

## 検証

Xcode 26.3でiPhoneシミュレータ向けビルドを確認済みです。設定機能を含むSwift Packageの単体テストは41件成功しています。JSON保存・読込失敗時の保護、暦日・夏時間・金額・座標の検証に加え、実際の画像の縮小・回転・メタデータ除去、正常・破損・暗号化PDFの取り込み判定、設定の保存・入力検証・予約番号の共有制御を検証しています。

2026年9月6日、設定機能の追加前にiPhone 17 Proシミュレータ（iOS 26.3）でUIテスト8件すべて成功しました。旅行の作成・編集・キャンセル・削除、予定とチェック状態の復元、手動座標とApple Maps実検索からの保存、地図の行き先一覧、実際の写真・PDFピッカーからの取り込み・プレビュー・復元、写真削除を確認しています。結果はローカルの `Artifacts/VerifiedUITests.xcresult` に保存しています。

バージョン1.1では設定の保存・再起動後の復元、新しい旅行だけへの初期値適用、キャンセル時の変更破棄を確認する追加UIテスト2件も成功しました。結果は `Artifacts/SettingsVerified.xcresult`、画面例は[設定画面](Artifacts/settings.png)です。スクリーンショットのUSD・自動追加オフはテストで選んだ値で、初期設定はJPY・オンです。

2026年9月6日、バージョン1.1（ビルド2）をiPhone 17（iOS 26.6）向けに署名付きでビルドし、接続した実機へのインストールと起動に成功しました。アプリ一覧の「たびおり」から開けます。開発用署名の期限が切れた場合は、上記の実機導入スクリプトでビルド・インストールし直してください。

共有ロジックのテスト：

```sh
swift test --scratch-path .build/swift-tests
```

シミュレータの画面操作テスト：

```sh
# 起動済みのシミュレータの「ファイル」と「写真」に、テスト用PDF・画像を用意
bash Scripts/prepare_ui_fixtures.sh booted

xcodebuild \
  -project Tabiori.xcodeproj \
  -scheme Tabiori \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/DerivedData \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  test
```

UIテストは `--uitesting` で起動し、通常の旅行とは別の `Tabiori-UITests` ディレクトリを使います。`--reset-data` は `--uitesting` と同時指定した場合だけテスト用データを初期化します。

取り込みテストはiOSの実際の写真ピッカーとファイルピッカーを操作します。準備スクリプトはシミュレータの「このiPhone内」の `Tabiori-UITests` フォルダに架空のチケットPDFと画像をコピーし、画像を写真ライブラリにも追加します。既存のファイルは削除しません。

Apple Mapsの実検索テストには通信が必要です。オフラインで検証する場合は、xcodebuildに `-skip-testing:TabioriUITests/TabioriUITests/testLivePlaceSearchAndSave` を加えてください。iCloud上のファイルや写真のダウンロード中断、実機での取り込み・経路案内、VoiceOver、iOS 17での表示は手動確認項目です。

## 構成

```text
Tabiori.xcodeproj/        アプリとUIテストのXcodeプロジェクト
App/
  TabioriApp.swift        起動・日本語表示設定
  AppStore.swift          状態管理、保存と読み込みエラー処理
  Views/                 一覧、旅程、編集、地図、書類、準備、費用、設定
  Services/              写真・PDFの読み込みと画像変換
  Assets.xcassets/        アプリアイコン・アクセントカラー
Core/                    モデル、設定、入力検証、JSONと添付の保存、共有テキスト
Tests/TravelCoreTests/    共有ロジックのテスト
Tests/AttachmentSupportTests/  画像・PDF変換のテスト
UITests/                 iPhone画面を操作するテスト
Scripts/                 アイコン・テスト資料生成、実機ビルドとインストール
Package.swift            TravelCoreのSwift Package定義
```

Xcodeは同期フォルダを使用するため、`App/`・`Core/`に追加したSwiftファイルを自動的にビルド対象へ含めます。Swift 5言語モードで、Apple標準フレームワークだけで構成しています。
