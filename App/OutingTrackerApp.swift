//
//  OutingTrackerApp.swift
//  外出登记 · 主 App 入口
//

import SwiftUI

@main
struct OutingTrackerApp: App {
    @StateObject private var store = OutingStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onChange(of: scenePhase) { phase in
                    // 从小组件改了状态后回到 App，刷新一次
                    if phase == .active {
                        store.reloadIfNeeded()
                    }
                }
                // 小组件在 iOS 16 上无法直接执行 AppIntent，退化为打开 App 并立即打点
                .onOpenURL { url in
                    guard url.scheme == "outingtracker", url.host == "toggle" else { return }
                    store.reloadIfNeeded()
                    store.toggle()
                }
        }
    }
}
