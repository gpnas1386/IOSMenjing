//
//  OutingStore.swift
//  外出登记 · 共享数据层
//
//  这个文件同时被主 App 和 Widget 扩展编译，是两边通讯的唯一数据源。
//  数据落在 App Group 容器里的 JSON 文件中，Widget 通过 reloadAllTimelines 拿到最新状态。
//

import Foundation
import WidgetKit

// MARK: - 常量

enum OutingConfig {
    /// App Group 标识。主 App、Widget 的 entitlements 必须与此完全一致。
    static let appGroupID = "group.com.troll.outing"

    /// 单次外出默认时长上限（分钟）。超过即标红提醒。
    static let defaultLimitMinutes = 15

    /// 是否把周六、周日也计入统计。当前设置：计入。
    static let includeWeekends = true
}

// MARK: - 数据模型

/// 一条外出记录。`end == nil` 表示仍在外面（进行中）。
struct OutingRecord: Codable, Identifiable, Hashable {
    var id: UUID
    /// 出岗时间
    var start: Date
    /// 归岗时间，nil 表示进行中
    var end: Date?
    /// 备注 / 外出原因（可选）
    var note: String

    init(id: UUID = UUID(), start: Date, end: Date? = nil, note: String = "") {
        self.id = id
        self.start = start
        self.end = end
        self.note = note
    }

    var isActive: Bool { end == nil }

    /// 外出时长（秒）。进行中的记录按「现在」计算。
    func duration(now: Date = Date()) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }

    /// 是否已超出单次默认上限
    func isOvertime(limitMinutes: Int = OutingConfig.defaultLimitMinutes,
                    now: Date = Date()) -> Bool {
        duration(now: now) > TimeInterval(limitMinutes * 60)
    }
}

/// 统计颗粒度的汇总结果
struct OutingSummary {
    var count: Int = 0
    var seconds: TimeInterval = 0
    var overtimeCount: Int = 0

    var minutes: Int { Int((seconds / 60).rounded()) }
}

// MARK: - 时间格式化工具

enum OutingFormat {
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "zh_Hans_CN")
        cal.firstWeekday = 2 // 周一为一周开始
        return cal
    }()

    /// HH:mm
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// HH:mm:ss （进行中的秒级计时）
    static func clockWithSeconds(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    /// 9月3日 周三 / 今天 / 昨天
    static func dayTitle(_ date: Date, now: Date = Date()) -> String {
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    /// 时长显示：45秒 / 12分30秒 / 1小时05分
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total)秒" }
        let m = total / 60, s = total % 60
        if m < 60 { return s == 0 ? "\(m)分钟" : "\(m)分\(s)秒" }
        let h = m / 60, mm = m % 60
        return String(format: "%d小时%02d分", h, mm)
    }

    /// 紧凑时长：8′30″ 形式，给小组件用
    static func compact(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total)″" }
        let m = total / 60, s = total % 60
        if m < 60 { return s == 0 ? "\(m)′" : "\(m)′\(String(format: "%02d", s))″" }
        return String(format: "%d:%02d", m / 60, m % 60)
    }
}

// MARK: - 存储

/// 线程安全（main actor 隔离）的记录仓库。主 App 与 Widget 各自持有一份，靠 JSON 文件同步。
@MainActor
final class OutingStore: ObservableObject {

    static let shared = OutingStore()

    /// 供 UI 绑定的全部记录（按时间倒序）
    @Published private(set) var records: [OutingRecord] = []

    private let fileURL: URL?
    private var cacheDate: Date = .distantPast

    private init() {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: OutingConfig.appGroupID)
        self.fileURL = container?.appendingPathComponent("outing_records.json")
        load()
    }

    // MARK: 读写

    func load() {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([OutingRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded.sorted { $0.start > $1.start }
        cacheDate = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
    }

    /// 如果共享文件被另一端改过，就重新读一次（主 App 在前台回到时调用）
    func reloadIfNeeded() {
        guard let url = fileURL,
              let mtime = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        else { return }
        if mtime > cacheDate {
            load()
        }
    }

    private func persist() {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: url, options: .atomic)
            cacheDate = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? Date()
        } catch {
            // 落盘失败时保留内存态，不影响界面使用
            print("[OutingStore] persist failed: \(error)")
        }
        reloadWidgets()
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: 查询

    /// 当前进行中的记录（正常最多一条）
    var activeRecord: OutingRecord? {
        records.first(where: { $0.isActive })
    }

    var isOuting: Bool { activeRecord != nil }

    /// 某一天的全部记录（按出岗时间正序）
    func records(on day: Date) -> [OutingRecord] {
        records
            .filter { OutingFormat.calendar.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
    }

    /// 某一天的汇总
    func summary(on day: Date, now: Date = Date()) -> OutingSummary {
        let list = records(on: day)
        return OutingSummary(
            count: list.count,
            seconds: list.reduce(0) { $0 + $1.duration(now: now) },
            overtimeCount: list.filter { $0.isOvertime(now: now) }.count
        )
    }

    /// 今天的汇总（含周末，不做排除）
    func todaySummary(now: Date = Date()) -> OutingSummary {
        summary(on: now, now: now)
    }

    /// 从某天所在周（周一起算）到目前为止的汇总
    func weekSummary(reference: Date = Date(), now: Date = Date()) -> OutingSummary {
        let cal = OutingFormat.calendar
        guard let interval = cal.dateInterval(of: .weekOfYear, for: reference) else {
            return OutingSummary()
        }
        let list = records.filter {
            $0.start >= interval.start && $0.start < interval.end
        }
        return OutingSummary(
            count: list.count,
            seconds: list.reduce(0) { $0 + $1.duration(now: now) },
            overtimeCount: list.filter { $0.isOvertime(now: now) }.count
        )
    }

    /// 所有记录按「天」分组，日期倒序
    var groupedByDay: [(day: Date, records: [OutingRecord])] {
        let cal = OutingFormat.calendar
        let groups = Dictionary(grouping: records) { cal.startOfDay(for: $0.start) }
        return groups
            .map { (day: $0.key, records: $0.value.sorted { $0.start < $1.start }) }
            .sorted { $0.day > $1.day }
    }

    // MARK: 打点

    /// 主操作：在岗 → 出岗；外出中 → 归岗。返回刚关闭的记录（若为归岗）
    @discardableResult
    func toggle(now: Date = Date()) -> OutingRecord? {
        if let active = activeRecord {
            return endOuting(id: active.id, at: now)
        } else {
            startOuting(at: now)
            return nil
        }
    }

    func startOuting(at date: Date = Date()) {
        // 兜底：若历史数据里有多条未关闭记录，先把它们关闭再开新的
        for i in records.indices where records[i].isActive {
            records[i].end = date
        }
        records.insert(OutingRecord(start: date), at: 0)
        persist()
    }

    @discardableResult
    func endOuting(id: UUID, at date: Date = Date()) -> OutingRecord? {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return nil }
        // 归岗时间不允许早于出岗时间
        let start = records[idx].start
        records[idx].end = max(date, start)
        let updated = records[idx]
        persist()
        return updated
    }

    /// 补录一条完整记录
    func addManual(start: Date, end: Date, note: String = "") {
        let record = OutingRecord(start: min(start, end), end: max(start, end), note: note)
        records.append(record)
        records.sort { $0.start > $1.start }
        persist()
    }

    /// 修改一条记录的出岗/归岗时间与备注
    func update(id: UUID, start: Date, end: Date?, note: String) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].start = start
        if let end = end, end >= start {
            records[idx].end = end
        }
        records[idx].note = note
        records.sort { $0.start > $1.start }
        persist()
    }

    func delete(id: UUID) {
        records.removeAll { $0.id == id }
        persist()
    }

    /// 清空全部
    func deleteAll() {
        records = []
        persist()
    }
}
