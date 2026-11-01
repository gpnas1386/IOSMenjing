//
//  RootView.swift
//  外出登记 · 主界面
//
//  设计思路：
//  - 顶部一张「大卡片」承担全部核心信息：当前状态、计时、一键打点按钮
//  - 中部今日统计（次数 / 累计 / 超标次数）
//  - 下部按天分组的历史列表，支持编辑、补录、删除
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: OutingStore

    @State private var showingEditor = false
    @State private var editingRecord: OutingRecord?
    @State private var showingSettings = false
    @State private var showingOvertimeToast = false
    @State private var overtimeText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    StatusCard(
                        active: store.activeRecord,
                        onToggle: handleToggle
                    )
                    .padding(.horizontal, 16)

                    TodayStatsCard(store: store)
                        .padding(.horizontal, 16)

                    HistorySection(
                        onEdit: { record in
                            editingRecord = record
                            showingEditor = true
                        },
                        onAdd: {
                            editingRecord = nil
                            showingEditor = true
                        },
                        onDelete: { record in
                            store.delete(id: record.id)
                        }
                    )
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("外出登记")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        editingRecord = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                RecordEditorView(record: editingRecord)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(store)
            }
            .overlay(alignment: .top) {
                if showingOvertimeToast {
                    OvertimeToast(text: overtimeText)
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear { store.reloadIfNeeded() }
        }
    }

    private func handleToggle() {
        let wasOuting = store.isOuting
        let closed = store.toggle()
        if wasOuting, let closed, closed.isOvertime() {
            overtimeText = "本次外出 \(OutingFormat.duration(closed.duration()))，已超出 \(OutingConfig.defaultLimitMinutes) 分钟上限"
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showingOvertimeToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showingOvertimeToast = false
                }
            }
        }
    }
}

// MARK: - 主题

enum Theme {
    static let accent = Color(red: 0.13, green: 0.45, blue: 0.98)      // 在岗 / 主色
    static let outing = Color(red: 1.00, green: 0.58, blue: 0.12)      // 外出中 橙色
    static let overtime = Color(red: 0.92, green: 0.26, blue: 0.24)    // 超时 红色
    static let ok = Color(red: 0.16, green: 0.68, blue: 0.42)          // 合规 绿色
}

// MARK: - 顶部状态卡片

struct StatusCard: View {
    let active: OutingRecord?
    let onToggle: () -> Void

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // 状态标签
            HStack(spacing: 6) {
                Circle()
                    .fill(active == nil ? Theme.accent : Theme.outing)
                    .frame(width: 8, height: 8)
                Text(active == nil ? "当前在岗" : "外出中")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(active == nil ? Theme.accent : Theme.outing)
                Spacer()
                if let active {
                    Text("出岗 \(OutingFormat.clock(active.start))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            // 计时
            VStack(spacing: 6) {
                if let active {
                    let secs = active.duration(now: now)
                    let overtime = secs > TimeInterval(OutingConfig.defaultLimitMinutes * 60)
                    Text(OutingFormat.clockWithSeconds(Date(timeInterval: secs, since: Date(timeIntervalSince1970: 0))))
                        .font(.system(size: 56, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(overtime ? Theme.overtime : .primary)
                    Text(overtime
                         ? "已超出 \(OutingConfig.defaultLimitMinutes) 分钟上限"
                         : "剩余 \(OutingFormat.duration(TimeInterval(OutingConfig.defaultLimitMinutes * 60) - secs))")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(overtime ? Theme.overtime : Theme.ok)
                } else {
                    Text("00:00:00")
                        .font(.system(size: 56, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("点击下方按钮开始记录外出")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)

            // 主按钮
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: active == nil ? "figure.walk.departure" : "figure.walk.arrival")
                        .font(.system(size: 20, weight: .semibold))
                    Text(active == nil ? "出岗" : "归岗")
                        .font(.system(size: 20, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(active == nil ? Theme.accent : Theme.outing)
                )
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onReceive(timer) { now = $0 }
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 今日统计

struct TodayStatsCard: View {
    @ObservedObject var store: OutingStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let today = store.todaySummary(now: now)
        let week = store.weekSummary(now: now)
        let limited = today.seconds > TimeInterval(OutingConfig.defaultLimitMinutes * 60)

        VStack(spacing: 14) {
            HStack {
                Text("今天")
                    .font(.subheadline.weight(.semibold))
                + Text("  \(OutingFormat.weekday(now))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("单次限 \(OutingConfig.defaultLimitMinutes) 分钟")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 0) {
                StatItem(
                    title: "外出次数",
                    value: "\(today.count)",
                    unit: "次",
                    color: .primary
                )
                Divider().frame(height: 34)
                StatItem(
                    title: "累计时长",
                    value: OutingFormat.duration(today.seconds),
                    unit: "",
                    color: limited ? Theme.overtime : .primary
                )
                Divider().frame(height: 34)
                StatItem(
                    title: "超时次数",
                    value: "\(today.overtimeCount)",
                    unit: "次",
                    color: today.overtimeCount > 0 ? Theme.overtime : Theme.ok
                )
            }

            Divider()

            HStack {
                Label("本周累计", systemImage: "calendar")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(week.count) 次 · \(OutingFormat.duration(week.seconds))")
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onReceive(timer) { now = $0 }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 超时提示条

struct OvertimeToast: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(Theme.overtime)
        )
        .padding(.horizontal, 24)
        .shadow(color: Theme.overtime.opacity(0.3), radius: 12, y: 6)
    }
}
