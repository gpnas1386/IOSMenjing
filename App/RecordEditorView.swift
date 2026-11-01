//
//  RecordEditorView.swift
//  新增 / 编辑一条记录
//

import SwiftUI

struct RecordEditorView: View {
    @EnvironmentObject private var store: OutingStore
    @Environment(\.dismiss) private var dismiss

    /// nil 表示新增
    let record: OutingRecord?

    @State private var start: Date = Date()
    @State private var end: Date = Date()
    @State private var isOngoing: Bool = false
    @State private var note: String = ""
    @State private var loaded = false

    private var isEditing: Bool { record != nil }

    private var duration: TimeInterval {
        max(0, (isOngoing ? Date() : end).timeIntervalSince(start))
    }

    private var overtime: Bool {
        duration > TimeInterval(OutingConfig.defaultLimitMinutes * 60)
    }

    private var canSave: Bool {
        isOngoing || end >= start
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("出岗时间", selection: $start, displayedComponents: [.date, .hourAndMinute])

                    Toggle("仍在外面（进行中）", isOn: $isOngoing)
                        .tint(Theme.outing)

                    if !isOngoing {
                        DatePicker("归岗时间", selection: $end, displayedComponents: [.date, .hourAndMinute])
                    }
                } header: {
                    Text("时间")
                } footer: {
                    if isOngoing {
                        Text("保存后这条记录会保持「进行中」，在主页或小组件点归岗即可结束。")
                    } else if end < start {
                        Text("归岗时间不能早于出岗时间。")
                            .foregroundColor(Theme.overtime)
                    }
                }

                Section("外出时长") {
                    HStack {
                        Text("时长")
                        Spacer()
                        Text(OutingFormat.duration(duration))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundColor(overtime ? Theme.overtime : .primary)
                    }
                    if overtime {
                        Label("已超出 \(OutingConfig.defaultLimitMinutes) 分钟上限，将标红提醒",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(Theme.overtime)
                    }
                }

                Section("备注") {
                    TextField("例如：去医院、取快递（选填）", text: $note)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            if let record {
                                store.delete(id: record.id)
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除这条记录")
                                Spacer()
                            }
                        }
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isEditing ? "保存修改" : "保存记录")
                                .font(.body.weight(.semibold))
                                .foregroundColor(canSave ? Theme.accent : .secondary)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                } footer: {
                    Text("提示：日期可切到任意一天，周六日照常记录并计入统计。")
                }
            }
            .navigationTitle(isEditing ? "编辑记录" : "补录记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let record {
            start = record.start
            isOngoing = record.end == nil
            end = record.end ?? Date()
            note = record.note
        } else {
            // 新增默认给一个最近 10 分钟、看起来合理的区间
            let now = Date()
            start = now.addingTimeInterval(-10 * 60)
            end = now
        }
    }

    private func save() {
        if let record {
            store.update(id: record.id,
                         start: start,
                         end: isOngoing ? nil : end,
                         note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            store.addManual(start: start,
                            end: isOngoing ? start : end,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        dismiss()
    }
}
