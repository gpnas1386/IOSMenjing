# 外出登记 · OutingTracker

一个极简的外出计时工具，专为 **iPhone 14 Pro Max + iOS 16.1.1 + TrollStore（巨魔）** 环境设计。

## 功能

- **一键打点**：在岗时点「出岗」开始计时，回来点「归岗」结束，自动计算外出时长
- **15 分钟上限**：单次外出默认不超过 15 分钟；超出后时长标红、归岗时弹提示条（不阻止记录）
- **周六日照常计入**：任何一天都能记录，周末记录打「周末」标签，一并计入本周统计
- **负一屏小组件**：WidgetKit 小组件，显示当前在岗/外出中、秒级计时、今日次数与累计时长；支持一键打点
- **历史记录**：按天分组，支持补录、编辑、删除，支持导出 CSV

## 添加到负一屏

1. 在主屏幕一直向左滑，进入「今天」视图（负一屏）
2. 长按空白处 → 点左上角「+」
3. 搜索「外出登记」→ 选择小组件 → 添加小组件
4. 小组件上的按钮可直接打点（iOS 17+ 后台执行不跳 App；iOS 16 会先打开 App 再自动记录）

## 编译打包（需要一台 Mac）

本项目是标准 Xcode 工程，无法在 Linux/Windows 上编译，请用 Mac 上的 Xcode（15 及以上均可，最低 Xcode 14）：

```bash
git clone <本仓库>   # 或直接解压
cd OutingTracker
open OutingTracker.xcodeproj
```

1. 选中 **OutingTracker** target → Signing & Capabilities：
   - Team 选你的 Apple ID（免费个人账号即可）
   - 勾选 `Automatically manage signing`
2. 菜单 **Product → Archive**（设备选 Any iOS Device）
3. Archive 完成后 **Distribute App → Custom → Debugging**，导出得到 `OutingTracker.ipa`

> 不需要付费开发者账号，TrollStore 安装不校验签名。

## 用 TrollStore 安装

1. 把 `OutingTracker.ipa` 传到 iPhone（AirDrop / 文件 App / 网盘均可）
2. 用「文件」App 长按 ipa → 分享 → **TrollStore**
3. TrollStore 弹出后点「Install」即可

或直接在 Mac 上用 TrollInstaller 一键安装。

## 工程结构

```
OutingTracker/
├── OutingTracker.xcodeproj/
├── App/                    # 主 App（SwiftUI, iOS 16+）
│   ├── OutingTrackerApp.swift   入口 + URL Scheme（outingtracker://toggle）
│   ├── RootView.swift           状态卡片 / 今日统计 / 超时提示
│   ├── HistorySection.swift     按天分组历史列表
│   ├── RecordEditorView.swift   补录 / 编辑
│   └── SettingsView.swift       设置 / 统计 / 导出
├── Shared/
│   └── OutingStore.swift        共享数据层（App Group JSON 持久化）
└── Widget/
    └── OutingWidget.swift       小组件（systemSmall / systemMedium）
```

## 数据存储

记录保存在 App Group 容器 `group.com.troll.outing` 下的 `outing_records.json`，主 App 与小组件共享同一份文件，不上传任何数据，卸载即清空。

## 自定义

改 `Shared/OutingStore.swift` 里的 `OutingConfig`：

| 配置项 | 默认值 | 说明 |
|---|---|---|
| `defaultLimitMinutes` | 15 | 单次外出上限（分钟），超时标红 |
| `appGroupID` | group.com.troll.outing | App Group 标识（改了要同步改两个 target 的 entitlements） |
| `includeWeekends` | true | 周末是否计入（当前计入） |
