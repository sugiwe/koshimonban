# Tatsumaki

座りっぱなしを防ぐための macOS メニューバーアプリ。
決まった時刻に画面を物理的に奪って、立ち上がってストレッチさせる。

意志で続けるのは無理だという前提に立っており、このアプリの本質は
機能の豊かさではなく **「無視されにくさ」** にある。
設計方針の詳細は [SPEC.md](SPEC.md) を参照。

## 必要なもの

- macOS 14 以上
- Xcode 16 以上（開発は Xcode 26.3 / macOS 15.6.1 で行っている）

外部ライブラリへの依存はない。

## ビルドと実行

```bash
git clone https://github.com/sugiwe/tatsumaki.git
cd tatsumaki
xcodebuild -project Tatsumaki.xcodeproj -scheme Tatsumaki -configuration Debug build
```

ビルドした `.app` の場所は次のコマンドで分かる。

```bash
xcodebuild -project Tatsumaki.xcodeproj -scheme Tatsumaki -configuration Debug \
  -showBuildSettings 2>/dev/null | grep -m1 " BUILT_PRODUCTS_DIR" | awk '{print $3}'
```

起動する:

```bash
open "$(xcodebuild -project Tatsumaki.xcodeproj -scheme Tatsumaki -configuration Debug \
  -showBuildSettings 2>/dev/null | grep -m1 ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/Tatsumaki.app"
```

Dock にはアイコンが出ない（`LSUIElement`）。メニューバー右上の人型アイコンから操作する。

### 初回のみ必要な場合があるもの

Xcode を入れた直後は次が必要になることがある。

```bash
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
```

## データの保存先

```
~/Library/Application Support/Tatsumaki/
  settings.json        設定
  logs/YYYY-MM.json    記録（Phase 3 以降）
```

JSON なので直接開いて編集できる。読めない状態になっていた場合は
`.corrupt-日時` にリネームして退避し、既定値で起動する（消しはしない）。

**注意: このデータはマシンごとにローカル保存される。** 複数の Mac で使うと
記録が分裂し、達成率やヒートマップがそれぞれの Mac の分しか映らない。
同期は v1 の対象外。

## 複数の Mac で使う

Xcode が入れられる Mac なら、上のビルド手順をそのまま実行すればよい。

Xcode を入れられない Mac に持ち込む場合は、ビルド済みの `Tatsumaki.app` を
コピーする。ad-hoc 署名は特定のマシンに紐づかないため、そのまま動く。
ただし AirDrop やダウンロード経由で転送すると Gatekeeper に隔離属性を付けられ、
「開発元を確認できないため開けません」と出る。その場合は次のいずれかで通す。

- `.app` を右クリック →「開く」→ ダイアログで「開く」
- システム設定 →「プライバシーとセキュリティ」→「このまま開く」
- `xattr -d com.apple.quarantine /path/to/Tatsumaki.app`

`scp` や USB メモリ経由なら隔離属性が付かないことが多く、そのまま起動できる。

## 開発の進め方

実装は SPEC.md の「6. 実装フェーズ」に沿って進める。
各フェーズの末尾で一度止めて、人間が実機で目視確認する。

| フェーズ | 内容 | 状態 |
| --- | --- | --- |
| Phase -1 | スパイク検証（最前面表示とフォーカス奪取） | 完了 |
| Phase 0 | 土台（メニューバー常駐、設定の読み書き） | 完了 |
| Phase 1 | 発動の仕組み（スケジューラ、オーバーレイ） | 未着手 |
| Phase 2 | 動画 | 未着手 |
| Phase 3 | 記録 | 未着手 |
| Phase 4 | 仕上げ（自動起動、予告、一時停止） | 未着手 |

### spike/

Phase -1 で使った検証用の使い捨てアプリ。Xcode 不要で `swiftc` だけでビルドできる。
オーバーレイの実装で迷ったときの参照用に残してある。詳細は [spike/README.md](spike/README.md)。

## 構成

```
Tatsumaki/Sources/
  App/       エントリポイント、ライフサイクル
  Models/    設定・作業時間帯・動画エントリなどの型
  Storage/   JSON の読み書き、パス解決
  UI/        メニューバーと設定画面
```

`Tatsumaki/Sources` は Xcode の buildable folder として登録してある。
**ファイルを増やしても `.xcodeproj` を編集する必要はない。**
