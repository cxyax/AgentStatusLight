//
//  AgentModels.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import Foundation
import SwiftUI

/**
 * Agent 类型枚举，用于区分 Claude 与 Codex
 * @author 程序员阿鑫
 */
enum AgentKind: String, CaseIterable, Identifiable, Sendable {
    case claude
    case codex

    /**
     * 枚举唯一标识
     */
    var id: String {
        rawValue
    }

    /**
     * 用于界面展示的名称
     */
    var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        }
    }
}

/**
 * 状态灯颜色枚举
 * @author 程序员阿鑫
 */
enum LightColor: String, Sendable {
    case green
    case yellow
    case red
    case gray
    case fault

    /**
     * 将业务颜色映射为 SwiftUI 颜色
     */
    var color: Color {
        adaptiveColor(for: .light)
    }

    /**
     * 根据颜色方案返回更舒适的状态灯颜色
     * @param colorScheme 当前颜色方案
     * @return 适配后的颜色
     */
    func adaptiveColor(for colorScheme: ColorScheme) -> Color {
        switch (self, colorScheme) {
        case (.green, .dark):
            return Color(red: 0.33, green: 0.88, blue: 0.48)
        case (.green, .light):
            return Color(red: 0.24, green: 0.72, blue: 0.38)
        case (.yellow, .dark):
            return Color(red: 0.98, green: 0.82, blue: 0.36)
        case (.yellow, .light):
            return Color(red: 0.88, green: 0.72, blue: 0.28)
        case (.red, .dark):
            return Color(red: 0.96, green: 0.42, blue: 0.36)
        case (.red, .light):
            return Color(red: 0.86, green: 0.39, blue: 0.34)
        case (.gray, .dark):
            return Color(red: 0.63, green: 0.67, blue: 0.73)
        case (.gray, .light):
            return Color(red: 0.60, green: 0.64, blue: 0.69)
        case (.fault, .dark):
            return Color(red: 1.0, green: 0.37, blue: 0.30)
        case (.fault, .light):
            return Color(red: 0.94, green: 0.30, blue: 0.25)
        @unknown default:
            return Color(red: 0.60, green: 0.64, blue: 0.69)
        }
    }
}

/**
 * 主题模式枚举，支持白天、夜晚和跟随系统
 * @author 程序员阿鑫
 */
enum DisplayThemeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case daylight
    case night

    /**
     * 唯一标识
     */
    var id: String {
        rawValue
    }

    /**
     * 展示名称
     */
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .daylight:
            return "白天视图"
        case .night:
            return "夜晚视图"
        }
    }
}

/**
 * 轮询频率枚举，用于控制兜底刷新的时间间隔
 * @author 程序员阿鑫
 */
enum PollingInterval: String, Codable, CaseIterable, Identifiable, Sendable {
    case everySecond
    case everyTwoSeconds
    case everyFiveSeconds

    /**
     * 唯一标识
     */
    var id: String {
        rawValue
    }

    /**
     * 展示名称
     */
    var displayName: String {
        switch self {
        case .everySecond:
            return "1秒"
        case .everyTwoSeconds:
            return "2秒"
        case .everyFiveSeconds:
            return "5秒"
        }
    }

    /**
     * 对应的秒数
     */
    var seconds: Int {
        switch self {
        case .everySecond:
            return 1
        case .everyTwoSeconds:
            return 2
        case .everyFiveSeconds:
            return 5
        }
    }
}

/**
 * 悬浮窗显示模式枚举，用于切换聚合单灯与双灯箱展示
 * @author 程序员阿鑫
 */
enum FloatingWindowDisplayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case dualPanel
    case singleLamp

    /**
     * 唯一标识
     */
    var id: String {
        rawValue
    }

    /**
     * 展示名称
     */
    var displayName: String {
        switch self {
        case .dualPanel:
            return "双灯模式"
        case .singleLamp:
            return "单灯模式"
        }
    }
}

/**
 * 悬浮窗灯位布局枚举，用于切换竖向堆叠与横向排列
 * @author 程序员阿鑫
 */
enum FloatingWindowLampLayoutMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case vertical
    case horizontal

    /**
     * 唯一标识
     */
    var id: String {
        rawValue
    }

    /**
     * 展示名称
     */
    var displayName: String {
        switch self {
        case .vertical:
            return "竖向"
        case .horizontal:
            return "横向"
        }
    }
}

/**
 * 横向灯位时的悬浮窗排列方式枚举，用于切换上下堆叠与左右并排
 * @author 程序员阿鑫
 */
enum FloatingWindowHorizontalPanelArrangement: String, Codable, CaseIterable, Identifiable, Sendable {
    case upDown
    case leftRight

    /**
     * 唯一标识
     */
    var id: String {
        rawValue
    }

    /**
     * 展示名称
     */
    var displayName: String {
        switch self {
        case .upDown:
            return "上下"
        case .leftRight:
            return "左右"
        }
    }
}

/**
 * 提醒功能默认配置
 * @author 程序员阿鑫
 */
enum StatusAlertDefaults {
    /**
     * 默认内置语音提醒标识
     */
    static let defaultAudioPath = "builtin://xiaoba-oi"

    /**
     * 默认内置语音提醒文件名
     */
    static let defaultAudioFileName = "小八oi.mp3"

    /**
     * 默认内置语音提醒文件名（不含扩展名）
     */
    static let defaultAudioResourceName = "小八oi"

    /**
     * 默认内置语音提醒资源目录
     */
    static let defaultAudioSubdirectory = "Audio"

    /**
     * 默认语音提醒展示文案
     */
    static let defaultAudioDisplayName = "内置音频：小八oi.mp3"
}

/**
 * 悬浮窗缩放默认配置
 * @author 程序员阿鑫
 */
enum FloatingWindowScaleDefaults {
    /**
     * 默认缩放比例
     */
    static let defaultScale: Double = 1.0

    /**
     * 最小缩放比例
     */
    static let minimumScale: Double = 0.30

    /**
     * 最大缩放比例
     */
    static let maximumScale: Double = 1.80

    /**
     * 设置面板中的步进值
     */
    static let step: Double = 0.05

    /**
     * 将缩放比例限制在允许区间内
     * @param scale 原始缩放比例
     * @return 限制后的缩放比例
     */
    static func clampedScale(_ scale: Double) -> Double {
        min(max(scale, minimumScale), maximumScale)
    }
}

/**
 * 聚合信号灯类型枚举
 * @author 程序员阿鑫
 */
enum SignalLampKind: String, CaseIterable, Identifiable, Sendable {
    case red
    case yellow
    case green
    case fault

    /**
     * 枚举唯一标识
     */
    var id: String {
        rawValue
    }

    /**
     * 当前灯对应的基础颜色
     */
    var lightColor: LightColor {
        switch self {
        case .red:
            return .red
        case .yellow:
            return .yellow
        case .green:
            return .green
        case .fault:
            return .fault
        }
    }

    /**
     * 展示名称
     */
    var displayName: String {
        switch self {
        case .red:
            return "红灯"
        case .yellow:
            return "黄灯"
        case .green:
            return "绿灯"
        case .fault:
            return "故障"
        }
    }
}

/**
 * 灯效行为枚举，用于描述常亮、慢闪与快闪
 * @author 程序员阿鑫
 */
enum LampBehavior: String, Sendable {
    case off
    case solid
    case pulseSlow
    case pulseFast
}

/**
 * Agent 运行状态枚举
 * @author 程序员阿鑫
 */
enum AgentRuntimeState: String, Sendable {
    case idle
    case running
    case waitingUser
    case failed
    case unavailable
    case disabled

    /**
     * 用于界面展示的状态文案
     */
    var displayText: String {
        switch self {
        case .idle:
            return "空闲"
        case .running:
            return "运行中"
        case .waitingUser:
            return "等待用户"
        case .failed:
            return "异常"
        case .unavailable:
            return "不可用"
        case .disabled:
            return "已关闭"
        }
    }
}

/**
 * Agent 状态快照模型
 * @author 程序员阿鑫
 */
struct AgentStatusSnapshot: Identifiable, Sendable {
    /**
     * 唯一标识，直接使用 Agent 类型
     */
    let id: AgentKind

    /**
     * Agent 类型
     */
    let agent: AgentKind

    /**
     * 状态灯颜色
     */
    let lightColor: LightColor

    /**
     * 运行状态
     */
    let runtimeState: AgentRuntimeState

    /**
     * 标题文案
     */
    let headline: String

    /**
     * 明细文案
     */
    let detail: String

    /**
     * 是否属于接口、令牌或配额故障
     */
    let isFault: Bool

    /**
     * 最近更新时间
     */
    let updatedAt: Date?

    /**
     * 状态来源路径
     */
    let sourcePath: String?

    /**
     * 便捷初始化
     */
    init(agent: AgentKind,
         lightColor: LightColor,
         runtimeState: AgentRuntimeState,
         headline: String,
         detail: String,
         isFault: Bool,
         updatedAt: Date?,
         sourcePath: String?) {
        self.id = agent
        self.agent = agent
        self.lightColor = lightColor
        self.runtimeState = runtimeState
        self.headline = headline
        self.detail = detail
        self.isFault = isFault
        self.updatedAt = updatedAt
        self.sourcePath = sourcePath
    }

    /**
     * 生成禁用状态快照
     */
    static func disabled(for agent: AgentKind) -> AgentStatusSnapshot {
        AgentStatusSnapshot(
            agent: agent,
            lightColor: .gray,
            runtimeState: .disabled,
            headline: "状态灯已关闭",
            detail: "当前不采集\(agent.displayName)状态",
            isFault: false,
            updatedAt: nil,
            sourcePath: nil
        )
    }
}

/**
 * Agent 状态灯本地配置模型
 * @author 程序员阿鑫
 */
struct AgentLightSettings: Codable, Equatable, Sendable {
    /**
     * Claude 状态灯是否启用
     */
    var isClaudeEnabled: Bool = true

    /**
     * Codex 状态灯是否启用
     */
    var isCodexEnabled: Bool = true

    /**
     * 是否启用桌面悬浮窗
     */
    var isFloatingWindowEnabled: Bool = true

    /**
     * 是否启用故障灯
     */
    var isFaultLightEnabled: Bool = true

    /**
     * 是否显示悬浮窗标题
     */
    var isFloatingWindowTitleVisible: Bool = true

    /**
     * 是否显示悬浮窗状态文案
     */
    var isFloatingWindowStateTextVisible: Bool = true

    /**
     * 是否启用语音提醒
     */
    var isVoiceAlertEnabled: Bool = false

    /**
     * 是否启用弹窗提醒
     */
    var isPopupAlertEnabled: Bool = false

    /**
     * 语音提醒音频路径
     */
    var alertAudioPath: String = StatusAlertDefaults.defaultAudioPath

    /**
     * 当前主题模式
     */
    var displayThemeMode: DisplayThemeMode = .system

    /**
     * 轮询频率
     */
    var pollingInterval: PollingInterval = .everySecond

    /**
     * 悬浮窗显示模式
     */
    var floatingWindowDisplayMode: FloatingWindowDisplayMode = .dualPanel

    /**
     * 悬浮窗灯位布局
     */
    var floatingWindowLampLayoutMode: FloatingWindowLampLayoutMode = .vertical

    /**
     * 横向灯位时的悬浮窗排列方式
     */
    var floatingWindowHorizontalPanelArrangement: FloatingWindowHorizontalPanelArrangement = .leftRight

    /**
     * 悬浮窗缩放比例
     */
    var floatingWindowScale: Double = FloatingWindowScaleDefaults.defaultScale

    /**
     * 默认初始化配置
     */
    init() {
    }

    /**
     * 可编码字段
     * @author 程序员阿鑫
     */
    private enum CodingKeys: String, CodingKey {
        case isClaudeEnabled
        case isCodexEnabled
        case isFloatingWindowEnabled
        case isFaultLightEnabled
        case isFloatingWindowTitleVisible
        case isFloatingWindowStateTextVisible
        case isVoiceAlertEnabled
        case isPopupAlertEnabled
        case alertAudioPath
        case displayThemeMode
        case pollingInterval
        case floatingWindowDisplayMode
        case floatingWindowLampLayoutMode
        case floatingWindowHorizontalPanelArrangement
        case floatingWindowScale
    }

    /**
     * 解码配置并为缺失字段回填默认值
     * @param decoder 解码器
     * @throws 解码异常
     */
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 兼容旧版本已保存的配置数据，缺失字段直接回填默认值。
        self.isClaudeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isClaudeEnabled) ?? true
        self.isCodexEnabled = try container.decodeIfPresent(Bool.self, forKey: .isCodexEnabled) ?? true
        self.isFloatingWindowEnabled = try container.decodeIfPresent(Bool.self, forKey: .isFloatingWindowEnabled) ?? true
        self.isFaultLightEnabled = try container.decodeIfPresent(Bool.self, forKey: .isFaultLightEnabled) ?? true
        self.isFloatingWindowTitleVisible = try container.decodeIfPresent(Bool.self, forKey: .isFloatingWindowTitleVisible) ?? true
        self.isFloatingWindowStateTextVisible = try container.decodeIfPresent(Bool.self, forKey: .isFloatingWindowStateTextVisible) ?? true
        self.isVoiceAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .isVoiceAlertEnabled) ?? false
        self.isPopupAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPopupAlertEnabled) ?? false
        self.alertAudioPath = try container.decodeIfPresent(String.self, forKey: .alertAudioPath) ?? StatusAlertDefaults.defaultAudioPath
        self.displayThemeMode = try container.decodeIfPresent(DisplayThemeMode.self, forKey: .displayThemeMode) ?? .system
        self.pollingInterval = try container.decodeIfPresent(PollingInterval.self, forKey: .pollingInterval) ?? .everySecond
        self.floatingWindowDisplayMode = try container.decodeIfPresent(FloatingWindowDisplayMode.self, forKey: .floatingWindowDisplayMode) ?? .dualPanel
        self.floatingWindowLampLayoutMode = try container.decodeIfPresent(FloatingWindowLampLayoutMode.self, forKey: .floatingWindowLampLayoutMode) ?? .vertical
        self.floatingWindowHorizontalPanelArrangement = try container.decodeIfPresent(FloatingWindowHorizontalPanelArrangement.self, forKey: .floatingWindowHorizontalPanelArrangement) ?? .leftRight
        self.floatingWindowScale = FloatingWindowScaleDefaults.clampedScale(
            try container.decodeIfPresent(Double.self, forKey: .floatingWindowScale) ?? FloatingWindowScaleDefaults.defaultScale
        )
    }

    /**
     * 编码配置
     * @param encoder 编码器
     * @throws 编码异常
     */
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // 按字段完整写入配置，确保后续版本可以稳定读取。
        try container.encode(isClaudeEnabled, forKey: .isClaudeEnabled)
        try container.encode(isCodexEnabled, forKey: .isCodexEnabled)
        try container.encode(isFloatingWindowEnabled, forKey: .isFloatingWindowEnabled)
        try container.encode(isFaultLightEnabled, forKey: .isFaultLightEnabled)
        try container.encode(isFloatingWindowTitleVisible, forKey: .isFloatingWindowTitleVisible)
        try container.encode(isFloatingWindowStateTextVisible, forKey: .isFloatingWindowStateTextVisible)
        try container.encode(isVoiceAlertEnabled, forKey: .isVoiceAlertEnabled)
        try container.encode(isPopupAlertEnabled, forKey: .isPopupAlertEnabled)
        try container.encode(alertAudioPath, forKey: .alertAudioPath)
        try container.encode(displayThemeMode, forKey: .displayThemeMode)
        try container.encode(pollingInterval, forKey: .pollingInterval)
        try container.encode(floatingWindowDisplayMode, forKey: .floatingWindowDisplayMode)
        try container.encode(floatingWindowLampLayoutMode, forKey: .floatingWindowLampLayoutMode)
        try container.encode(floatingWindowHorizontalPanelArrangement, forKey: .floatingWindowHorizontalPanelArrangement)
        try container.encode(FloatingWindowScaleDefaults.clampedScale(floatingWindowScale), forKey: .floatingWindowScale)
    }

    /**
     * 判断指定 Agent 是否启用
     */
    func isEnabled(for agent: AgentKind) -> Bool {
        switch agent {
        case .claude:
            return isClaudeEnabled
        case .codex:
            return isCodexEnabled
        }
    }
}
