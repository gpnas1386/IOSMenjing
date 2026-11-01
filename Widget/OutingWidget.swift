//
//  OutingWidget.swift
//  外出登记 · WidgetKit 小组件（负一屏「今天」视图 / 桌面均可添加）
//
//  关键点：
//  1. 与主 App 共用 App Group 里的 outing_records.json，读写同一份数据
//  2. 用 AppIntents 的 Button(intent:) 实现小组件内一键「出岗 / 归岗」，不用进 App
//  3. 外出中时用 Text(timerInterval:) 让系统自己跳秒，几乎零耗电
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline 数据

struct OutingEntry: TimelineEntry {
    let date: Date
    let activeStart: Date?      // 外出中的出岗时间；nil 表示在岗
    let todayCount: Int
    let todaySeconds: TimeInterval
    let todayOvertimeCount: Int
    let lastRecord: WidgetRecordLite?

    var isOuting: Bool { activeStart != nil }

    var isOvertime: Bool {
        guard let activeStart else { return false }
        return date.timeIntervalSince(activeStart) > TimeInterval(OutingConfig.defaultLimitMinutes * 60)
    }
}

/// 小组件侧用的极简记录模型（不复用主 App 的 @MainActor 类，避免并发问题）
struct WidgetRecordLite: Codable {
    var id: UUID
    var start: Date
    var end: Date?
    var note: String?
}

// MARK: - Provider

struct OutingProvider: TimelineProvider {

    func placeholder(in context: Context) -> OutingEntry {
        OutingEntry(date: Date(), activeStart: nil, todayCount: 3,
                    todaySeconds: 27 * 60, todayOvertimeCount: 1,
                    lastRecord: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (OutingEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OutingEntry>) -> Void) {
        let entry = makeEntry()
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func makeEntry() -> OutingEntry {
        let records = WidgetStore.shared.load()
        let now = Date()
        let cal = OutingFormat.calendar

        let active = records.first(where: { $0.end == nil })
        let today = records.filter { cal.isDate($0.start, inSameDayAs: now) }
        let seconds = today.reduce(0.0) { $0 + ($1.end ?? now).timeIntervalSince($1.start) }
        let overtimeCount = today.filter {
            ($0.end ?? now).timeIntervalSince($0.start) > TimeInterval(OutingConfig.defaultLimitMinutes * 60)
        }.count
        let last = records
            .filter { $0.end != nil }
            .sorted { $0.start > $1.start }
            .first

        return OutingEntry(date: now,
                           activeStart: active?.start,
                           todayCount: today.count,
                           todaySeconds: seconds,
                           todayOvertimeCount: overtimeCount,
                           lastRecord: last)
    }
}

// MARK: - 小组件内读写存储

enum WidgetStore {
    static let shared = WidgetStore()

    private var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: OutingConfig.appGroupID)?
            .appendingPathComponent("outing_records.json")
    }

    func load() -> [WidgetRecordLite] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([WidgetRecordLite].self, from: data)
        else { return [] }
        return decoded.sorted { $0.start > $1.start }
    }

    func save(_ records: [WidgetRecordLite]) {
        guard let url = fileURL else { return }
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// 小组件里点按钮：在岗→出岗，外出→归岗
    @discardableResult
    func toggle() -> Bool {
        var records = load()
        let now = Date()
        if let idx = records.firstIndex(where: { $0.end == nil }) {
            records[idx].end = max(now, records[idx].start)
        } else {
            records.insert(WidgetRecordLite(id: UUID(), start: now, end: nil, note: nil), at: 0)
        }
        save(records)
        return true
    }
}

// MARK: - AppIntent（小组件按钮）

@available(iOS 17.0, *)
struct ToggleOutingIntent: AppIntent {
    static var title: LocalizedStringResource = "出岗 / 归岗"
    static var description = IntentDescription("点击记录出岗或归岗时间")
    /// 不打开 App，直接在后台完成
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetStore.shared.toggle()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - 视图

struct OutingWidgetView: View {
    var entry: OutingEntry
    @Environment(\.widgetFamily) private var family

    private var stateColor: Color {
        if entry.isOvertime { return Theme.overtime }
        return entry.isOuting ? Theme.outing : Theme.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 4)
            mainArea
            Spacer(minLength: 4)
            footer
        }
        .padding(14)
        .modifier(WidgetBackgroundModifier(stateColor: stateColor))
        .widgetURL(URL(string: "outingtracker://toggle")!)
    }

    // 顶部：状态
    private var header: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(stateColor)
                .frame(width: 7, height: 7)
            Text(entry.isOuting ? "外出中" : "在岗")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(stateColor)
            Spacer()
            Text(entry.date, format: .dateTime.hour().minute())
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // 中部：计时 or 今日概览
    @ViewBuilder
    private var mainArea: some View {
        if let start = entry.activeStart {
            VStack(alignment: .leading, spacing: 2) {
                // 系统托管计时器，不耗电、秒级跳
                Text(start, style: .timer)
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(entry.isOvertime ? Theme.overtime : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(entry.isOvertime
                     ? "已超 \(OutingConfig.defaultLimitMinutes) 分钟"
                     : "\(OutingFormat.clock(start)) 出岗 · 限 \(OutingConfig.defaultLimitMinutes) 分钟")
                    .font(.system(size: 10.5, weight: entry.isOvertime ? .semibold : .regular))
                    .foregroundColor(entry.isOvertime ? Theme.overtime : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(entry.todayCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("次")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Text("今日 \(OutingFormat.duration(entry.todaySeconds))")
                    .font(.system(size: 10.5))
                    .foregroundColor(entry.todayOvertimeCount > 0 ? Theme.overtime : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    // 底部：一键按钮
    private var footer: some View {
        Group {
            if #available(iOS 17.0, *) {
                Button(intent: ToggleOutingIntent()) {
                    buttonLabel
                }
                .buttonStyle(.plain)
            } else {
                // iOS 16：小组件内不能执行 AppIntent，退化为打开 App
                if let url = URL(string: "outingtracker://toggle") {
                    Link(destination: url) { buttonLabel }
                } else {
                    buttonLabel
                }
            }
        }
    }

    private var buttonLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.isOuting ? "figure.walk.arrival" : "figure.walk.departure")
                .font(.system(size: 11, weight: .bold))
            Text(entry.isOuting ? "归岗" : "出岗")
                .font(.system(size: 12.5, weight: .bold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(stateColor)
        )
    }
}

// MARK: - iOS 16/17 双版本背景兼容

private struct WidgetBackgroundModifier: ViewModifier {
    let stateColor: Color

    func body(content: Content) -> some View {
        let grad = LinearGradient(
            colors: [Color(.secondarySystemGroupedBackground),
                     stateColor.opacity(0.10)],
            startPoint: .top, endPoint: .bottom
        )
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) { grad }
        } else {
            content.background(grad)
        }
    }
}

// MARK: - Widget 定义

struct OutingWidget: Widget {
    let kind = "OutingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            OutingWidgetView(entry: entry)
        }
        .configurationDisplayName("外出登记")
        .description("一眼看到当前是否在外、已用时多久，点一下就能打点。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct OutingWidgetBundle: WidgetBundle {
    var body: some Widget {
        OutingWidget()
    }
}
