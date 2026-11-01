//
//  HistorySection.swift
//  按天分组的历史列表
//

import SwiftUI

struct HistorySection: View {
    @EnvironmentObject private var store: OutingStore

    let onEdit: (OutingRecord) -> Void
    let onAdd: () -> Void
    let onDelete: (OutingRecord) -> Void

    @State private var pendingDelete: OutingRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("记录")
                    .font(.headline)
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Label("补录", systemImage: "plus")
                        .font(.footnote.weight(.semibold))
                }
            }
            .padding(.horizontal, 20)

            if store.groupedByDay.isEmpty {
                EmptyHistoryView(onAdd: onAdd)
            } else {
                ForEach(store.groupedByDay, id: \.day) { group in
                    DayGroupView(
                        day: group.day,
                        records: group.records,
                        summary: store.summary(on: group.day),
                        onEdit: onEdit,
                        onDelete: { record in pendingDelete = record }
                    )
                }
            }
        }
        .alert(
            "删除这条记录？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { record in
            Button("删除", role: .destructive) {
                onDelete(record)
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { record in
            Text("\(OutingFormat.clock(record.start)) – \(record.end.map(OutingFormat.clock) ?? "进行中")，删除后不可恢复。")
        }
    }
}

struct DayGroupView: View {
    let day: Date
    let records: [OutingRecord]
    let summary: OutingSummary
    let onEdit: (OutingRecord) -> Void
    let onDelete: (OutingRecord) -> Void

    @State private var now = Date()

    private var isWeekend: Bool {
        OutingFormat.calendar.isDateInWeekend(day)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 日标题
            HStack(spacing: 6) {
                Text(OutingFormat.dayTitle(day))
                    .font(.subheadline.weight(.semibold))
                Text(OutingFormat.weekday(day))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if isWeekend {
                    Text("周末")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.outing))
                }
                Spacer()
                Text("\(summary.count) 次 · \(OutingFormat.duration(summary.seconds))")
                    .font(.caption)
                    .foregroundColor(summary.overtimeCount > 0 ? Theme.overtime : .secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Divider().padding(.leading, 18)

            ForEach(Array(records.enumerated()), id: \.element.id) { idx, record in
                RecordRow(record: record, now: now, onEdit: { onEdit(record) })
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            onEdit(record)
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            onDelete(record)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDelete(record)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        Button {
                            onEdit(record)
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .onTapGesture { onEdit(record) }

                if idx < records.count - 1 {
                    Divider().padding(.leading, 18)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
    }
}

struct RecordRow: View {
    let record: OutingRecord
    let now: Date
    let onEdit: () -> Void

    var body: some View {
        let overtime = record.isOvertime(now: now)
        HStack(spacing: 12) {
            // 时间轴圆点
            VStack(spacing: 2) {
                Circle()
                    .fill(record.isActive ? Theme.outing : (overtime ? Theme.overtime : Theme.accent))
                    .frame(width: 9, height: 9)
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(OutingFormat.clock(record.start))
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    if let end = record.end {
                        Text(OutingFormat.clock(end))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    } else {
                        Text("进行中")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Theme.outing)
                    }
                }
                if !record.note.isEmpty {
                    Text(record.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                if overtime {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                }
                Text(OutingFormat.duration(record.duration(now: now)))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .foregroundColor(overtime ? Theme.overtime : .secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

struct EmptyHistoryView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.walk")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(Color(.tertiaryLabel))
            Text("还没有记录")
                .font(.subheadline.weight(.medium))
            Text("点上方大按钮记录出岗，回来后点归岗")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("补录一条", action: onAdd)
                .font(.footnote.weight(.semibold))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
    }
}
