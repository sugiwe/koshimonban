# Koshimonban スパイク検証

本実装に入る前に、設計の前提が macOS 15 で本当に成立するかだけを確かめる使い捨てアプリ。
確かめたいのは次の2点のみ。

1. **他アプリのネイティブフルスクリーンの「上」にオーバーレイが出るか**
2. **その時キーボードフォーカスを奪えるか**（画面は覆えているのにタイプは下のアプリに通る、が最悪）

## 手順

```bash
./build.sh
./build/KoshimonbanSpike.app/Contents/MacOS/KoshimonbanSpike --mode 1 --delay 10
```

実行すると 10 秒待つので、その間に **別アプリを緑ボタンでネイティブフルスクリーンにして**待つ。
外部ディスプレイがあれば繋いだ状態で。

オーバーレイが出たら、画面の指示どおり適当にキーを叩く。

## 記録すること（mode ごとに）

| 確認項目 | 見かた |
| --- | --- |
| フルスクリーンの上に出たか | 出ない / 出るが Space が切り替わる / そのまま上に出る |
| 外部ディスプレイも覆えたか | サブ画面に「サブ画面 N も覆えています」が出るか |
| 入力を奪えたか | `isKeyWindow` が **緑の YES** で、叩いた文字が画面に出るか |
| Space が勝手に切り替わったか | 切り替わるなら「割り込み」としては品質が落ちる |

## mode の切り替え

`--mode` で `collectionBehavior` の組み合わせを変えて比較する。
mode 1 が仕様書の案。ダメなら 2 → 4 の順に試す。

| mode | 組み合わせ |
| --- | --- |
| 1 | `.canJoinAllSpaces` + `.fullScreenAuxiliary`（仕様書の案） |
| 2 | `.canJoinAllSpaces` のみ |
| 3 | `.fullScreenAuxiliary` のみ |
| 4 | `.canJoinAllSpaces` + `.stationary` + `.fullScreenAuxiliary` + `.ignoresCycle` |

## その他のオプション

| オプション | 意味 |
| --- | --- |
| `--delay N` | 起動から表示までの秒数（既定 8） |
| `--duration N` | オーバーレイを出しておく秒数（既定 30） |
| `--level N` | ウィンドウレベルを数値で上書き（既定は `CGShieldingWindowLevel()`） |

## 抜けられなくなったら

`--duration` 秒で自動的に閉じる。それでも困ったら別ターミナルから:

```bash
pkill -x KoshimonbanSpike
```
