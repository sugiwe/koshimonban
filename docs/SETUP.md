# セットアップ手順

新しい Mac に入れるときの手順を、上から順に実行できる形で書いてある。
各ステップの「確認」を実行して、期待どおりの結果が出てから次へ進むこと。

**「人間がやること」と書いた手順は自動化できない**（パスワード入力、GUI 操作、目視確認）。

> このファイルは Claude Code などのコーディングエージェントに読ませて実行させることも
> 想定している。その場合、「人間がやること」はエージェントに実行させず、
> 依頼して待つこと。オーバーレイの表示確認も同様（エージェントには結果が見えない）。

---

## 0. 前提の確認

```bash
sw_vers                    # macOS 14 以上であること
xcodebuild -version        # Xcode 16 以上。エラーが出たら手順1へ
git --version
```

---

## 1. Xcode（入っていない場合のみ）

**人間がやること**: App Store から Xcode をインストールする。十数GB、30分〜1時間かかる。

```bash
open "macappstore://apps.apple.com/app/id497799835"
```

インストール後、**人間がやること**（パスワードを聞かれるため自動化できない）:

```bash
sudo xcodebuild -license accept
```

そのあとはコマンドで進められる:

```bash
xcodebuild -runFirstLaunch
```

**確認**:

```bash
xcodebuild -showsdks | grep macOS
```

macOS SDK が表示されれば OK。「ライセンスに同意していません」と出たら上の `sudo` が未実行。

---

## 2. リポジトリを取得

```bash
git clone https://github.com/sugiwe/koshimonban.git
cd koshimonban
```

### コミットの著者情報を設定する（コミットする前に必ず）

**このリポジトリは公開予定で、コミット履歴の著者情報も公開されます。**
個人のメールアドレスが履歴に入らないよう、このリポジトリだけ noreply アドレスを使います。

```bash
git config user.name "sugiwe"
git config user.email "25524188+sugiwe@users.noreply.github.com"
```

`--global` を付けないこと。このリポジトリの中だけの設定にします。

**確認**:

```bash
git config user.email    # 25524188+sugiwe@users.noreply.github.com と出れば OK
```

あわせて、GitHub の https://github.com/settings/emails で
**「Keep my email addresses private」と「Block command line pushes that expose my email」**
を有効にしておくことを勧めます。有効にすると、個人アドレスを含む push を GitHub が拒否するため、
マシンごとの設定を忘れても事故になりません。

---

## 3. 発動判定の検証（任意だが推奨）

Xcode がなくても走る。ここが通れば、少なくとも計算部分は健全。

```bash
./tests/run.sh
```

**確認**: 「すべて期待どおりです（0 件の失敗）」と出ること。

---

## 4. ビルドして /Applications に入れる

```bash
./tools/deploy.sh
```

ビルド → 既存プロセスの終了 → `/Applications/Koshimonban.app` にコピー → 起動、までを行う。

**なぜ /Applications なのか**: 次の手順で登録する LaunchAgent には
**アプリの実行ファイルのパスが直接書き込まれる**。ビルド出力先（DerivedData）のままだと
Xcode の都合で場所が変わりうるので、固定の場所に置く。

**確認**:

```bash
ps -Ao command | grep "Koshimonban.app" | grep -v grep
pgrep -x Koshimonban | wc -l          # 1 であること（多重起動していない）
```

`/Applications/Koshimonban.app/Contents/MacOS/Koshimonban` が動いていれば OK。

**人間がやること**: 画面右上のメニューバーに人型のアイコンが出ていることを目視で確認する。
Dock にはアイコンが出ない（`LSUIElement`）ので、そちらには現れない。

---

## 5. 作業時間帯を設定する

**人間がやること**（GUI 操作）:

1. メニューバーのアイコンをクリック →「設定を開く」
2. **「作業時間帯」タブ**で、実際の勤務時間に合わせる
   - 既定は 月〜金 の 10:00–12:00 と 14:00–17:00
   - 時刻は上部のピッカー、曜日は下の 月火水木金土日 ボタンで切り替える
   - 「作業時間帯を追加」で増やせる、ゴミ箱で消せる
3. 下部の**「今日の発動予定」**に実際の発動時刻が並ぶので、意図どおりか確認する

設定は `~/Library/Application Support/Koshimonban/settings.json` に保存される。
中身をコマンドで確認したい場合:

```bash
cat ~/Library/Application\ Support/Koshimonban/settings.json
```

### 発動時刻の決まり方

各作業時間帯の**開始時刻を起点とした固定グリッド**。

```
10:00–12:00 / 間隔30分 → 10:30, 11:00, 11:30
```

- 時間帯の終端（12:00）では発動しない
- 休憩が時間帯からはみ出す発動もしない（3分休憩なら 11:58 には発動しない）
- スキップしてもグリッドはズレない

---

## 6. 動画を登録する（任意）

**人間がやること**（GUI 操作）:

設定 →「動画」タブ →「YouTube を追加」で URL を貼る。
正しく解析できていれば緑で「動画 ID: xxxxx」と出る。
「ファイルを追加」でローカルの動画ファイルも選べる。

0件でも動作する（テキストとカウントダウンだけになる）。
複数登録すると発動ごとに切り替わり、前回と同じものは続けて出さない。

---

## 7. ログイン時の自動起動を登録する

**人間がやること**（GUI 操作）:

設定 →「一般」タブ →「起動」セクション →「**ログイン時に自動起動**」をオン。

オンにすると下に登録先のパスが表示される。`/Applications/Koshimonban.app/...` になっていること。
「/Applications の外にあります」という注意書きが出ていたら、手順4をやり直す。

**確認**（コマンドで実行できる）:

```bash
cat ~/Library/LaunchAgents/net.sugiwe.koshimonban.plist
launchctl print gui/$(id -u)/net.sugiwe.koshimonban | head -20
```

plist の `ProgramArguments` が `/Applications/Koshimonban.app/Contents/MacOS/Koshimonban` を
指していれば OK。

### 仕組みの補足

`SMAppService` ではなく LaunchAgent を使っている。前者は正しいコード署名を要求し、
無料 Apple ID の証明書は7日で失効してアプリが起動しなくなるため。

`KeepAlive` は `SuccessfulExit: false`。**異常終了したときは自動で復帰するが、
メニューの「終了」で終わらせた場合は復帰しない。** 逃げ道を塞がないための設定。

---

## 8. 動作確認

### 8-1. 短い休憩で試す

**人間がやること**:

1. 設定 →「一般」タブで **休憩の長さを 20 秒**にする（既定の180秒だと確認に3分かかる）
2. **フルスクリーンのアプリを開く**（Safari で動画でもエディタでも）
3. メニューバー →「今すぐ発動」

確認すること:

- フルスクリーンのアプリの**上に**オーバーレイが出るか
- 外部ディスプレイがあれば、そちらも覆われるか
- **「腰より仕事💀」が最初の5秒間押せず、数字が減っていくか**
- Esc を押しても閉じないか
- 「腰より仕事💀」を押すと理由の3択が出るか
- 「腰を守った✌️」で閉じるか

確認が終わったら**休憩の長さを 180 秒に戻す**。

### 8-2. 記録されるか

**人間がやること**: 設定 →「記録」タブ →「今日」に行が増えていること。

**確認**（コマンドで実行できる）:

```bash
cat ~/Library/Application\ Support/Koshimonban/logs/$(date +%Y-%m).json
```

### 8-3. 再起動しても立ち上がるか

**人間がやること**: 都合のよいタイミングで Mac を再起動し、
ログイン後にメニューバーのアイコンが出ていることを確認する。

---

## 逃げ道（先に把握しておくこと）

画面を奪うアプリなので、抜け方を知っておく。

| 状況 | 対処 |
| --- | --- |
| 今は発動してほしくない | メニューバーから「30分停止」「1時間停止」「今日はもう停止」 |
| オーバーレイから抜けたい | 「腰を守った✌️」または「腰より仕事💀」。カウントダウンが0になれば必ず閉じる |
| アプリごと止めたい | メニューバーから「腰門番を終了」、または `pkill -x Koshimonban` |
| 自動起動をやめたい | 設定 →「一般」→「ログイン時に自動起動」をオフ |

`Esc` では**閉じない**（意図的にそうしてある）。

---

## 記録は Mac ごとに別々になる

`~/Library/Application Support/Koshimonban/` はそのマシンのローカル。
複数の Mac で使うと記録が分裂し、達成率やヒートマップがそれぞれの Mac の分しか映らない。
同期は対象外。

**主に作業する Mac 1台だけで使うのが素直。**

---

## コードを直したとき

```bash
git pull
./tools/deploy.sh
```

アプリの置き場所は変わらないので、**自動起動の登録をやり直す必要はない。**

---

## 困ったときに見る場所

```bash
# 設定と記録
open ~/Library/Application\ Support/Koshimonban/

# アプリのログ（発動判定の記録が NSLog で出ている）
log show --predicate 'process == "Koshimonban"' --last 1h --info

# ビルドが失敗したとき
cat /tmp/koshimonban-build.log | grep error:
```

設定画面の「開発」タブに、スケジューラの状態と判定ログがそのまま出ている。
「いま判定する」ボタンで即座に判定を走らせられる。

### デバッグモード

実時間で待たずに動作を確認したいとき。設定 →「開発」タブ:

- **デバッグモード**をオン → 発動間隔と予告の単位が「分」ではなく「秒」になる
- **作業時間帯を無視**をオン → 時間帯の判定を飛ばして常に作業中とみなす
- 「一般」タブで 間隔 `60` / 休憩 `15` にすると、60秒ごとに15秒の休憩が来る

**デバッグモード中は記録されない**（開発中の発動で実データが埋まるのを防ぐため）。
確認が終わったら必ずオフに戻すこと。戻し忘れると数十秒おきに画面を奪われる。
