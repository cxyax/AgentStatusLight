//
//  StatusCenter.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import Foundation
import AppKit
import Combine
import SwiftUI

/**
 * 状态中心，统一管理配置持久化、状态采集、轮询刷新与聚合
 * @author 程序员阿鑫
 */
final class StatusCenter: ObservableObject {

    /**
     * 配置存储键
     */
    private enum Keys {
        static let settings = "agent.light.settings"
    }

    /**
     * 当前配置
     */
    @Published private(set) var settings: AgentLightSettings

    /**
     * Claude 最新快照
     */
    @Published private(set) var claudeSnapshot: AgentStatusSnapshot

    /**
     * Codex 最新快照
     */
    @Published private(set) var codexSnapshot: AgentStatusSnapshot

    /**
     * 聚合四灯状态
     */
    @Published private(set) var signalLampStates: [SignalLampKind: Bool]

    /**
     * 四灯当前灯效行为
     */
    @Published private(set) var signalLampBehaviors: [SignalLampKind: LampBehavior]

    /**
     * Claude 状态采集器
     */
    private let claudeProvider: ClaudeStatusProvider

    /**
     * Codex 状态采集器
     */
    private let codexProvider: CodexStatusProvider

    /**
     * 轮询定时任务
     */
    private var refreshTask: Task<Void, Never>?

    /**
     * 文件系统监听器集合
     */
    private var directoryWatchers: [DirectoryWatcher] = []

    /**
     * UserDefaults 存储
     */
    private let userDefaults: UserDefaults

    /**
     * 桌面悬浮窗控制器
     */
    private let floatingWindowController: FloatingWindowController

    /**
     * 桌面设置窗控制器
     */
    private let settingsWindowController: SettingsWindowController

    /**
     * 状态提醒服务
     */
    private let statusAlertService: StatusAlertService

    /**
     * 是否存在等待落盘的拖拽缩放结果
     */
    private var hasPendingFloatingWindowScalePersistence = false

    /**
     * Claude 状态源根目录
     */
    private let claudeSourceRootDirectory = "~/.claude"

    /**
     * Codex 状态源根目录
     */
    private let codexSourceRootDirectory = "~/.codex"

    /**
     * Claude 状态源根目录
     */
    private let claudeSourceDirectories = [
        "~/.claude/todos",
        "~/.claude/projects"
    ]

    /**
     * Codex 状态源根目录
     */
    private let codexSourceDirectories = [
        "~/.codex",
        "~/.codex/sessions"
    ]

    /**
     * 初始化状态中心
     */
    init(userDefaults: UserDefaults = .standard,
         claudeProvider: ClaudeStatusProvider = ClaudeStatusProvider(),
         codexProvider: CodexStatusProvider = CodexStatusProvider()) {
        self.userDefaults = userDefaults
        self.claudeProvider = claudeProvider
        self.codexProvider = codexProvider
        self.settings = Self.loadSettings(from: userDefaults)
        self.claudeSnapshot = AgentStatusSnapshot.disabled(for: .claude)
        self.codexSnapshot = AgentStatusSnapshot.disabled(for: .codex)
        self.signalLampStates = Dictionary(uniqueKeysWithValues: SignalLampKind.allCases.map { ($0, false) })
        self.signalLampBehaviors = Dictionary(uniqueKeysWithValues: SignalLampKind.allCases.map { ($0, .off) })
        self.floatingWindowController = FloatingWindowController()
        self.settingsWindowController = SettingsWindowController()
        self.statusAlertService = StatusAlertService()

        // 启动后立即根据配置刷新一次状态。
        rebuildWatchers()
        startPolling()
        updateFloatingWindowVisibility()

        Task {
            await refreshAllStatuses()
        }
    }

    deinit {
        // 结束轮询任务，避免对象释放后继续刷新。
        refreshTask?.cancel()
    }

    /**
     * 获取当前启用灯的状态快照
     * @return 快照数组
     */
    var visibleSnapshots: [AgentStatusSnapshot] {
        AgentKind.allCases.compactMap { agent in
            guard settings.isEnabled(for: agent) else {
                return nil
            }

            return snapshot(for: agent)
        }
    }

    /**
     * 聚合后的菜单栏灯色
     */
    var combinedLightColor: LightColor {
        let snapshots = visibleSnapshots.filter { !$0.isFault }
        guard !snapshots.isEmpty else {
            return .gray
        }

        // 使用红 > 黄 > 绿 > 灰的优先级聚合总状态。
        if snapshots.contains(where: { $0.lightColor == .red }) {
            return .red
        }
        if snapshots.contains(where: { $0.lightColor == .yellow }) {
            return .yellow
        }
        if snapshots.contains(where: { $0.lightColor == .green }) {
            return .green
        }
        return .gray
    }

    /**
     * 当前是否点亮故障灯
     */
    var isFaultLampActive: Bool {
        guard settings.isFaultLightEnabled else {
            return false
        }

        return visibleSnapshots.contains(where: { $0.isFault })
    }

    /**
     * 当前监听中的目录列表
     */
    var watchedDirectoryPaths: [String] {
        watchedDirectories().map { path in
            // 使用显式闭包展开路径，避免并发检查将静态方法引用识别为隔离函数值。
            FileSystemUtilities.expandTildePath(path)
        }
    }

    /**
     * 设置 Claude 灯开关
     * @param enabled 是否启用
     */
    func setClaudeEnabled(_ enabled: Bool) {
        settings.isClaudeEnabled = enabled
        handleSettingsChanged()
    }

    /**
     * 设置 Codex 灯开关
     * @param enabled 是否启用
     */
    func setCodexEnabled(_ enabled: Bool) {
        settings.isCodexEnabled = enabled
        handleSettingsChanged()
    }

    /**
     * 设置桌面悬浮窗是否显示
     * @param enabled 是否启用
     */
    func setFloatingWindowEnabled(_ enabled: Bool) {
        settings.isFloatingWindowEnabled = enabled
        handleSettingsChanged()
    }

    /**
     * 设置故障灯是否启用
     * @param enabled 是否启用
     */
    func setFaultLightEnabled(_ enabled: Bool) {
        settings.isFaultLightEnabled = enabled
        handleSettingsChanged()
    }

    /**
     * 设置悬浮窗标题是否显示
     * @param visible 是否显示
     */
    func setFloatingWindowTitleVisible(_ visible: Bool) {
        settings.isFloatingWindowTitleVisible = visible
        handleSettingsChanged()
    }

    /**
     * 设置悬浮窗状态文案是否显示
     * @param visible 是否显示
     */
    func setFloatingWindowStateTextVisible(_ visible: Bool) {
        settings.isFloatingWindowStateTextVisible = visible
        handleSettingsChanged()
    }

    /**
     * 设置语音提醒是否启用
     * @param enabled 是否启用
     */
    func setVoiceAlertEnabled(_ enabled: Bool) {
        settings.isVoiceAlertEnabled = enabled
        handleSettingsChanged()
    }

    /**
     * 设置弹窗提醒是否启用
     * @param enabled 是否启用
     */
    func setPopupAlertEnabled(_ enabled: Bool) {
        settings.isPopupAlertEnabled = enabled

        // 用户开启弹窗提醒时再申请系统通知权限，减少启动打扰。
        if enabled {
            statusAlertService.requestPopupAuthorization()
        }

        handleSettingsChanged()
    }

    /**
     * 设置提醒音频路径
     * @param path 音频路径
     */
    func setAlertAudioPath(_ path: String) {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPath = trimmedPath.isEmpty
        ? StatusAlertDefaults.defaultAudioPath
        : trimmedPath

        settings.alertAudioPath = resolvedPath
        handleSettingsChanged()
    }

    /**
     * 设置主题模式
     * @param mode 主题模式
     */
    func setDisplayThemeMode(_ mode: DisplayThemeMode) {
        settings.displayThemeMode = mode
        handleSettingsChanged()
    }

    /**
     * 设置轮询频率
     * @param interval 轮询频率
     */
    func setPollingInterval(_ interval: PollingInterval) {
        settings.pollingInterval = interval
        handleSettingsChanged()
    }

    /**
     * 设置悬浮窗显示模式
     * @param mode 悬浮窗显示模式
     */
    func setFloatingWindowDisplayMode(_ mode: FloatingWindowDisplayMode) {
        settings.floatingWindowDisplayMode = mode
        handleSettingsChanged()
    }

    /**
     * 设置悬浮窗灯位布局
     * @param mode 灯位布局
     */
    func setFloatingWindowLampLayoutMode(_ mode: FloatingWindowLampLayoutMode) {
        settings.floatingWindowLampLayoutMode = mode
        handleSettingsChanged()
    }

    /**
     * 设置横向灯位时的悬浮窗排列方式
     * @param arrangement 排列方式
     */
    func setFloatingWindowHorizontalPanelArrangement(_ arrangement: FloatingWindowHorizontalPanelArrangement) {
        settings.floatingWindowHorizontalPanelArrangement = arrangement
        handleSettingsChanged()
    }

    /**
     * 设置悬浮窗缩放比例
     * @param scale 缩放比例
     */
    func setFloatingWindowScale(_ scale: Double) {
        let clampedScale = FloatingWindowScaleDefaults.clampedScale(scale)
        let needsPersistence = hasPendingFloatingWindowScalePersistence
            || settings.floatingWindowScale != clampedScale

        guard needsPersistence else {
            return
        }

        // 统一在最终值确认后再持久化与刷新相关界面。
        settings.floatingWindowScale = clampedScale
        hasPendingFloatingWindowScalePersistence = false
        handleFloatingWindowPresentationChanged()
    }

    /**
     * 拖拽过程中临时更新悬浮窗缩放比例
     * @param scale 缩放比例
     */
    func updateFloatingWindowScaleDuringDrag(_ scale: Double) {
        let clampedScale = FloatingWindowScaleDefaults.clampedScale(scale)

        // 拖拽过程中只刷新悬浮窗本身，避免频繁持久化与设置窗口重绘导致卡顿。
        hasPendingFloatingWindowScalePersistence = true
        floatingWindowController.syncPanelSizeImmediately(with: self, scaleOverride: clampedScale)
    }

    /**
     * 重置悬浮窗缩放比例
     */
    func resetFloatingWindowScale() {
        setFloatingWindowScale(FloatingWindowScaleDefaults.defaultScale)
    }

    /**
     * 手动立即刷新
     */
    func refreshNow() {
        Task {
            await refreshAllStatuses()
        }
    }

    /**
     * 打开桌面端设置窗口
     */
    func openSettingsWindow() {
        settingsWindowController.show(statusCenter: self)
    }

    /**
     * 退出应用
     */
    func quitApplication() {
        NSApplication.shared.terminate(nil)
    }

    /**
     * 重置为默认配置
     */
    func resetSettings() {
        settings = AgentLightSettings()
        handleSettingsChanged()
    }

    /**
     * 获取指定 Agent 的最新快照
     * @param agent Agent 类型
     * @return 状态快照
     */
    func latestSnapshot(for agent: AgentKind) -> AgentStatusSnapshot {
        snapshot(for: agent)
    }

    /**
     * 打开指定 Agent 的状态源目录
     * @param agent Agent 类型
     */
    func openSourceDirectories(for agent: AgentKind) {
        let rootDirectory = sourceRootDirectory(for: agent)

        // 统一打开各自的状态源根目录，避免一次弹出多个 Finder 窗口。
        if FileSystemUtilities.fileExists(at: rootDirectory) {
            openInFinder(path: rootDirectory)
        }
    }

    /**
     * 在 Finder 中定位当前状态源文件
     * @param agent Agent 类型
     */
    func revealSourceFile(for agent: AgentKind) {
        let snapshot = latestSnapshot(for: agent)
        guard let sourcePath = snapshot.sourcePath else {
            return
        }

        // 优先直接定位状态源文件，帮助核对采集结果是否准确。
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: sourcePath)])
    }

    /**
     * 根据 Agent 获取快照
     * @param agent Agent类型
     * @return 状态快照
     */
    private func snapshot(for agent: AgentKind) -> AgentStatusSnapshot {
        switch agent {
        case .claude:
            return claudeSnapshot
        case .codex:
            return codexSnapshot
        }
    }

    /**
     * 配置变化后的统一处理
     */
    private func handleSettingsChanged() {
        persistSettings()
        startPolling()
        rebuildWatchers()
        updateFloatingWindowVisibility()

        // 关闭灯时立即回填禁用状态，避免旧数据残留在界面上。
        if !settings.isClaudeEnabled {
            claudeSnapshot = .disabled(for: .claude)
        }
        if !settings.isCodexEnabled {
            codexSnapshot = .disabled(for: .codex)
        }
        signalLampStates = buildSignalLampStates()
        signalLampBehaviors = buildSignalLampBehaviors()
        floatingWindowController.updateContent(statusCenter: self)
        settingsWindowController.updateContent(statusCenter: self)

        Task {
            await refreshAllStatuses()
        }
    }

    /**
     * 悬浮窗外观设置变化后的轻量处理
     */
    private func handleFloatingWindowPresentationChanged() {
        persistSettings()
        updateFloatingWindowVisibility()
        floatingWindowController.updateContent(statusCenter: self)
        settingsWindowController.updateContent(statusCenter: self)
    }

    /**
     * 持久化配置
     */
    private func persistSettings() {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        // 将最新开关配置保存到用户默认存储。
        userDefaults.set(data, forKey: Keys.settings)
    }

    /**
     * 从 UserDefaults 加载配置
     * @param userDefaults 存储
     * @return 配置对象
     */
    private static func loadSettings(from userDefaults: UserDefaults) -> AgentLightSettings {
        guard
            let data = userDefaults.data(forKey: Keys.settings),
            let settings = try? JSONDecoder().decode(AgentLightSettings.self, from: data)
        else {
            return AgentLightSettings()
        }

        return settings
    }

    /**
     * 启动轮询任务
     */
    private func startPolling() {
        refreshTask?.cancel()

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }

                // 按用户配置的频率轮询，为监听失效场景提供兜底刷新。
                try? await Task.sleep(for: .seconds(self.settings.pollingInterval.seconds))
                await self.refreshAllStatuses()
            }
        }
    }

    /**
     * 重建目录监听器
     */
    private func rebuildWatchers() {
        directoryWatchers.removeAll()

        let watchDirectories = watchedDirectories()

        // 仅监听当前启用灯对应的数据目录，减少无效刷新。
        directoryWatchers = watchDirectories.compactMap { path in
            let expandedPath = FileSystemUtilities.expandTildePath(path)
            return DirectoryWatcher(directoryURL: URL(fileURLWithPath: expandedPath)) { [weak self] in
                Task { [weak self] in
                    await self?.refreshAllStatuses()
                }
            }
        }
    }

    /**
     * 获取需要监听的目录列表
     * @return 目录路径数组
     */
    private func watchedDirectories() -> [String] {
        var directories: [String] = []

        if settings.isClaudeEnabled {
            directories.append(contentsOf: claudeSourceDirectories)
        }

        if settings.isCodexEnabled {
            directories.append(contentsOf: codexSourceDirectories)
        }

        return directories
    }

    /**
     * 获取指定 Agent 的状态源根目录
     * @param agent Agent 类型
     * @return 根目录路径
     */
    private func sourceRootDirectory(for agent: AgentKind) -> String {
        switch agent {
        case .claude:
            return claudeSourceRootDirectory
        case .codex:
            return codexSourceRootDirectory
        }
    }

    /**
     * 在 Finder 中打开指定路径
     * @param path 文件或目录路径
     */
    private func openInFinder(path: String) {
        let expandedPath = FileSystemUtilities.expandTildePath(path)
        NSWorkspace.shared.open(URL(fileURLWithPath: expandedPath))
    }

    /**
     * 刷新全部启用灯的状态
     */
    private func refreshAllStatuses() async {
        async let claudeResult = fetchSnapshotIfEnabled(agent: .claude)
        async let codexResult = fetchSnapshotIfEnabled(agent: .codex)

        let claudeSnapshot = await claudeResult
        let codexSnapshot = await codexResult
        let previousSnapshots = await MainActor.run { self.visibleSnapshots }

        // 将刷新结果统一切回主线程后再回写到可观察状态。
        await MainActor.run {
            self.claudeSnapshot = claudeSnapshot
            self.codexSnapshot = codexSnapshot
            self.signalLampStates = self.buildSignalLampStates()
            self.signalLampBehaviors = self.buildSignalLampBehaviors()
            self.floatingWindowController.updateContent(statusCenter: self)
            self.settingsWindowController.updateContent(statusCenter: self)

            // 状态发生实质变化后再触发提醒，避免重复打扰。
            self.statusAlertService.notifyIfNeeded(
                previousSnapshots: previousSnapshots,
                currentSnapshots: self.visibleSnapshots,
                settings: self.settings
            )
        }
    }

    /**
     * 构建四灯聚合状态
     * @return 四灯状态字典
     */
    private func buildSignalLampStates() -> [SignalLampKind: Bool] {
        var states = Dictionary(uniqueKeysWithValues: SignalLampKind.allCases.map { ($0, false) })
        let enabledSnapshots = visibleSnapshots

        // 故障灯独立展示接口、令牌和配额类问题。
        if isFaultLampActive {
            states[.fault] = true
            return states
        }

        switch combinedLightColor {
        case .red:
            states[.red] = true
        case .yellow:
            states[.yellow] = true
        case .green:
            states[.green] = true
        case .gray, .fault:
            break
        }

        // 只要有启用灯，就至少保留一盏灰态保底灯，避免全部熄灭看不出应用在工作。
        if !enabledSnapshots.isEmpty && !states.values.contains(true) {
            states[.green] = true
        }

        return states
    }

    /**
     * 构建四灯灯效行为
     * @return 灯效行为字典
     */
    private func buildSignalLampBehaviors() -> [SignalLampKind: LampBehavior] {
        var behaviors = Dictionary(uniqueKeysWithValues: SignalLampKind.allCases.map { ($0, LampBehavior.off) })

        if isFaultLampActive {
            behaviors[.fault] = .pulseFast
            return behaviors
        }

        let activeSnapshots = visibleSnapshots.filter { !$0.isFault }

        // 红灯：异常常亮；若当前所有可见灯都不可用，则保持熄灭。
        if combinedLightColor == .red {
            behaviors[.red] = activeSnapshots.contains(where: { $0.runtimeState == .failed }) ? .solid : .pulseFast
        }

        // 黄灯：运行中慢闪；等待用户常亮。
        if combinedLightColor == .yellow {
            if activeSnapshots.contains(where: { $0.runtimeState == .running }) {
                behaviors[.yellow] = .pulseSlow
            } else {
                behaviors[.yellow] = .solid
            }
        }

        // 绿灯：空闲或成功常亮。
        if combinedLightColor == .green {
            behaviors[.green] = .solid
        }

        // 当启用灯存在但状态未明确时，让绿灯保底常亮，避免四灯全灭。
        if !visibleSnapshots.isEmpty && !behaviors.values.contains(where: { $0 != .off }) {
            behaviors[.green] = .solid
        }

        return behaviors
    }

    /**
     * 获取灯规则说明列表
     * @return 规则文案数组
     */
    func lampRuleDescriptions() -> [String] {
        [
            "红灯常亮：最近一次任务明确失败或命令执行异常，需要处理。",
            "红灯快闪：保留为更严重的异常预警入口，当前主要由聚合异常兜底。",
            "黄灯常亮：当前在等待用户输入、确认或人工操作。",
            "黄灯慢闪：Claude 或 Codex 正在运行、输出或处理中。",
            "绿灯常亮：当前空闲，或最近一次任务已正常结束。",
            "故障灯快闪：API请求失败、令牌失效、额度不足、模型负载过高等外部故障。"
        ]
    }

    /**
     * 同步悬浮窗显示状态
     */
    private func updateFloatingWindowVisibility() {
        if settings.isFloatingWindowEnabled {
            floatingWindowController.show(statusCenter: self)
        } else {
            floatingWindowController.hide()
        }
    }

    /**
     * 仅在灯启用时采集状态
     * @param agent Agent类型
     * @return 状态快照
     */
    private func fetchSnapshotIfEnabled(agent: AgentKind) async -> AgentStatusSnapshot {
        guard settings.isEnabled(for: agent) else {
            return .disabled(for: agent)
        }

        switch agent {
        case .claude:
            return await claudeProvider.fetchStatus()
        case .codex:
            return await codexProvider.fetchStatus()
        }
    }
}
