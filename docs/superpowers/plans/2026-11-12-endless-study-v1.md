# Endless Study v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 自由記録 + 任意タグの勉強記録 iPhone アプリを作り、連続日数・草カレンダー・XP/レベル・ガチャ・実績バッジで継続実感を与える。

**Architecture:** ごほうびルールと集計はすべて、Foundation のみに依存する Swift パッケージ `StudyCore` に置き、Linux (Docker) と Mac の両方で `swift test` できるようにする。アプリ本体 `EndlessStudy` は SwiftUI + SwiftData で、`@Query` で取得した記録を `StudyCore` に渡して表示値を得る。記録の保存と券付与は `RecordService` の 1 か所に集約する。

**Tech Stack:** Swift 5.9+ / SwiftUI / SwiftData / XCTest / XcodeGen。外部ライブラリなし。

## Global Constraints

- iOS 17.0 以上、iPhone のみ。外部ライブラリは使わない。
- UI 文言はすべて日本語。
- XP: 1 分 = 1 XP。レベル L 到達の累計 XP は `50 × L × (L − 1)`。上限なし。
- 連続日数: 1 日 1 分以上で継続。区切りは端末ローカル時刻の 0 時。今日未記録なら昨日から数える。
- ガチャ券: 15 分以上の記録 1 件 = 1 枚、記録の日付ごとに 3 枚まで。付与判定は新規保存時のみ。編集・削除で取り消さない。
- 排出率: N 70% / R 25% / SR 4.5% / SSR 0.5%。景品数 N 12 / R 8 / SR 4 / SSR 2。ダブり XP: N 10 / R 30 / SR 100 / SSR 500。
- タイマー: 開始日時との差分で算出、分単位切り上げ、1〜720 分に丸める。手入力も 1〜720 分、未来日不可。
- XP・レベル・連続日数・バッジは保存せず記録から都度計算する。保存するのは券残数・ボーナス XP・装備中 ID のみ。
- 日付またぎの記録は開始日に全量計上する。
- `StudyCore` は `Foundation` 以外を import しない。現在日時・カレンダー・乱数は引数で受け取る。

## 検証コマンド

`StudyCore` のテスト（Linux。リポジトリルートで実行。Docker デーモンが止まっていれば先に `dockerd &` を実行）:

```bash
docker run --rm -v "$PWD/Packages/StudyCore":/pkg -w /pkg swift:6.0-noble swift test
```

Mac では `cd Packages/StudyCore && swift test`。

アプリ側 Swift の構文チェック（Linux。SwiftUI が無いため型検査はできず、構文のみ）:

```bash
docker run --rm -v "$PWD":/src -w /src swift:6.0-noble sh -c 'find EndlessStudy -name "*.swift" -print0 | xargs -0 swiftc -frontend -parse'
```

期待: 出力なし・終了コード 0。アプリの型検査とビルドは Mac の Xcode でのみ可能（Task 10 の README 手順）。

## File Structure

```
project.yml                                  XcodeGen 定義
.gitignore
README.md                                    ビルド手順
Packages/StudyCore/
  Package.swift
  Sources/StudyCore/
    SessionRecord.swift                      記録の値型
    Leveling.swift                           XP → レベル
    Stats.swift                              日別・タグ別集計
    Streak.swift                             連続日数
    Heatmap.swift                            草カレンダーの格子と濃淡
    TimerMath.swift                          経過秒 → 分
    Rewards.swift                            Rarity / Reward / RewardCatalog
    Gacha.swift                              抽選・券付与
    Badges.swift                             バッジ定義と判定
    Progress.swift                           ProgressSnapshot / RecordEvaluator
  Tests/StudyCoreTests/
    TestSupport.swift                        UTC カレンダー、日付ヘルパ、シード付き乱数
    LevelingTests.swift / StatsTests.swift / StreakTests.swift / HeatmapTests.swift
    TimerMathTests.swift / GachaTests.swift / BadgesTests.swift / ProgressTests.swift
EndlessStudy/
  App/EndlessStudyApp.swift                  エントリポイント、ModelContainer
  App/RootView.swift                         タブ構成、AppRouter、テーマ色
  Models/Models.swift                        SwiftData モデル 4 種
  Services/RecordService.swift               保存・券付与・ガチャ
  Services/TimerStore.swift                  計測中タイマーの永続化
  Support/Formatters.swift                   分数表示、Color(hex:)、TagPalette
  Features/Home/HomeView.swift               ホーム、タイマー
  Features/Record/SessionFormView.swift      保存シート・手入力・編集
  Features/Record/ResultView.swift           保存直後の報酬表示
  Features/History/HeatmapView.swift         草カレンダー
  Features/History/HistoryView.swift         タグ別累計、履歴
  Features/Collection/CollectionView.swift   ガチャ、景品、バッジ
```

設計書 7 章の `Logic/` は `Packages/StudyCore` に、`EndlessStudyTests/` は `Packages/StudyCore/Tests` に置き換える（Linux でテストを回すため）。

---

### Task 1: StudyCore パッケージの土台と Leveling

**Files:**
- Create: `.gitignore`
- Create: `Packages/StudyCore/Package.swift`
- Create: `Packages/StudyCore/Sources/StudyCore/SessionRecord.swift`
- Create: `Packages/StudyCore/Sources/StudyCore/Leveling.swift`
- Create: `Packages/StudyCore/Tests/StudyCoreTests/TestSupport.swift`
- Test: `Packages/StudyCore/Tests/StudyCoreTests/LevelingTests.swift`

**Interfaces:**
- Produces:
  - `struct SessionRecord: Equatable, Sendable { let startedAt: Date; let minutes: Int; let tagID: UUID?; init(startedAt:minutes:tagID:) }`
  - `struct LevelProgress: Equatable, Sendable { let level: Int; let xpIntoLevel: Int; let xpForNextLevel: Int; var fraction: Double }`
  - `enum Leveling { static func totalXP(toReach level: Int) -> Int; static func level(forXP: Int) -> Int; static func progress(forXP: Int) -> LevelProgress }`
  - テスト用: `let utc: Calendar`、`func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date`、`struct SeededRNG: RandomNumberGenerator { init(seed: UInt64) }`

- [ ] **Step 1: .gitignore とパッケージ定義を作る**

`.gitignore`:

```
.build/
DerivedData/
*.xcodeproj
xcuserdata/
.DS_Store
.swiftpm/
```

`Packages/StudyCore/Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StudyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "StudyCore", targets: ["StudyCore"])],
    targets: [
        .target(name: "StudyCore"),
        .testTarget(name: "StudyCoreTests", dependencies: ["StudyCore"]),
    ]
)
```

`Packages/StudyCore/Sources/StudyCore/SessionRecord.swift`:

```swift
import Foundation

public struct SessionRecord: Equatable, Sendable {
    public let startedAt: Date
    public let minutes: Int
    public let tagID: UUID?

    public init(startedAt: Date, minutes: Int, tagID: UUID? = nil) {
        self.startedAt = startedAt
        self.minutes = minutes
        self.tagID = tagID
    }
}
```

`Packages/StudyCore/Tests/StudyCoreTests/TestSupport.swift`:

```swift
import Foundation

let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 1
    return calendar
}()

func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
}

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
```

- [ ] **Step 2: 失敗するテストを書く**

`Packages/StudyCore/Tests/StudyCoreTests/LevelingTests.swift`:

```swift
import XCTest
@testable import StudyCore

final class LevelingTests: XCTestCase {
    func testTotalXPToReachLevel() {
        XCTAssertEqual(Leveling.totalXP(toReach: 1), 0)
        XCTAssertEqual(Leveling.totalXP(toReach: 2), 100)
        XCTAssertEqual(Leveling.totalXP(toReach: 3), 300)
        XCTAssertEqual(Leveling.totalXP(toReach: 4), 600)
    }

    func testLevelBoundaries() {
        XCTAssertEqual(Leveling.level(forXP: 0), 1)
        XCTAssertEqual(Leveling.level(forXP: 99), 1)
        XCTAssertEqual(Leveling.level(forXP: 100), 2)
        XCTAssertEqual(Leveling.level(forXP: 299), 2)
        XCTAssertEqual(Leveling.level(forXP: 300), 3)
    }

    func testNegativeXPIsLevelOne() {
        XCTAssertEqual(Leveling.level(forXP: -5), 1)
    }

    func testProgressWithinLevel() {
        let p = Leveling.progress(forXP: 150)
        XCTAssertEqual(p, LevelProgress(level: 2, xpIntoLevel: 50, xpForNextLevel: 200))
        XCTAssertEqual(p.fraction, 0.25, accuracy: 0.0001)
    }
}
```

- [ ] **Step 3: テストが失敗することを確認する**

Run: `docker run --rm -v "$PWD/Packages/StudyCore":/pkg -w /pkg swift:6.0-noble swift test`
Expected: コンパイルエラー `cannot find 'Leveling' in scope`

- [ ] **Step 4: 実装する**

`Packages/StudyCore/Sources/StudyCore/Leveling.swift`:

```swift
import Foundation

public struct LevelProgress: Equatable, Sendable {
    public let level: Int
    public let xpIntoLevel: Int
    public let xpForNextLevel: Int

    public init(level: Int, xpIntoLevel: Int, xpForNextLevel: Int) {
        self.level = level
        self.xpIntoLevel = xpIntoLevel
        self.xpForNextLevel = xpForNextLevel
    }

    public var fraction: Double {
        xpForNextLevel > 0 ? Double(xpIntoLevel) / Double(xpForNextLevel) : 0
    }
}

public enum Leveling {
    public static func totalXP(toReach level: Int) -> Int {
        50 * level * (level - 1)
    }

    public static func level(forXP xp: Int) -> Int {
        var level = 1
        while totalXP(toReach: level + 1) <= xp { level += 1 }
        return level
    }

    public static func progress(forXP xp: Int) -> LevelProgress {
        let xp = max(0, xp)
        let level = level(forXP: xp)
        let base = totalXP(toReach: level)
        return LevelProgress(
            level: level,
            xpIntoLevel: xp - base,
            xpForNextLevel: totalXP(toReach: level + 1) - base
        )
    }
}
```

- [ ] **Step 5: テストが通ることを確認する**

Run: `docker run --rm -v "$PWD/Packages/StudyCore":/pkg -w /pkg swift:6.0-noble swift test`
Expected: `Executed 4 tests, with 0 failures`

- [ ] **Step 6: コミット**

```bash
git add .gitignore Packages/StudyCore
git commit -m "feat(core): StudyCore パッケージと Leveling を追加"
```

---

### Task 2: Stats・Streak・Heatmap・TimerMath

**Files:**
- Create: `Packages/StudyCore/Sources/StudyCore/Stats.swift`
- Create: `Packages/StudyCore/Sources/StudyCore/Streak.swift`
- Create: `Packages/StudyCore/Sources/StudyCore/Heatmap.swift`
- Create: `Packages/StudyCore/Sources/StudyCore/TimerMath.swift`
- Test: `Packages/StudyCore/Tests/StudyCoreTests/StatsTests.swift`
- Test: `Packages/StudyCore/Tests/StudyCoreTests/StreakTests.swift`
- Test: `Packages/StudyCore/Tests/StudyCoreTests/HeatmapTests.swift`
- Test: `Packages/StudyCore/Tests/StudyCoreTests/TimerMathTests.swift`

**Interfaces:**
- Consumes: `SessionRecord`、テスト用 `utc` / `day(...)`
- Produces:
  - `enum Stats { static func dailyTotals(_: [SessionRecord], calendar: Calendar) -> [Date: Int]`（キーはその日の `startOfDay`）`; static func totalMinutes(_: [SessionRecord]) -> Int; static func tagTotals(_: [SessionRecord]) -> [UUID?: Int]; static func distinctTagCount(_: [SessionRecord]) -> Int }`
  - `struct StreakInfo: Equatable, Sendable { let current: Int; let longest: Int }`
  - `enum Streak { static func compute(studyDays: Set<Date>, today: Date, calendar: Calendar) -> StreakInfo }`
  - `enum Heatmap { static func intensity(minutes: Int) -> Int`（0〜4）`; static func weeks(endingOn: Date, weekCount: Int = 26, calendar: Calendar) -> [[Date?]] }`（列 = 週、各列 7 要素、未来日は `nil`）
  - `enum TimerMath { static let maxMinutes = 720; static func elapsedMinutes(from: Date, to: Date) -> Int }`

- [ ] **Step 1: 失敗するテストを書く**

`StatsTests.swift`:

```swift
import XCTest
@testable import StudyCore

final class StatsTests: XCTestCase {
    func testDailyTotalsGroupsByStartDay() {
        let sessions = [
            SessionRecord(startedAt: day(2026, 11, 10, hour: 9), minutes: 30),
            SessionRecord(startedAt: day(2026, 11, 10, hour: 20), minutes: 15),
            SessionRecord(startedAt: day(2026, 11, 11, hour: 8), minutes: 60),
        ]
        let totals = Stats.dailyTotals(sessions, calendar: utc)
        XCTAssertEqual(totals[utc.startOfDay(for: day(2026, 11, 10))], 45)
        XCTAssertEqual(totals[utc.startOfDay(for: day(2026, 11, 11))], 60)
        XCTAssertEqual(totals.count, 2)
    }

    func testSessionCrossingMidnightCountsOnStartDay() {
        let sessions = [SessionRecord(startedAt: day(2026, 11, 10, hour: 23), minutes: 120)]
        let totals = Stats.dailyTotals(sessions, calendar: utc)
        XCTAssertEqual(totals, [utc.startOfDay(for: day(2026, 11, 10)): 120])
    }

    func testTotalsAndTags() {
        let a = UUID(), b = UUID()
        let sessions = [
            SessionRecord(startedAt: day(2026, 11, 10), minutes: 30, tagID: a),
            SessionRecord(startedAt: day(2026, 11, 11), minutes: 20, tagID: a),
            SessionRecord(startedAt: day(2026, 11, 11), minutes: 10, tagID: b),
            SessionRecord(startedAt: day(2026, 11, 12), minutes: 5),
        ]
        XCTAssertEqual(Stats.totalMinutes(sessions), 65)
        XCTAssertEqual(Stats.tagTotals(sessions), [a: 50, b: 10, nil: 5])
        XCTAssertEqual(Stats.distinctTagCount(sessions), 2)
    }
}
```

`StreakTests.swift`:

```swift
import XCTest
@testable import StudyCore

final class StreakTests: XCTestCase {
    private func days(_ list: [(Int, Int)]) -> Set<Date> {
        Set(list.map { day(2026, $0.0, $0.1) })
    }

    func testNoRecords() {
        XCTAssertEqual(Streak.compute(studyDays: [], today: day(2026, 11, 12), calendar: utc),
                       StreakInfo(current: 0, longest: 0))
    }

    func testStudiedTodayCountsToday() {
        let info = Streak.compute(studyDays: days([(11, 10), (11, 11), (11, 12)]),
                                  today: day(2026, 11, 12), calendar: utc)
        XCTAssertEqual(info, StreakInfo(current: 3, longest: 3))
    }

    func testNotYetStudiedTodayCountsFromYesterday() {
        let info = Streak.compute(studyDays: days([(11, 10), (11, 11)]),
                                  today: day(2026, 11, 12), calendar: utc)
        XCTAssertEqual(info.current, 2)
    }

    func testBrokenStreakIsZeroButLongestRemains() {
        let info = Streak.compute(studyDays: days([(11, 1), (11, 2), (11, 3), (11, 4), (11, 9)]),
                                  today: day(2026, 11, 12), calendar: utc)
        XCTAssertEqual(info, StreakInfo(current: 0, longest: 4))
    }

    func testStreakAcrossMonthBoundary() {
        let info = Streak.compute(studyDays: days([(10, 30), (10, 31), (11, 1)]),
                                  today: day(2026, 11, 1), calendar: utc)
        XCTAssertEqual(info, StreakInfo(current: 3, longest: 3))
    }
}
```

`HeatmapTests.swift`（2026-11-12 は木曜、週の始まりは日曜）:

```swift
import XCTest
@testable import StudyCore

final class HeatmapTests: XCTestCase {
    func testIntensityBuckets() {
        XCTAssertEqual(Heatmap.intensity(minutes: 0), 0)
        XCTAssertEqual(Heatmap.intensity(minutes: 1), 1)
        XCTAssertEqual(Heatmap.intensity(minutes: 29), 1)
        XCTAssertEqual(Heatmap.intensity(minutes: 30), 2)
        XCTAssertEqual(Heatmap.intensity(minutes: 59), 2)
        XCTAssertEqual(Heatmap.intensity(minutes: 60), 3)
        XCTAssertEqual(Heatmap.intensity(minutes: 119), 3)
        XCTAssertEqual(Heatmap.intensity(minutes: 120), 4)
    }

    func testWeeksGrid() {
        let weeks = Heatmap.weeks(endingOn: day(2026, 11, 12), calendar: utc)
        XCTAssertEqual(weeks.count, 26)
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })

        let last = weeks[25]
        XCTAssertEqual(last[0], utc.startOfDay(for: day(2026, 11, 8)))
        XCTAssertEqual(last[4], utc.startOfDay(for: day(2026, 11, 12)))
        XCTAssertNil(last[5])
        XCTAssertNil(last[6])

        XCTAssertEqual(weeks[0][0], utc.startOfDay(for: day(2026, 5, 17)))
    }
}
```

`TimerMathTests.swift`:

```swift
import XCTest
@testable import StudyCore

final class TimerMathTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testRoundsUpToMinute() {
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start.addingTimeInterval(1)), 1)
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start.addingTimeInterval(60)), 1)
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start.addingTimeInterval(61)), 2)
    }

    func testClampsToRange() {
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start), 1)
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start.addingTimeInterval(-500)), 1)
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start.addingTimeInterval(13 * 3600)), 720)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `docker run --rm -v "$PWD/Packages/StudyCore":/pkg -w /pkg swift:6.0-noble swift test`
Expected: コンパイルエラー `cannot find 'Stats' in scope` など

- [ ] **Step 3: 実装する**

`Stats.swift`:

```swift
import Foundation

public enum Stats {
    public static func dailyTotals(_ sessions: [SessionRecord], calendar: Calendar) -> [Date: Int] {
        var totals: [Date: Int] = [:]
        for session in sessions {
            totals[calendar.startOfDay(for: session.startedAt), default: 0] += session.minutes
        }
        return totals
    }

    public static func totalMinutes(_ sessions: [SessionRecord]) -> Int {
        sessions.reduce(0) { $0 + $1.minutes }
    }

    public static func tagTotals(_ sessions: [SessionRecord]) -> [UUID?: Int] {
        var totals: [UUID?: Int] = [:]
        for session in sessions {
            totals[session.tagID, default: 0] += session.minutes
        }
        return totals
    }

    public static func distinctTagCount(_ sessions: [SessionRecord]) -> Int {
        Set(sessions.compactMap(\.tagID)).count
    }
}
```

`Streak.swift`:

```swift
import Foundation

public struct StreakInfo: Equatable, Sendable {
    public let current: Int
    public let longest: Int

    public init(current: Int, longest: Int) {
        self.current = current
        self.longest = longest
    }
}

public enum Streak {
    public static func compute(studyDays: Set<Date>, today: Date, calendar: Calendar) -> StreakInfo {
        let days = Set(studyDays.map { calendar.startOfDay(for: $0) })
        func shifted(_ date: Date, by value: Int) -> Date {
            calendar.startOfDay(for: calendar.date(byAdding: .day, value: value, to: date)!)
        }

        let todayStart = calendar.startOfDay(for: today)
        var cursor = days.contains(todayStart) ? todayStart : shifted(todayStart, by: -1)
        var current = 0
        while days.contains(cursor) {
            current += 1
            cursor = shifted(cursor, by: -1)
        }

        var longest = 0
        for runStart in days where !days.contains(shifted(runStart, by: -1)) {
            var length = 1
            var next = shifted(runStart, by: 1)
            while days.contains(next) {
                length += 1
                next = shifted(next, by: 1)
            }
            longest = max(longest, length)
        }
        return StreakInfo(current: current, longest: longest)
    }
}
```

`Heatmap.swift`:

```swift
import Foundation

public enum Heatmap {
    public static func intensity(minutes: Int) -> Int {
        switch minutes {
        case ..<1: return 0
        case 1..<30: return 1
        case 30..<60: return 2
        case 60..<120: return 3
        default: return 4
        }
    }

    public static func weeks(endingOn today: Date, weekCount: Int = 26, calendar: Calendar) -> [[Date?]] {
        let todayStart = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: todayStart)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let thisWeekStart = calendar.date(byAdding: .day, value: -offset, to: todayStart)!

        return (0..<weekCount).map { column in
            let weekStart = calendar.date(byAdding: .day, value: -7 * (weekCount - 1 - column), to: thisWeekStart)!
            return (0..<7).map { row in
                let date = calendar.startOfDay(for: calendar.date(byAdding: .day, value: row, to: weekStart)!)
                return date > todayStart ? nil : date
            }
        }
    }
}
```

`TimerMath.swift`:

```swift
import Foundation

public enum TimerMath {
    public static let maxMinutes = 720

    public static func elapsedMinutes(from start: Date, to now: Date) -> Int {
        let seconds = max(0, now.timeIntervalSince(start))
        let minutes = Int((seconds / 60).rounded(.up))
        return min(max(minutes, 1), maxMinutes)
    }
}
```

- [ ] **Step 4: テストが通ることを確認する**

Run: `docker run --rm -v "$PWD/Packages/StudyCore":/pkg -w /pkg swift:6.0-noble swift test`
Expected: `Executed 16 tests, with 0 failures`

- [ ] **Step 5: コミット**

```bash
git add Packages/StudyCore
git commit -m "feat(core): 集計・連続日数・草カレンダー・タイマー計算を追加"
```

---

### Task 3: 景品カタログとガチャ

**Files:**
- Create: `Packages/StudyCore/Sources/StudyCore/Rewards.swift`
- Create: `Packages/StudyCore/Sources/StudyCore/Gacha.swift`
- Test: `Packages/StudyCore/Tests/StudyCoreTests/GachaTests.swift`

**Interfaces:**
- Consumes: テスト用 `SeededRNG`
- Produces:
  - `enum Rarity: Int, CaseIterable, Sendable { case n, r, sr, ssr; var label: String; var duplicateXP: Int }`
  - `enum RewardKind: Sendable { case title, theme }`
  - `struct Reward: Identifiable, Equatable, Sendable { let id: String; let name: String; let rarity: Rarity; let kind: RewardKind; let colorHex: String? }`（`colorHex` は `theme` のみ非 nil）
  - `enum RewardCatalog { static let all: [Reward]; static func reward(id: String) -> Reward?; static func rewards(of: Rarity) -> [Reward] }`
  - `struct GachaResult: Equatable, Sendable { let reward: Reward; let isDuplicate: Bool; let bonusXP: Int }`
  - `enum Gacha { static let minMinutesForTicket = 15; static let dailyTicketCap = 3; static func rarity(forRoll: Int) -> Rarity`（roll は 0..<1000）`; static func result(rarityRoll: Int, itemRoll: Int, owned: Set<String>) -> GachaResult; static func draw<G: RandomNumberGenerator>(owned: Set<String>, using: inout G) -> GachaResult; static func ticketsAwarded(newSessionMinutes: Int, qualifyingSessionsAlreadyOnDay: Int) -> Int }`

- [ ] **Step 1: 失敗するテストを書く**

`GachaTests.swift`:

```swift
import XCTest
@testable import StudyCore

final class GachaTests: XCTestCase {
    func testCatalogCounts() {
        XCTAssertEqual(RewardCatalog.rewards(of: .n).count, 12)
        XCTAssertEqual(RewardCatalog.rewards(of: .r).count, 8)
        XCTAssertEqual(RewardCatalog.rewards(of: .sr).count, 4)
        XCTAssertEqual(RewardCatalog.rewards(of: .ssr).count, 2)
        XCTAssertEqual(Set(RewardCatalog.all.map(\.id)).count, 26)
    }

    func testThemesHaveColorAndTitlesDoNot() {
        for reward in RewardCatalog.all {
            XCTAssertEqual(reward.colorHex != nil, reward.kind == .theme, reward.id)
        }
    }

    func testRarityBoundaries() {
        XCTAssertEqual(Gacha.rarity(forRoll: 0), .n)
        XCTAssertEqual(Gacha.rarity(forRoll: 699), .n)
        XCTAssertEqual(Gacha.rarity(forRoll: 700), .r)
        XCTAssertEqual(Gacha.rarity(forRoll: 949), .r)
        XCTAssertEqual(Gacha.rarity(forRoll: 950), .sr)
        XCTAssertEqual(Gacha.rarity(forRoll: 994), .sr)
        XCTAssertEqual(Gacha.rarity(forRoll: 995), .ssr)
        XCTAssertEqual(Gacha.rarity(forRoll: 999), .ssr)
    }

    func testResultPicksItemWithinRarity() {
        let ssr = RewardCatalog.rewards(of: .ssr)
        let result = Gacha.result(rarityRoll: 999, itemRoll: 1, owned: [])
        XCTAssertEqual(result, GachaResult(reward: ssr[1], isDuplicate: false, bonusXP: 0))
    }

    func testDuplicateConvertsToBonusXP() {
        let first = RewardCatalog.rewards(of: .n)[0]
        let result = Gacha.result(rarityRoll: 0, itemRoll: 0, owned: [first.id])
        XCTAssertEqual(result, GachaResult(reward: first, isDuplicate: true, bonusXP: 10))
        XCTAssertEqual(Rarity.r.duplicateXP, 30)
        XCTAssertEqual(Rarity.sr.duplicateXP, 100)
        XCTAssertEqual(Rarity.ssr.duplicateXP, 500)
    }

    func testDrawDistribution() {
        var rng = SeededRNG(seed: 42)
        var counts: [Rarity: Int] = [:]
        let trials = 100_000
        for _ in 0..<trials {
            counts[Gacha.draw(owned: [], using: &rng).reward.rarity, default: 0] += 1
        }
        func rate(_ rarity: Rarity) -> Double { Double(counts[rarity] ?? 0) / Double(trials) }
        XCTAssertEqual(rate(.n), 0.70, accuracy: 0.01)
        XCTAssertEqual(rate(.r), 0.25, accuracy: 0.01)
        XCTAssertEqual(rate(.sr), 0.045, accuracy: 0.005)
        XCTAssertEqual(rate(.ssr), 0.005, accuracy: 0.002)
    }

    func testTicketsAwarded() {
        XCTAssertEqual(Gacha.ticketsAwarded(newSessionMinutes: 14, qualifyingSessionsAlreadyOnDay: 0), 0)
        XCTAssertEqual(Gacha.ticketsAwarded(newSessionMinutes: 15, qualifyingSessionsAlreadyOnDay: 0), 1)
        XCTAssertEqual(Gacha.ticketsAwarded(newSessionMinutes: 60, qualifyingSessionsAlreadyOnDay: 2), 1)
        XCTAssertEqual(Gacha.ticketsAwarded(newSessionMinutes: 60, qualifyingSessionsAlreadyOnDay: 3), 0)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `docker run --rm -v "$PWD/Packages/StudyCore":/pkg -w /pkg swift:6.0-noble swift test`
Expected: コンパイルエラー `cannot find 'RewardCatalog' in scope`

- [ ] **Step 3: 実装する**

`Rewards.swift`:

```swift
import Foundation

public enum Rarity: Int, CaseIterable, Sendable {
    case n, r, sr, ssr

    public var label: String {
        switch self {
        case .n: return "N"
        case .r: return "R"
        case .sr: return "SR"
        case .ssr: return "SSR"
        }
    }

    public var duplicateXP: Int {
        switch self {
        case .n: return 10
        case .r: return 30
        case .sr: return 100
        case .ssr: return 500
        }
    }
}

public enum RewardKind: Sendable {
    case title, theme
}

public struct Reward: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let rarity: Rarity
    public let kind: RewardKind
    public let colorHex: String?
}

public enum RewardCatalog {
    private static func title(_ id: String, _ name: String, _ rarity: Rarity) -> Reward {
        Reward(id: id, name: name, rarity: rarity, kind: .title, colorHex: nil)
    }

    private static func theme(_ id: String, _ name: String, _ rarity: Rarity, _ hex: String) -> Reward {
        Reward(id: id, name: name, rarity: rarity, kind: .theme, colorHex: hex)
    }

    public static let all: [Reward] = [
        title("title_n_beginner", "かけだし", .n),
        title("title_n_morning", "朝型", .n),
        title("title_n_night", "夜ふかし", .n),
        title("title_n_steady", "こつこつ", .n),
        title("title_n_curious", "知りたがり", .n),
        title("title_n_desk", "机の住人", .n),
        title("title_n_notes", "メモ魔", .n),
        title("title_n_coffee", "コーヒー党", .n),
        theme("theme_n_sky", "そらいろ", .n, "#5AC8FA"),
        theme("theme_n_orange", "みかん", .n, "#FF9500"),
        theme("theme_n_pink", "さくら", .n, "#FF6B9A"),
        theme("theme_n_mint", "ミント", .n, "#00C7BE"),

        title("title_r_scholar", "努力家", .r),
        title("title_r_explorer", "探究者", .r),
        title("title_r_marathon", "長距離ランナー", .r),
        title("title_r_owl", "知恵のフクロウ", .r),
        title("title_r_polyglot", "多芸多才", .r),
        theme("theme_r_indigo", "藍", .r, "#5856D6"),
        theme("theme_r_crimson", "紅", .r, "#D7263D"),
        theme("theme_r_forest", "深緑", .r, "#1B7F5C"),

        title("title_sr_sage", "賢者", .sr),
        title("title_sr_unstoppable", "止まらない人", .sr),
        theme("theme_sr_gold", "黄金", .sr, "#D4A017"),
        theme("theme_sr_violet", "紫水晶", .sr, "#9B5DE5"),

        title("title_ssr_endless", "終わりなき学徒", .ssr),
        theme("theme_ssr_aurora", "オーロラ", .ssr, "#00E5A8"),
    ]

    public static func reward(id: String) -> Reward? {
        all.first { $0.id == id }
    }

    public static func rewards(of rarity: Rarity) -> [Reward] {
        all.filter { $0.rarity == rarity }
    }
}
```

`Gacha.swift`:

```swift
import Foundation

public struct GachaResult: Equatable, Sendable {
    public let reward: Reward
    public let isDuplicate: Bool
    public let bonusXP: Int
}

public enum Gacha {
    public static let minMinutesForTicket = 15
    public static let dailyTicketCap = 3

    public static func rarity(forRoll roll: Int) -> Rarity {
        switch roll {
        case ..<700: return .n
        case ..<950: return .r
        case ..<995: return .sr
        default: return .ssr
        }
    }

    public static func result(rarityRoll: Int, itemRoll: Int, owned: Set<String>) -> GachaResult {
        let rarity = rarity(forRoll: rarityRoll)
        let pool = RewardCatalog.rewards(of: rarity)
        let reward = pool[itemRoll % pool.count]
        let isDuplicate = owned.contains(reward.id)
        return GachaResult(reward: reward, isDuplicate: isDuplicate, bonusXP: isDuplicate ? rarity.duplicateXP : 0)
    }

    public static func draw<G: RandomNumberGenerator>(owned: Set<String>, using rng: inout G) -> GachaResult {
        let rarityRoll = Int.random(in: 0..<1000, using: &rng)
        let itemRoll = Int.random(in: 0..<1000, using: &rng)
        return result(rarityRoll: rarityRoll, itemRoll: itemRoll, owned: owned)
    }

    public static func ticketsAwarded(newSessionMinutes: Int, qualifyingSessionsAlreadyOnDay: Int) -> Int {
        guard newSessionMinutes >= minMinutesForTicket else { return 0 }
        return qualifyingSessionsAlreadyOnDay < dailyTicketCap ? 1 : 0
    }
}
```

注: `itemRoll % pool.count` は 0..<1000 の一様乱数に対し、景品数 12・8・4・2 のうち 12 と 8 で最大 0.1% 程度の偏りが出る。景品内の偏りであり排出率には影響しないため許容する。

- [ ] **Step 4: テストが通ることを確認する**

Run: `docker run --rm -v "$PWD/Packages/StudyCore":/pkg -w /pkg swift:6.0-noble swift test`
Expected: `Executed 23 tests, with 0 failures`

- [ ] **Step 5: コミット**

```bash
git add Packages/StudyCore
git commit -m "feat(core): 景品カタログとガチャ抽選を追加"
```

---

### Task 4: バッジ・進捗スナップショット・保存結果の評価

**Files:**
- Create: `Packages/StudyCore/Sources/StudyCore/Badges.swift`
- Create: `Packages/StudyCore/Sources/StudyCore/Progress.swift`
- Test: `Packages/StudyCore/Tests/StudyCoreTests/BadgesTests.swift`
- Test: `Packages/StudyCore/Tests/StudyCoreTests/ProgressTests.swift`

**Interfaces:**
- Consumes: `SessionRecord`、`Stats`、`Streak`/`StreakInfo`、`Leveling`/`LevelProgress`、`Gacha.ticketsAwarded`、`Gacha.minMinutesForTicket`
- Produces:
  - `struct BadgeStats: Equatable, Sendable { var totalMinutes, longestStreak, sessionCount, distinctTagCount, maxDailyMinutes, level: Int }`（memberwise の public init あり）
  - `enum BadgeCategory: Sendable { case totalMinutes, longestStreak, sessionCount, tagCount, dailyMinutes, level }`
  - `struct Badge: Identifiable, Equatable, Sendable { let id: String; let name: String; let category: BadgeCategory; let threshold: Int; var conditionText: String; func isUnlocked(by: BadgeStats) -> Bool }`
  - `enum Badges { static let all: [Badge]; static func unlockedIDs(for: BadgeStats) -> Set<String> }`
  - `struct ProgressSnapshot: Equatable, Sendable { let totalMinutes: Int; let totalXP: Int; let level: LevelProgress; let streak: StreakInfo; let todayMinutes: Int; let dailyTotals: [Date: Int]; let unlockedBadgeIDs: Set<String> }`
  - `enum Progress { static func snapshot(sessions: [SessionRecord], bonusXP: Int, today: Date, calendar: Calendar) -> ProgressSnapshot }`
  - `struct RecordOutcome: Equatable, Sendable { let xpGained: Int; let levelBefore: Int; let levelAfter: Int; let newBadgeIDs: [String]; let ticketsAwarded: Int; var leveledUp: Bool }`（`newBadgeIDs` は `Badges.all` の定義順）
  - `enum RecordEvaluator { static func outcome(existing: [SessionRecord], new: SessionRecord, bonusXP: Int, today: Date, calendar: Calendar) -> RecordOutcome }`

- [ ] **Step 1: 失敗するテストを書く**

`BadgesTests.swift`:

```swift
import XCTest
@testable import StudyCore

final class BadgesTests: XCTestCase {
    private func stats(total: Int = 0, streak: Int = 0, count: Int = 0,
                       tags: Int = 0, daily: Int = 0, level: Int = 1) -> BadgeStats {
        BadgeStats(totalMinutes: total, longestStreak: streak, sessionCount: count,
                   distinctTagCount: tags, maxDailyMinutes: daily, level: level)
    }

    func testCatalogHas23UniqueBadges() {
        XCTAssertEqual(Badges.all.count, 23)
        XCTAssertEqual(Set(Badges.all.map(\.id)).count, 23)
    }

    func testNothingUnlockedAtZero() {
        XCTAssertEqual(Badges.unlockedIDs(for: stats()), [])
    }

    func testTotalTimeBoundary() {
        XCTAssertFalse(Badges.unlockedIDs(for: stats(total: 59)).contains("time_1h"))
        XCTAssertTrue(Badges.unlockedIDs(for: stats(total: 60)).contains("time_1h"))
        XCTAssertEqual(Badges.unlockedIDs(for: stats(total: 60_000)),
                       ["time_1h", "time_10h", "time_50h", "time_100h", "time_500h", "time_1000h"])
    }

    func testEachCategoryBoundary() {
        XCTAssertEqual(Badges.unlockedIDs(for: stats(streak: 7)), ["streak_3", "streak_7"])
        XCTAssertEqual(Badges.unlockedIDs(for: stats(count: 10)), ["count_1", "count_10"])
        XCTAssertEqual(Badges.unlockedIDs(for: stats(tags: 3)), ["tags_3"])
        XCTAssertEqual(Badges.unlockedIDs(for: stats(daily: 180)), ["daily_3h"])
        XCTAssertEqual(Badges.unlockedIDs(for: stats(level: 5)), ["level_5"])
        XCTAssertEqual(Badges.unlockedIDs(for: stats(level: 4)), [])
    }

    func testConditionText() {
        XCTAssertEqual(Badges.all.first { $0.id == "time_10h" }?.conditionText, "累計 10 時間")
        XCTAssertEqual(Badges.all.first { $0.id == "streak_30" }?.conditionText, "30 日連続")
        XCTAssertEqual(Badges.all.first { $0.id == "count_100" }?.conditionText, "記録 100 回")
        XCTAssertEqual(Badges.all.first { $0.id == "tags_3" }?.conditionText, "タグ 3 種類")
        XCTAssertEqual(Badges.all.first { $0.id == "daily_3h" }?.conditionText, "1 日 3 時間")
        XCTAssertEqual(Badges.all.first { $0.id == "level_10" }?.conditionText, "レベル 10")
    }
}
```

`ProgressTests.swift`:

```swift
import XCTest
@testable import StudyCore

final class ProgressTests: XCTestCase {
    private let today = day(2026, 11, 12)

    func testSnapshotCombinesEverything() {
        let sessions = [
            SessionRecord(startedAt: day(2026, 11, 11), minutes: 60),
            SessionRecord(startedAt: day(2026, 11, 12, hour: 8), minutes: 30),
            SessionRecord(startedAt: day(2026, 11, 12, hour: 20), minutes: 10),
        ]
        let snapshot = Progress.snapshot(sessions: sessions, bonusXP: 50, today: today, calendar: utc)
        XCTAssertEqual(snapshot.totalMinutes, 100)
        XCTAssertEqual(snapshot.totalXP, 150)
        XCTAssertEqual(snapshot.level, LevelProgress(level: 2, xpIntoLevel: 50, xpForNextLevel: 200))
        XCTAssertEqual(snapshot.streak, StreakInfo(current: 2, longest: 2))
        XCTAssertEqual(snapshot.todayMinutes, 40)
        XCTAssertEqual(snapshot.unlockedBadgeIDs, ["time_1h", "count_1"])
    }

    func testEmptySnapshot() {
        let snapshot = Progress.snapshot(sessions: [], bonusXP: 0, today: today, calendar: utc)
        XCTAssertEqual(snapshot.totalXP, 0)
        XCTAssertEqual(snapshot.level.level, 1)
        XCTAssertEqual(snapshot.streak, StreakInfo(current: 0, longest: 0))
        XCTAssertEqual(snapshot.todayMinutes, 0)
    }

    func testFirstRecordOutcome() {
        let new = SessionRecord(startedAt: today, minutes: 60)
        let outcome = RecordEvaluator.outcome(existing: [], new: new, bonusXP: 0, today: today, calendar: utc)
        XCTAssertEqual(outcome, RecordOutcome(xpGained: 60, levelBefore: 1, levelAfter: 1,
                                              newBadgeIDs: ["time_1h", "count_1"], ticketsAwarded: 1))
        XCTAssertFalse(outcome.leveledUp)
    }

    func testLevelUpOutcome() {
        let existing = [SessionRecord(startedAt: day(2026, 11, 11), minutes: 90)]
        let new = SessionRecord(startedAt: today, minutes: 20)
        let outcome = RecordEvaluator.outcome(existing: existing, new: new, bonusXP: 0, today: today, calendar: utc)
        XCTAssertEqual(outcome.levelBefore, 1)
        XCTAssertEqual(outcome.levelAfter, 2)
        XCTAssertTrue(outcome.leveledUp)
        XCTAssertEqual(outcome.newBadgeIDs, [])
    }

    func testTicketCapCountsOnlyQualifyingSessionsOnSameDay() {
        let existing = [
            SessionRecord(startedAt: day(2026, 11, 12, hour: 6), minutes: 15),
            SessionRecord(startedAt: day(2026, 11, 12, hour: 7), minutes: 15),
            SessionRecord(startedAt: day(2026, 11, 12, hour: 8), minutes: 5),
            SessionRecord(startedAt: day(2026, 11, 11), minutes: 60),
        ]
        let third = SessionRecord(startedAt: day(2026, 11, 12, hour: 9), minutes: 15)
        XCTAssertEqual(RecordEvaluator.outcome(existing: existing, new: third, bonusXP: 0,
                                               today: today, calendar: utc).ticketsAwarded, 1)
        let fourth = SessionRecord(startedAt: day(2026, 11, 12, hour: 10), minutes: 15)
        XCTAssertEqual(RecordEvaluator.outcome(existing: existing + [third], new: fourth, bonusXP: 0,
                                               today: today, calendar: utc).ticketsAwarded, 0)
    }

    func testShortSessionGivesNoTicket() {
        let new = SessionRecord(startedAt: today, minutes: 14)
        XCTAssertEqual(RecordEvaluator.outcome(existing: [], new: new, bonusXP: 0,
                                               today: today, calendar: utc).ticketsAwarded, 0)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `docker run --rm -v "$PWD/Packages/StudyCore":/pkg -w /pkg swift:6.0-noble swift test`
Expected: コンパイルエラー `cannot find 'Badges' in scope`

- [ ] **Step 3: 実装する**

`Badges.swift`:

```swift
import Foundation

public struct BadgeStats: Equatable, Sendable {
    public var totalMinutes: Int
    public var longestStreak: Int
    public var sessionCount: Int
    public var distinctTagCount: Int
    public var maxDailyMinutes: Int
    public var level: Int

    public init(totalMinutes: Int, longestStreak: Int, sessionCount: Int,
                distinctTagCount: Int, maxDailyMinutes: Int, level: Int) {
        self.totalMinutes = totalMinutes
        self.longestStreak = longestStreak
        self.sessionCount = sessionCount
        self.distinctTagCount = distinctTagCount
        self.maxDailyMinutes = maxDailyMinutes
        self.level = level
    }
}

public enum BadgeCategory: Sendable {
    case totalMinutes, longestStreak, sessionCount, tagCount, dailyMinutes, level
}

public struct Badge: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let category: BadgeCategory
    public let threshold: Int

    public var conditionText: String {
        switch category {
        case .totalMinutes: return "累計 \(threshold / 60) 時間"
        case .longestStreak: return "\(threshold) 日連続"
        case .sessionCount: return "記録 \(threshold) 回"
        case .tagCount: return "タグ \(threshold) 種類"
        case .dailyMinutes: return "1 日 \(threshold / 60) 時間"
        case .level: return "レベル \(threshold)"
        }
    }

    public func isUnlocked(by stats: BadgeStats) -> Bool {
        let value: Int
        switch category {
        case .totalMinutes: value = stats.totalMinutes
        case .longestStreak: value = stats.longestStreak
        case .sessionCount: value = stats.sessionCount
        case .tagCount: value = stats.distinctTagCount
        case .dailyMinutes: value = stats.maxDailyMinutes
        case .level: value = stats.level
        }
        return value >= threshold
    }
}

public enum Badges {
    public static let all: [Badge] = [
        Badge(id: "time_1h", name: "はじめの一時間", category: .totalMinutes, threshold: 60),
        Badge(id: "time_10h", name: "十時間の壁", category: .totalMinutes, threshold: 600),
        Badge(id: "time_50h", name: "五十時間", category: .totalMinutes, threshold: 3_000),
        Badge(id: "time_100h", name: "百時間", category: .totalMinutes, threshold: 6_000),
        Badge(id: "time_500h", name: "五百時間", category: .totalMinutes, threshold: 30_000),
        Badge(id: "time_1000h", name: "千時間の達人", category: .totalMinutes, threshold: 60_000),

        Badge(id: "streak_3", name: "三日坊主卒業", category: .longestStreak, threshold: 3),
        Badge(id: "streak_7", name: "一週間", category: .longestStreak, threshold: 7),
        Badge(id: "streak_30", name: "一か月", category: .longestStreak, threshold: 30),
        Badge(id: "streak_100", name: "百日", category: .longestStreak, threshold: 100),
        Badge(id: "streak_365", name: "一年", category: .longestStreak, threshold: 365),

        Badge(id: "count_1", name: "最初の一歩", category: .sessionCount, threshold: 1),
        Badge(id: "count_10", name: "十回目", category: .sessionCount, threshold: 10),
        Badge(id: "count_100", name: "百回目", category: .sessionCount, threshold: 100),
        Badge(id: "count_1000", name: "千回目", category: .sessionCount, threshold: 1_000),

        Badge(id: "tags_3", name: "三刀流", category: .tagCount, threshold: 3),
        Badge(id: "tags_10", name: "博学", category: .tagCount, threshold: 10),

        Badge(id: "daily_3h", name: "集中の日", category: .dailyMinutes, threshold: 180),
        Badge(id: "daily_6h", name: "没頭の日", category: .dailyMinutes, threshold: 360),

        Badge(id: "level_5", name: "レベル 5", category: .level, threshold: 5),
        Badge(id: "level_10", name: "レベル 10", category: .level, threshold: 10),
        Badge(id: "level_25", name: "レベル 25", category: .level, threshold: 25),
        Badge(id: "level_50", name: "レベル 50", category: .level, threshold: 50),
    ]

    public static func unlockedIDs(for stats: BadgeStats) -> Set<String> {
        Set(all.filter { $0.isUnlocked(by: stats) }.map(\.id))
    }
}
```

`Progress.swift`:

```swift
import Foundation

public struct ProgressSnapshot: Equatable, Sendable {
    public let totalMinutes: Int
    public let totalXP: Int
    public let level: LevelProgress
    public let streak: StreakInfo
    public let todayMinutes: Int
    public let dailyTotals: [Date: Int]
    public let unlockedBadgeIDs: Set<String>
}

public enum Progress {
    public static func snapshot(sessions: [SessionRecord], bonusXP: Int,
                                today: Date, calendar: Calendar) -> ProgressSnapshot {
        let daily = Stats.dailyTotals(sessions, calendar: calendar)
        let total = Stats.totalMinutes(sessions)
        let xp = total + bonusXP
        let level = Leveling.progress(forXP: xp)
        let studyDays = Set(daily.filter { $0.value >= 1 }.keys)
        let streak = Streak.compute(studyDays: studyDays, today: today, calendar: calendar)
        let stats = BadgeStats(
            totalMinutes: total,
            longestStreak: streak.longest,
            sessionCount: sessions.count,
            distinctTagCount: Stats.distinctTagCount(sessions),
            maxDailyMinutes: daily.values.max() ?? 0,
            level: level.level
        )
        return ProgressSnapshot(
            totalMinutes: total,
            totalXP: xp,
            level: level,
            streak: streak,
            todayMinutes: daily[calendar.startOfDay(for: today)] ?? 0,
            dailyTotals: daily,
            unlockedBadgeIDs: Badges.unlockedIDs(for: stats)
        )
    }
}

public struct RecordOutcome: Equatable, Sendable {
    public let xpGained: Int
    public let levelBefore: Int
    public let levelAfter: Int
    public let newBadgeIDs: [String]
    public let ticketsAwarded: Int

    public init(xpGained: Int, levelBefore: Int, levelAfter: Int, newBadgeIDs: [String], ticketsAwarded: Int) {
        self.xpGained = xpGained
        self.levelBefore = levelBefore
        self.levelAfter = levelAfter
        self.newBadgeIDs = newBadgeIDs
        self.ticketsAwarded = ticketsAwarded
    }

    public var leveledUp: Bool { levelAfter > levelBefore }
}

public enum RecordEvaluator {
    public static func outcome(existing: [SessionRecord], new: SessionRecord, bonusXP: Int,
                               today: Date, calendar: Calendar) -> RecordOutcome {
        let before = Progress.snapshot(sessions: existing, bonusXP: bonusXP, today: today, calendar: calendar)
        let after = Progress.snapshot(sessions: existing + [new], bonusXP: bonusXP, today: today, calendar: calendar)

        let newDay = calendar.startOfDay(for: new.startedAt)
        let qualifying = existing.filter {
            $0.minutes >= Gacha.minMinutesForTicket && calendar.startOfDay(for: $0.startedAt) == newDay
        }.count

        let gained = after.unlockedBadgeIDs.subtracting(before.unlockedBadgeIDs)
        return RecordOutcome(
            xpGained: new.minutes,
            levelBefore: before.level.level,
            levelAfter: after.level.level,
            newBadgeIDs: Badges.all.map(\.id).filter(gained.contains),
            ticketsAwarded: Gacha.ticketsAwarded(newSessionMinutes: new.minutes,
                                                 qualifyingSessionsAlreadyOnDay: qualifying)
        )
    }
}
```

- [ ] **Step 4: テストが通ることを確認する**

Run: `docker run --rm -v "$PWD/Packages/StudyCore":/pkg -w /pkg swift:6.0-noble swift test`
Expected: `Executed 34 tests, with 0 failures`

- [ ] **Step 5: コミット**

```bash
git add Packages/StudyCore
git commit -m "feat(core): バッジ・進捗スナップショット・保存結果の評価を追加"
```

---

### Task 5: アプリの土台（XcodeGen・モデル・サービス・タブ）

**Files:**
- Create: `project.yml`
- Create: `EndlessStudy/Models/Models.swift`
- Create: `EndlessStudy/Services/RecordService.swift`
- Create: `EndlessStudy/Services/TimerStore.swift`
- Create: `EndlessStudy/Support/Formatters.swift`
- Create: `EndlessStudy/App/EndlessStudyApp.swift`
- Create: `EndlessStudy/App/RootView.swift`
- Create（仮置き。Task 6・8・9 で置き換える）: `EndlessStudy/Features/Home/HomeView.swift`、`EndlessStudy/Features/History/HistoryView.swift`、`EndlessStudy/Features/Collection/CollectionView.swift`

**Interfaces:**
- Consumes: `StudyCore` の `SessionRecord`、`RecordEvaluator`、`RecordOutcome`、`Gacha`、`GachaResult`、`RewardCatalog`
- Produces:
  - `enum SessionSource: String { case timer, manual }`
  - `@Model final class StudySession { var id: UUID; var startedAt: Date; var minutes: Int; var memo: String; var sourceRaw: String; var tag: Tag?; init(startedAt:minutes:memo:source:tag:); var record: SessionRecord }`
  - `@Model final class Tag { var id: UUID; var name: String; var colorHex: String; var createdAt: Date; var sessions: [StudySession]; init(name:colorHex:) }`
  - `@Model final class OwnedReward { var rewardID: String; var obtainedAt: Date; init(rewardID:) }`
  - `@Model final class PlayerState { var gachaTickets: Int; var bonusXP: Int; var equippedTitleID: String?; var equippedThemeID: String?; init() }`
  - `@MainActor struct RecordService { init(context: ModelContext); func playerState() throws -> PlayerState; func save(startedAt: Date, minutes: Int, tag: Tag?, memo: String, source: SessionSource) throws -> RecordOutcome; func drawGacha() throws -> GachaResult? }`（券 0 枚なら `nil`）
  - `@Observable final class TimerStore { var startedAt: Date? { get }; var isRunning: Bool; func start(); func clear() }`
  - `func formatMinutes(_ minutes: Int) -> String`（例: 80 → "1時間20分"、45 → "45分"、120 → "2時間"）
  - `extension Color { init(hex: String) }`
  - `enum TagPalette { static let colors: [String] }`
  - `enum AppTheme { static let defaultHex = "#34C759"; static func color(themeID: String?) -> Color }`
  - `enum AppTab { case home, history, collection }`、`@Observable final class AppRouter { var tab: AppTab }`
  - `struct RootView: View`

- [ ] **Step 1: project.yml を作る**

```yaml
name: EndlessStudy
options:
  bundleIdPrefix: com.example
  deploymentTarget:
    iOS: "17.0"
packages:
  StudyCore:
    path: Packages/StudyCore
targets:
  EndlessStudy:
    type: application
    platform: iOS
    sources:
      - EndlessStudy
    dependencies:
      - package: StudyCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.endlessstudy
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: Endless Study
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        SWIFT_VERSION: "5.0"
        TARGETED_DEVICE_FAMILY: "1"
```

- [ ] **Step 2: モデルを作る**

`EndlessStudy/Models/Models.swift`:

```swift
import Foundation
import SwiftData
import StudyCore

enum SessionSource: String {
    case timer, manual
}

@Model
final class StudySession {
    var id: UUID
    var startedAt: Date
    var minutes: Int
    var memo: String
    var sourceRaw: String
    var tag: Tag?

    init(startedAt: Date, minutes: Int, memo: String, source: SessionSource, tag: Tag?) {
        self.id = UUID()
        self.startedAt = startedAt
        self.minutes = minutes
        self.memo = memo
        self.sourceRaw = source.rawValue
        self.tag = tag
    }

    var record: SessionRecord {
        SessionRecord(startedAt: startedAt, minutes: minutes, tagID: tag?.id)
    }
}

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \StudySession.tag)
    var sessions: [StudySession] = []

    init(name: String, colorHex: String) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = .now
    }
}

@Model
final class OwnedReward {
    var rewardID: String
    var obtainedAt: Date

    init(rewardID: String) {
        self.rewardID = rewardID
        self.obtainedAt = .now
    }
}

@Model
final class PlayerState {
    var gachaTickets: Int
    var bonusXP: Int
    var equippedTitleID: String?
    var equippedThemeID: String?

    init() {
        self.gachaTickets = 0
        self.bonusXP = 0
    }
}
```

- [ ] **Step 3: サービスを作る**

`EndlessStudy/Services/RecordService.swift`:

```swift
import Foundation
import SwiftData
import StudyCore

@MainActor
struct RecordService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func playerState() throws -> PlayerState {
        if let state = try context.fetch(FetchDescriptor<PlayerState>()).first {
            return state
        }
        let state = PlayerState()
        context.insert(state)
        return state
    }

    func save(startedAt: Date, minutes: Int, tag: Tag?, memo: String,
              source: SessionSource) throws -> RecordOutcome {
        let existing = try context.fetch(FetchDescriptor<StudySession>()).map(\.record)
        let state = try playerState()
        let session = StudySession(startedAt: startedAt, minutes: minutes, memo: memo, source: source, tag: tag)
        let outcome = RecordEvaluator.outcome(existing: existing, new: session.record,
                                              bonusXP: state.bonusXP, today: .now, calendar: .current)
        context.insert(session)
        state.gachaTickets += outcome.ticketsAwarded
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return outcome
    }

    func drawGacha() throws -> GachaResult? {
        let state = try playerState()
        guard state.gachaTickets > 0 else { return nil }
        let owned = Set(try context.fetch(FetchDescriptor<OwnedReward>()).map(\.rewardID))
        var rng = SystemRandomNumberGenerator()
        let result = Gacha.draw(owned: owned, using: &rng)
        state.gachaTickets -= 1
        if result.isDuplicate {
            state.bonusXP += result.bonusXP
        } else {
            context.insert(OwnedReward(rewardID: result.reward.id))
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return result
    }
}
```

`EndlessStudy/Services/TimerStore.swift`:

```swift
import Foundation
import Observation

@Observable
final class TimerStore {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "timer.startedAt"

    private(set) var startedAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: key)
        self.startedAt = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    var isRunning: Bool { startedAt != nil }

    func start() {
        let now = Date.now
        startedAt = now
        defaults.set(now.timeIntervalSince1970, forKey: key)
    }

    func clear() {
        startedAt = nil
        defaults.removeObject(forKey: key)
    }
}
```

- [ ] **Step 4: 共通ユーティリティを作る**

`EndlessStudy/Support/Formatters.swift`:

```swift
import SwiftUI
import StudyCore

func formatMinutes(_ minutes: Int) -> String {
    let hours = minutes / 60
    let rest = minutes % 60
    if hours == 0 { return "\(rest)分" }
    if rest == 0 { return "\(hours)時間" }
    return "\(hours)時間\(rest)分"
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum TagPalette {
    static let colors = ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#007AFF", "#5856D6", "#AF52DE"]
}

enum AppTheme {
    static let defaultHex = "#34C759"

    static func color(themeID: String?) -> Color {
        let hex = themeID.flatMap { RewardCatalog.reward(id: $0)?.colorHex } ?? defaultHex
        return Color(hex: hex)
    }
}
```

- [ ] **Step 5: アプリのエントリポイントとタブを作る**

`EndlessStudy/App/EndlessStudyApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct EndlessStudyApp: App {
    @State private var timer = TimerStore()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(timer)
                .environment(router)
        }
        .modelContainer(for: [StudySession.self, Tag.self, OwnedReward.self, PlayerState.self])
    }
}
```

`EndlessStudy/App/RootView.swift`:

```swift
import SwiftUI
import SwiftData
import Observation

enum AppTab: Hashable {
    case home, history, collection
}

@Observable
final class AppRouter {
    var tab: AppTab = .home
}

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Query private var states: [PlayerState]

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(AppTab.home)
            HistoryView()
                .tabItem { Label("記録", systemImage: "calendar") }
                .tag(AppTab.history)
            CollectionView()
                .tabItem { Label("コレクション", systemImage: "sparkles") }
                .tag(AppTab.collection)
        }
        .tint(AppTheme.color(themeID: states.first?.equippedThemeID))
    }
}
```

仮置きの 3 画面（それぞれのファイルに 1 つずつ。後続タスクで全文を置き換える）:

`EndlessStudy/Features/Home/HomeView.swift`:

```swift
import SwiftUI

struct HomeView: View {
    var body: some View { Text("ホーム") }
}
```

`EndlessStudy/Features/History/HistoryView.swift`:

```swift
import SwiftUI

struct HistoryView: View {
    var body: some View { Text("記録") }
}
```

`EndlessStudy/Features/Collection/CollectionView.swift`:

```swift
import SwiftUI

struct CollectionView: View {
    var body: some View { Text("コレクション") }
}
```

- [ ] **Step 6: 構文チェック**

Run: `docker run --rm -v "$PWD":/src -w /src swift:6.0-noble sh -c 'find EndlessStudy -name "*.swift" -print0 | xargs -0 swiftc -frontend -parse'`
Expected: 出力なし・終了コード 0

- [ ] **Step 7: コミット**

```bash
git add project.yml EndlessStudy
git commit -m "feat(app): XcodeGen 定義・SwiftData モデル・保存サービス・タブ構成を追加"
```

---

### Task 6: 記録フォームと結果画面

**Files:**
- Create: `EndlessStudy/Features/Record/SessionFormView.swift`
- Create: `EndlessStudy/Features/Record/ResultView.swift`

**Interfaces:**
- Consumes: `RecordService.save(...)`、`StudySession`、`Tag`、`TagPalette`、`formatMinutes`、`AppRouter`、`StudyCore.RecordOutcome`、`StudyCore.Badges`、`StudyCore.TimerMath.maxMinutes`
- Produces:
  - `enum SessionFormMode { case timer(startedAt: Date, minutes: Int); case manual; case edit(StudySession) }`
  - `struct SessionFormView: View { init(mode: SessionFormMode, onSaved: @escaping (RecordOutcome?) -> Void = { _ in }, onDiscard: @escaping () -> Void = {}) }`（`edit` では `onSaved(nil)`。保存・破棄後に自分で `dismiss` する）
  - `struct ResultView: View { init(outcome: RecordOutcome) }`

- [ ] **Step 1: SessionFormView を作る**

`EndlessStudy/Features/Record/SessionFormView.swift`:

```swift
import SwiftUI
import SwiftData
import StudyCore

enum SessionFormMode {
    case timer(startedAt: Date, minutes: Int)
    case manual
    case edit(StudySession)
}

struct SessionFormView: View {
    let mode: SessionFormMode
    let onSaved: (RecordOutcome?) -> Void
    let onDiscard: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.createdAt) private var tags: [Tag]

    @State private var date: Date
    @State private var minutes: Int
    @State private var memo: String
    @State private var selectedTag: Tag?
    @State private var newTagName = ""
    @State private var newTagColor = TagPalette.colors[0]
    @State private var errorMessage: String?

    init(mode: SessionFormMode,
         onSaved: @escaping (RecordOutcome?) -> Void = { _ in },
         onDiscard: @escaping () -> Void = {}) {
        self.mode = mode
        self.onSaved = onSaved
        self.onDiscard = onDiscard
        switch mode {
        case .timer(let startedAt, let minutes):
            _date = State(initialValue: startedAt)
            _minutes = State(initialValue: minutes)
            _memo = State(initialValue: "")
            _selectedTag = State(initialValue: nil)
        case .manual:
            _date = State(initialValue: .now)
            _minutes = State(initialValue: 30)
            _memo = State(initialValue: "")
            _selectedTag = State(initialValue: nil)
        case .edit(let session):
            _date = State(initialValue: session.startedAt)
            _minutes = State(initialValue: session.minutes)
            _memo = State(initialValue: session.memo)
            _selectedTag = State(initialValue: session.tag)
        }
    }

    private var isTimer: Bool {
        if case .timer = mode { return true }
        return false
    }

    private var title: String {
        switch mode {
        case .timer: return "おつかれさま"
        case .manual: return "手入力"
        case .edit: return "記録を編集"
        }
    }

    private var isValid: Bool {
        (1...TimerMath.maxMinutes).contains(minutes)
    }

    private var sortedTags: [Tag] {
        tags.sorted { lastUsed($0) > lastUsed($1) }
    }

    private func lastUsed(_ tag: Tag) -> Date {
        tag.sessions.map(\.startedAt).max() ?? tag.createdAt
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("時間") {
                    if !isTimer {
                        DatePicker("日付", selection: $date, in: ...Date.now, displayedComponents: .date)
                    }
                    HStack {
                        TextField("分", value: $minutes, format: .number)
                            .keyboardType(.numberPad)
                        Text("分")
                        Stepper("分数", value: $minutes, in: 1...TimerMath.maxMinutes, step: 5)
                            .labelsHidden()
                    }
                    if !isValid {
                        Text("1〜\(TimerMath.maxMinutes) 分で入力してください")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("タグ（任意）") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(sortedTags) { tag in
                                tagChip(tag)
                            }
                        }
                    }
                    HStack {
                        TextField("新しいタグ", text: $newTagName)
                        Button("追加", action: addTag)
                            .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    HStack {
                        ForEach(TagPalette.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if hex == newTagColor {
                                        Circle().stroke(Color.primary, lineWidth: 2)
                                    }
                                }
                                .onTapGesture { newTagColor = hex }
                        }
                    }
                }

                Section("メモ（任意）") {
                    TextField("やったこと", text: $memo, axis: .vertical)
                        .lineLimit(1...4)
                }

                if isTimer {
                    Section {
                        Button("この計測を破棄", role: .destructive) {
                            onDiscard()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isTimer ? "計測に戻る" : "キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(!isValid)
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        let isSelected = selectedTag?.id == tag.id
        return Text(tag.name)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: tag.colorHex).opacity(isSelected ? 1 : 0.2), in: Capsule())
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .onTapGesture { selectedTag = isSelected ? nil : tag }
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        if let existing = tags.first(where: { $0.name == name }) {
            selectedTag = existing
        } else {
            let tag = Tag(name: name, colorHex: newTagColor)
            context.insert(tag)
            selectedTag = tag
        }
        newTagName = ""
    }

    private func save() {
        do {
            let service = RecordService(context: context)
            switch mode {
            case .timer(let startedAt, _):
                onSaved(try service.save(startedAt: startedAt, minutes: minutes, tag: selectedTag,
                                         memo: memo, source: .timer))
            case .manual:
                onSaved(try service.save(startedAt: date, minutes: minutes, tag: selectedTag,
                                         memo: memo, source: .manual))
            case .edit(let session):
                session.startedAt = date
                session.minutes = minutes
                session.memo = memo
                session.tag = selectedTag
                try context.save()
                onSaved(nil)
            }
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました。もう一度お試しください。"
        }
    }
}
```

- [ ] **Step 2: ResultView を作る**

`EndlessStudy/Features/Record/ResultView.swift`:

```swift
import SwiftUI
import StudyCore

struct ResultView: View {
    let outcome: RecordOutcome

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @State private var appeared = false

    private var newBadges: [Badge] {
        Badges.all.filter { outcome.newBadgeIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("+\(outcome.xpGained) XP")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(.tint)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)

            if outcome.leveledUp {
                VStack(spacing: 4) {
                    Text("レベルアップ！")
                        .font(.title2.bold())
                    Text("Lv \(outcome.levelBefore) → Lv \(outcome.levelAfter)")
                        .font(.title3)
                }
            }

            ForEach(newBadges) { badge in
                Label("バッジ獲得: \(badge.name)", systemImage: "rosette")
                    .font(.headline)
            }

            if outcome.ticketsAwarded > 0 {
                Label("ガチャ券 +\(outcome.ticketsAwarded)", systemImage: "ticket.fill")
                    .font(.headline)
            }

            Spacer()

            if outcome.ticketsAwarded > 0 {
                Button("ガチャを引きに行く") {
                    router.tab = .collection
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Button("閉じる") { dismiss() }
                .controlSize(.large)
        }
        .padding(32)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { appeared = true }
        }
        .sensoryFeedback(.success, trigger: appeared)
    }
}
```

- [ ] **Step 3: 構文チェック**

Run: `docker run --rm -v "$PWD":/src -w /src swift:6.0-noble sh -c 'find EndlessStudy -name "*.swift" -print0 | xargs -0 swiftc -frontend -parse'`
Expected: 出力なし・終了コード 0

- [ ] **Step 4: コミット**

```bash
git add EndlessStudy/Features/Record
git commit -m "feat(app): 記録フォームと保存直後の結果画面を追加"
```

---

### Task 7: ホーム画面とタイマー

**Files:**
- Modify（全文置き換え）: `EndlessStudy/Features/Home/HomeView.swift`

**Interfaces:**
- Consumes: `TimerStore`、`SessionFormView`/`SessionFormMode`、`ResultView`、`StudySession.record`、`PlayerState`、`formatMinutes`、`StudyCore.Progress.snapshot`、`StudyCore.TimerMath.elapsedMinutes`、`StudyCore.RewardCatalog.reward(id:)`、`StudyCore.RecordOutcome`
- Produces: `struct HomeView: View`

- [ ] **Step 1: HomeView を実装する**

`EndlessStudy/Features/Home/HomeView.swift` の全文:

```swift
import SwiftUI
import SwiftData
import StudyCore

private struct FormRequest: Identifiable {
    let id = UUID()
    let mode: SessionFormMode
}

private struct OutcomeBox: Identifiable {
    let id = UUID()
    let outcome: RecordOutcome
}

struct HomeView: View {
    @Environment(TimerStore.self) private var timer
    @Query private var sessions: [StudySession]
    @Query private var states: [PlayerState]

    @State private var formRequest: FormRequest?
    @State private var pendingOutcome: RecordOutcome?
    @State private var shownOutcome: OutcomeBox?

    private var snapshot: ProgressSnapshot {
        Progress.snapshot(sessions: sessions.map(\.record), bonusXP: states.first?.bonusXP ?? 0,
                          today: .now, calendar: .current)
    }

    private var equippedTitle: String? {
        states.first?.equippedTitleID.flatMap { RewardCatalog.reward(id: $0)?.name }
    }

    var body: some View {
        let snapshot = snapshot
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    streakCard(snapshot)
                    levelCard(snapshot)
                    todayCard(snapshot)
                    timerSection
                    Button {
                        formRequest = FormRequest(mode: .manual)
                    } label: {
                        Label("手入力で記録", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
            }
            .navigationTitle("Endless Study")
        }
        .sheet(item: $formRequest, onDismiss: showPendingOutcome) { request in
            SessionFormView(
                mode: request.mode,
                onSaved: { outcome in
                    if case .timer = request.mode { timer.clear() }
                    pendingOutcome = outcome
                },
                onDiscard: { timer.clear() }
            )
        }
        .sheet(item: $shownOutcome) { box in
            ResultView(outcome: box.outcome)
        }
    }

    private func showPendingOutcome() {
        if let outcome = pendingOutcome {
            pendingOutcome = nil
            shownOutcome = OutcomeBox(outcome: outcome)
        }
    }

    private func streakCard(_ snapshot: ProgressSnapshot) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.largeTitle)
                .foregroundStyle(snapshot.streak.current > 0 ? Color.orange : Color.secondary)
            Text("\(snapshot.streak.current) 日連続")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
            Text("最長 \(snapshot.streak.longest) 日")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func levelCard(_ snapshot: ProgressSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lv \(snapshot.level.level)")
                    .font(.title2.bold())
                if let equippedTitle {
                    Text(equippedTitle)
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.2), in: Capsule())
                }
                Spacer()
                Text("\(snapshot.level.xpIntoLevel) / \(snapshot.level.xpForNextLevel) XP")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: snapshot.level.fraction)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func todayCard(_ snapshot: ProgressSnapshot) -> some View {
        HStack {
            Text("今日")
            Spacer()
            Text(formatMinutes(snapshot.todayMinutes))
                .font(.title3.bold())
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var timerSection: some View {
        if let startedAt = timer.startedAt {
            VStack(spacing: 12) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsedText(from: startedAt, to: context.date))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                }
                Button {
                    let minutes = TimerMath.elapsedMinutes(from: startedAt, to: .now)
                    formRequest = FormRequest(mode: .timer(startedAt: startedAt, minutes: minutes))
                } label: {
                    Label("停止して記録", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
            }
        } else {
            Button {
                timer.start()
            } label: {
                Label("タイマー開始", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func elapsedText(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }
}
```

- [ ] **Step 2: 構文チェック**

Run: `docker run --rm -v "$PWD":/src -w /src swift:6.0-noble sh -c 'find EndlessStudy -name "*.swift" -print0 | xargs -0 swiftc -frontend -parse'`
Expected: 出力なし・終了コード 0

- [ ] **Step 3: コミット**

```bash
git add EndlessStudy/Features/Home
git commit -m "feat(app): ホーム画面とタイマーを追加"
```

---

### Task 8: 記録タブ（草カレンダー・タグ別累計・履歴）

**Files:**
- Create: `EndlessStudy/Features/History/HeatmapView.swift`
- Modify（全文置き換え）: `EndlessStudy/Features/History/HistoryView.swift`

**Interfaces:**
- Consumes: `StudySession`、`Tag`、`SessionFormView(mode: .edit(...))`、`formatMinutes`、`Color(hex:)`、`StudyCore.Heatmap`、`StudyCore.Stats.dailyTotals`、`StudyCore.Stats.tagTotals`
- Produces: `struct HeatmapView: View { init(dailyTotals: [Date: Int]) }`、`struct HistoryView: View`

- [ ] **Step 1: HeatmapView を作る**

`EndlessStudy/Features/History/HeatmapView.swift`:

```swift
import SwiftUI
import StudyCore

struct HeatmapView: View {
    let dailyTotals: [Date: Int]

    private let cell: CGFloat = 14
    private let spacing: CGFloat = 3

    var body: some View {
        let weeks = Heatmap.weeks(endingOn: .now, calendar: .current)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(weeks.indices, id: \.self) { column in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { row in
                            cellView(weeks[column][row])
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .defaultScrollAnchor(.trailing)
    }

    @ViewBuilder
    private func cellView(_ date: Date?) -> some View {
        if let date {
            let level = Heatmap.intensity(minutes: dailyTotals[date] ?? 0)
            RoundedRectangle(cornerRadius: 3)
                .fill(level == 0 ? AnyShapeStyle(Color.secondary.opacity(0.15))
                                 : AnyShapeStyle(.tint.opacity(Double(level) * 0.25)))
                .frame(width: cell, height: cell)
        } else {
            Color.clear.frame(width: cell, height: cell)
        }
    }
}
```

- [ ] **Step 2: HistoryView を実装する**

`EndlessStudy/Features/History/HistoryView.swift` の全文:

```swift
import SwiftUI
import SwiftData
import StudyCore

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StudySession.startedAt, order: .reverse) private var sessions: [StudySession]
    @Query(sort: \Tag.createdAt) private var tags: [Tag]

    @State private var editing: StudySession?
    @State private var errorMessage: String?

    var body: some View {
        let records = sessions.map(\.record)
        let tagTotals = Stats.tagTotals(records)
        NavigationStack {
            List {
                Section("直近 26 週間") {
                    HeatmapView(dailyTotals: Stats.dailyTotals(records, calendar: .current))
                }

                Section("タグ別累計") {
                    ForEach(tags) { tag in
                        HStack {
                            Circle().fill(Color(hex: tag.colorHex)).frame(width: 12, height: 12)
                            Text(tag.name)
                            Spacer()
                            Text(formatMinutes(tagTotals[tag.id] ?? 0))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        delete(offsets.map { tags[$0] })
                    }
                    if let untagged = tagTotals[nil] {
                        HStack {
                            Circle().fill(Color.secondary).frame(width: 12, height: 12)
                            Text("タグなし")
                            Spacer()
                            Text(formatMinutes(untagged))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("履歴") {
                    if sessions.isEmpty {
                        Text("まだ記録がありません")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(sessions) { session in
                        Button {
                            editing = session
                        } label: {
                            row(session)
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        delete(offsets.map { sessions[$0] })
                    }
                }
            }
            .navigationTitle("記録")
        }
        .sheet(item: $editing) { session in
            SessionFormView(mode: .edit(session))
        }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func row(_ session: StudySession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                    if let tag = session.tag {
                        Text(tag.name)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color(hex: tag.colorHex).opacity(0.25), in: Capsule())
                    }
                }
                if !session.memo.isEmpty {
                    Text(session.memo)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(formatMinutes(session.minutes))
                .font(.headline)
        }
    }

    private func delete<T: PersistentModel>(_ models: [T]) {
        for model in models {
            context.delete(model)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = "削除に失敗しました。"
        }
    }
}
```

- [ ] **Step 3: 構文チェック**

Run: `docker run --rm -v "$PWD":/src -w /src swift:6.0-noble sh -c 'find EndlessStudy -name "*.swift" -print0 | xargs -0 swiftc -frontend -parse'`
Expected: 出力なし・終了コード 0

- [ ] **Step 4: コミット**

```bash
git add EndlessStudy/Features/History
git commit -m "feat(app): 草カレンダー・タグ別累計・履歴を追加"
```

---

### Task 9: コレクションタブ（ガチャ・景品・バッジ）

**Files:**
- Modify（全文置き換え）: `EndlessStudy/Features/Collection/CollectionView.swift`

**Interfaces:**
- Consumes: `RecordService.drawGacha()`、`RecordService.playerState()`、`OwnedReward`、`PlayerState`、`StudySession.record`、`Color(hex:)`、`StudyCore.RewardCatalog`、`StudyCore.Reward`、`StudyCore.Rarity`、`StudyCore.GachaResult`、`StudyCore.Badges`、`StudyCore.Progress.snapshot`
- Produces: `struct CollectionView: View`

- [ ] **Step 1: CollectionView を実装する**

`EndlessStudy/Features/Collection/CollectionView.swift` の全文:

```swift
import SwiftUI
import SwiftData
import StudyCore

private struct DrawBox: Identifiable {
    let id = UUID()
    let result: GachaResult
}

struct CollectionView: View {
    @Environment(\.modelContext) private var context
    @Query private var sessions: [StudySession]
    @Query private var states: [PlayerState]
    @Query private var ownedRewards: [OwnedReward]

    @State private var draw: DrawBox?
    @State private var drawCount = 0
    @State private var errorMessage: String?

    private var tickets: Int { states.first?.gachaTickets ?? 0 }
    private var ownedIDs: Set<String> { Set(ownedRewards.map(\.rewardID)) }

    var body: some View {
        let unlocked = Progress.snapshot(sessions: sessions.map(\.record), bonusXP: states.first?.bonusXP ?? 0,
                                         today: .now, calendar: .current).unlockedBadgeIDs
        NavigationStack {
            List {
                Section("ガチャ") {
                    HStack {
                        Label("ガチャ券 \(tickets) 枚", systemImage: "ticket.fill")
                        Spacer()
                        Button("引く", action: drawGacha)
                            .buttonStyle(.borderedProminent)
                            .disabled(tickets == 0)
                    }
                    Text("15 分以上の記録で 1 枚（1 日 3 枚まで）")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("景品 \(ownedIDs.count) / \(RewardCatalog.all.count)") {
                    ForEach(RewardCatalog.all) { reward in
                        rewardRow(reward, owned: ownedIDs.contains(reward.id))
                    }
                }

                Section("バッジ \(unlocked.count) / \(Badges.all.count)") {
                    ForEach(Badges.all) { badge in
                        let isUnlocked = unlocked.contains(badge.id)
                        HStack {
                            Image(systemName: isUnlocked ? "rosette" : "lock.fill")
                                .foregroundStyle(isUnlocked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                            VStack(alignment: .leading) {
                                Text(isUnlocked ? badge.name : "？？？")
                                Text(badge.conditionText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("コレクション")
        }
        .sensoryFeedback(.impact, trigger: drawCount)
        .sheet(item: $draw) { box in
            DrawResultView(result: box.result)
                .presentationDetents([.medium])
        }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func rewardRow(_ reward: Reward, owned: Bool) -> some View {
        let state = states.first
        let isEquipped = reward.kind == .title ? state?.equippedTitleID == reward.id
                                               : state?.equippedThemeID == reward.id
        return Button {
            toggleEquip(reward)
        } label: {
            HStack {
                Text(reward.rarity.label)
                    .font(.caption.bold())
                    .frame(width: 36)
                if let hex = reward.colorHex {
                    Circle()
                        .fill(owned ? Color(hex: hex) : Color.secondary.opacity(0.3))
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "textformat")
                        .frame(width: 16)
                }
                Text(owned ? reward.name : "？？？")
                Spacer()
                if isEquipped {
                    Text("装備中")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(owned ? Color.primary : Color.secondary)
        .disabled(!owned)
    }

    private func drawGacha() {
        do {
            if let result = try RecordService(context: context).drawGacha() {
                drawCount += 1
                draw = DrawBox(result: result)
            }
        } catch {
            errorMessage = "ガチャに失敗しました。券は消費されていません。"
        }
    }

    private func toggleEquip(_ reward: Reward) {
        do {
            let state = try RecordService(context: context).playerState()
            switch reward.kind {
            case .title:
                state.equippedTitleID = state.equippedTitleID == reward.id ? nil : reward.id
            case .theme:
                state.equippedThemeID = state.equippedThemeID == reward.id ? nil : reward.id
            }
            try context.save()
        } catch {
            context.rollback()
            errorMessage = "変更に失敗しました。"
        }
    }
}

private struct DrawResultView: View {
    let result: GachaResult

    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false

    private var rarityColor: Color {
        switch result.reward.rarity {
        case .n: return .gray
        case .r: return .blue
        case .sr: return .purple
        case .ssr: return .orange
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(result.reward.rarity.label)
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(rarityColor)
                .scaleEffect(revealed ? 1 : 0.2)
                .rotationEffect(.degrees(revealed ? 0 : -180))
            Text(result.reward.name)
                .font(.title.bold())
                .opacity(revealed ? 1 : 0)
            Text(result.reward.kind == .title ? "称号" : "テーマ色")
                .foregroundStyle(.secondary)
            if result.isDuplicate {
                Text("もう持っている！ +\(result.bonusXP) XP")
                    .font(.headline)
            }
            Button("OK") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) { revealed = true }
        }
        .sensoryFeedback(.success, trigger: revealed)
    }
}
```

- [ ] **Step 2: 構文チェック**

Run: `docker run --rm -v "$PWD":/src -w /src swift:6.0-noble sh -c 'find EndlessStudy -name "*.swift" -print0 | xargs -0 swiftc -frontend -parse'`
Expected: 出力なし・終了コード 0

- [ ] **Step 3: コミット**

```bash
git add EndlessStudy/Features/Collection
git commit -m "feat(app): ガチャ・景品・バッジのコレクション画面を追加"
```

---

### Task 10: README と最終確認

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: これまでの全タスク
- Produces: Mac でのビルド手順書

- [ ] **Step 1: README を書く**

`README.md`:

````markdown
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
````

- [ ] **Step 2: 全テストと構文チェックを再実行する**

Run: `docker run --rm -v "$PWD/Packages/StudyCore":/pkg -w /pkg swift:6.0-noble swift test`
Expected: `Executed 34 tests, with 0 failures`

Run: `docker run --rm -v "$PWD":/src -w /src swift:6.0-noble sh -c 'find EndlessStudy -name "*.swift" -print0 | xargs -0 swiftc -frontend -parse'`
Expected: 出力なし・終了コード 0

- [ ] **Step 3: コミットしてプッシュ**

```bash
git add README.md
git commit -m "docs: README とビルド手順を追加"
git push -u origin claude/wizardly-newton-whw3pm
```

- [ ] **Step 4: 未検証範囲を報告する**

ユーザーへの報告に次を必ず含める: `StudyCore` は 34 テスト通過で検証済み。アプリ本体（`EndlessStudy/`）は構文チェックのみで、型検査・ビルド・実機動作は未検証。Mac で `xcodegen generate` → ビルドし、エラーが出たら全文を貼ってもらう。
