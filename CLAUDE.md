# 腰門番 — 作業するときの約束ごと

このファイルは Claude Code が自動で読み込みます。どのマシンで作業しても同じ前提が伝わるよう、
機械的に守ってほしいことだけを書いてあります。設計の背景は [SPEC.md](SPEC.md) を参照してください。

## コミットの著者情報（最優先）

**このリポジトリは公開予定です。コミット履歴の著者情報も公開されます。**

作業を始める前に、このリポジトリの git 設定が noreply アドレスになっているか確認してください。

```bash
git config user.email
```

`25524188+sugiwe@users.noreply.github.com` 以外が出たら、次を実行してから作業を始めます。

```bash
git config user.name "sugiwe"
git config user.email "25524188+sugiwe@users.noreply.github.com"
```

`--global` ではなくリポジトリ単位の設定にしてください。他のリポジトリには影響させません。

過去に個人アドレスのまま入ったコミットが履歴に残っています。公開前に履歴を書き換えるかは
未決なので、**少なくともこれ以上増やさない**のが現時点の方針です。

## 変更の反映

`main` は保護されていませんが、直近の変更はすべて PR 経由で入っています。履歴を読みやすく
保つため、この流儀に合わせてください。

```bash
git checkout -b feature/<内容>
# 変更してコミット
gh pr create --base main
gh pr merge --squash --delete-branch
```

## 変更したら通すもの

```bash
./tests/run.sh                                    # 発動判定と URL 解析の検証
xcodebuild -project Koshimonban.xcodeproj -scheme Koshimonban -configuration Debug build
```

`Koshimonban/Sources` は Xcode の buildable folder なので、**ファイルを増やしても
`.xcodeproj` を編集する必要はありません。** `project.pbxproj` を手で編集しないでください。

## 実機での確認は人間に依頼する

このアプリは全画面を奪います。オーバーレイが本当に最前面に出るか、フルスクリーンのアプリの
上に出るか、入力を奪えているかは**画面を見ないと分かりません。** これらは自分で確認したことに
せず、ユーザーに実行と目視を依頼して、結果を待ってください。

動作確認のために `/Applications` のアプリを最新にする場合はこれを使います。

```bash
./tools/deploy.sh
```

## 判断に迷ったときの優先順位

SPEC.md の冒頭にあるとおり、このアプリの本質は「無視されにくさ」です。

1. 発動が確実であること
2. 逃げ道はあるが、摩擦があること
3. サボった事実が残ること
4. 見た目や機能の豊かさ（最下位）

見た目を良くする変更が 1 や 2 を損なう場合、見た目のほうを諦めてください。
