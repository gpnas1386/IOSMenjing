//
//  SettingsView.swift
//  设置 / 统计 / 数据管理
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: OutingStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingClearConfirm = false
    @State private var showingShare = false
    @State private var shareItems: [Any] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("使用说明") {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("一次点击一个动作")
                                .font(.subheadline.weight(.medium))
                            Text("在岗时点「出岗」开始计时，回来后点「归岗」结束，自动算时长。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "hand.tap.fill").foregroundColor(Theme.accent)
                    }

                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("单次上限 \(OutingConfig.defaultLimitMinutes) 分钟")
                                .font(.subheadline.weight(.medium))
                            Text("超过上限不会阻止记录，但时长会标红，并在归岗时提示超时。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "timer").foregroundColor(Theme.overtime)
                    }

                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("周六日同样计入")
                                .font(.subheadline.weight(.medium))
                            Text("任何一天都可以记录，周末记录会打上「周末」标签，一并计入本周统计。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "calendar.badge.clock").foregroundColor(Theme.outing)
                    }

                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("添加到负一屏")
                                .font(.subheadline.weight(.medium))
                            Text("长按锁屏/桌面空白处 → 左上角「+」→ 搜索「外出登记」→ 添加小组件。小组件上可直接点按钮打点。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "rectangle.grid.1x2.fill").foregroundColor(.purple)
                    }
                }

                Section("统计") {
                    let all = allRecordsSummary()
                    statRow("记录总数", "\(store.records.count) 条")
                    statRow("累计外出", OutingFormat.duration(all.seconds))
                    statRow("超时次数", "\(all.overtimeCount) 次")
                }

                Section("数据") {
                    Button {
                        exportCSV()
                    } label: {
                        Label("导出 CSV", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showingClearConfirm = true
                    } label: {
                        Label("清空全部记录", systemImage: "trash")
                    }
                }

                Section {
                    Text("数据保存在本机 App Group 容器内，不会上传。卸载 App 会一并清除。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .confirmationDialog("确定清空全部记录？", isPresented: $showingClearConfirm, titleVisibility: .visible) {
                Button("清空", role: .destructive) { store.deleteAll() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作不可撤销。")
            }
            .sheet(isPresented: $showingShare) {
                ShareSheet(items: shareItems)
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private func allRecordsSummary() -> OutingSummary {
        OutingSummary(
            count: store.records.count,
            seconds: store.records.reduce(0) { $0 + $1.duration() },
            overtimeCount: store.records.filter { $0.isOvertime() }.count
        )
    }

    private func exportCSV() {
        var lines = ["日期,星期,出岗时间,归岗时间,时长(分钟),是否超时,备注"]
        let cal = OutingFormat.calendar
        for record in store.records.sorted(by: { $0.start < $1.start }) {
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"
            let day = dateFmt.string(from: record.start)
            let week = OutingFormat.weekday(record.start)
            let start = OutingFormat.clock(record.start)
            let end = record.end.map(OutingFormat.clock) ?? "进行中"
            let minutes = String(format: "%.1f", record.duration() / 60)
            let over = record.isOvertime() ? "是" : "否"
            let note = record.note.replacingOccurrences(of: ",", with: "，")
            lines.append("\(day),\(week),\(start),\(end),\(minutes),\(over),\(note)")
        }
        let csv = "\u{FEFF}" + lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("外出记录.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        shareItems = [url]
        showingShare = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
