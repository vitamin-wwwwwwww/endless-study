# Endless Study

気の向くままに勉強を記録し、連続日数・レベル・ガチャ・バッジで「続けている実感」を得る iPhone アプリ。

## 必要なもの

- Mac、Xcode 15 以上
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）
- iOS 17 以上の iPhone またはシミュレータ

## ビルド

```bash
xcodegen generate
```

```bash
open EndlessStudy.xcodeproj
```

Xcode で `EndlessStudy` スキームを選び、実機またはシミュレータで実行する。
実機で動かす場合は Signing & Capabilities で自分の Team を選び、Bundle Identifier を自分のものに変える（`project.yml` の `PRODUCT_BUNDLE_IDENTIFIER`）。

## テスト

ルール計算（レベル・連続日数・ガチャ・バッジ）は `Packages/StudyCore` にあり、Xcode なしでテストできる。

```bash
cd Packages/StudyCore && swift test
```

## 構成

- `Packages/StudyCore` — UI にも SwiftData にも依存しないルールと集計
- `EndlessStudy` — SwiftUI + SwiftData のアプリ本体
- `docs/superpowers/specs` — 設計書

## 手動確認チェックリスト

- タイマーを開始し、アプリを終了して再起動しても計測が続いている
- 停止 → 保存で XP 表示が出る。15 分以上ならガチャ券が増える
- 手入力で未来日が選べない、0 分や 721 分では保存できない
- 同じ日に 15 分以上の記録を 4 件入れても券は 3 枚まで
- 記録タブの草カレンダーに今日の分が塗られる
- 履歴の記録をタップして編集、スワイプで削除できる
- タグを削除しても記録は「タグなし」として残る
- ガチャで得たテーマ色を装備するとアプリ全体の色が変わる
- 称号を装備するとホームのレベル横に表示される
