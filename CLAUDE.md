# 腰門番 — 作業するときの約束ごと

このファイルは Claude Code が自動で読み込みます。どのマシンで作業しても同じ前提が伝わるよう、
機械的に守ってほしいことだけを書いてあります。設計の背景は [SPEC.md](SPEC.md) を参照してください。

## コミットの著者情報（最優先）

**このリポジトリは公開予定です。コミット履歴の著者情報も公開されます。**

### 原因は GitHub 側の設定にある

履歴に個人アドレスが混ざっているが、**その全件が committer=GitHub、つまり squash マージや
web 編集で GitHub が作ったコミット**である。ローカルの git 設定が原因のものは1件もない。

**GitHub は squash マージのとき、著者をアカウントの主要メールアドレスに置き換える。**
ローカルで noreply を設定していても、PR をマージした時点で個人アドレスに戻る。

したがって本質的な対策はこれ一つ。

- https://github.com/settings/emails で **「Keep my email addresses private」を有効にする**

有効にすると、GitHub が作るコミットの著者が noreply アドレスになる。
アカウント単位の設定なので、どのマシンから作業しても効く。

**PR をマージする前に、この設定が有効か確認すること。** 無効のままマージすると、
そのコミットに個人アドレスが入る。

### ローカルの git 設定（副次的）

`main` へ直接 push する場合はローカルの設定がそのまま著者になる。念のため揃えておく。

```bash
git config user.name "sugiwe"
git config user.email "25524188+sugiwe@users.noreply.github.com"
```

`--global` ではなくリポジトリ単位の設定にすること。他のリポジトリには影響させない。

あわせて同じ設定画面の **「Block command line pushes that expose my email」** を有効にすると、
個人アドレスを含む push を GitHub が拒否するため、設定を忘れても事故にならない。

過去に入った分を消すかは未決。現時点の方針は **これ以上増やさない** こと。

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
