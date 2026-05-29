//
//  StatusPanelView.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import SwiftUI

/**
 * 菜单栏展开后的主状态面板视图
 * @author 程序员阿鑫
 */
struct StatusPanelView: View {

    /**
     * 面板呈现样式
     */
    enum PresentationStyle {
        case menuBar
        case desktopSettings
    }

    /**
     * 状态中心
     */
    @ObservedObject var statusCenter: StatusCenter

    /**
     * 当前呈现样式
     */
    let presentationStyle: PresentationStyle

    /**
     * 当前系统颜色方案
     */
    @Environment(\.colorScheme) private var colorScheme

    /**
     * 当前面板使用的主题色板
     */
    private var palette: SharedTheme.Palette {
        // 根据主题设置与系统外观解析当前面板配色。
        SharedTheme.palette(for: statusCenter.settings.displayThemeMode, colorScheme: colorScheme)
    }

    /**
     * 当前实际生效的颜色方案
     */
    private var resolvedColorScheme: ColorScheme {
        SharedTheme.resolveColorScheme(for: statusCenter.settings.displayThemeMode, colorScheme: colorScheme)
    }

    var body: some View {
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                statusSection
                settingsSection
                diagnosticsSection
                rulesSection
                footerSection
            }
            .padding(18)
        }
        .frame(width: presentationStyle == .menuBar ? 396 : 448)
        .foregroundStyle(palette.titleColor)
        .background(
            LinearGradient(
                colors: [
                    palette.backgroundTop,
                    palette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    /**
     * 头部区域
     */
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(SignalLampKind.allCases) { lamp in
                    let isActive = statusCenter.signalLampStates[lamp] ?? false

                    if lamp == .fault {
                        Capsule(style: .continuous)
                            .fill(isActive
                                  ? AnyShapeStyle(lamp.lightColor.adaptiveColor(for: resolvedColorScheme))
                                  : AnyShapeStyle(lamp.lightColor.adaptiveColor(for: resolvedColorScheme).opacity(0.34)))
                            .frame(width: 10, height: 5)
                    } else {
                        Circle()
                            .fill(isActive
                                  ? AnyShapeStyle(lamp.lightColor.adaptiveColor(for: resolvedColorScheme))
                                  : AnyShapeStyle(lamp.lightColor.adaptiveColor(for: resolvedColorScheme).opacity(0.34)))
                            .frame(width: 18, height: 18)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Agent Status Light")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.titleColor)
                Text("Claude、Codex 与故障灯聚合状态")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.secondaryTextColor)
            }

            Spacer(minLength: 0)

            if presentationStyle == .menuBar {
                Button("设置") {
                    // 从菜单栏快速打开桌面设置窗。
                    statusCenter.openSettingsWindow()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryTextColor)
            }
        }
    }

    /**
     * 状态灯展示区域
     */
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("状态区")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryTextColor)

            if statusCenter.visibleSnapshots.isEmpty {
                Text("当前未启用任何状态灯")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.panelFill)
                    )
            } else {
                ForEach(statusCenter.visibleSnapshots) { snapshot in
                    StatusLightRowView(snapshot: snapshot,
                                       palette: palette,
                                       resolvedColorScheme: resolvedColorScheme)
                }
            }
        }
    }

    /**
     * 开关配置区域
     */
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("配置区")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryTextColor)

            Toggle(
                "启用Claude状态灯",
                isOn: Binding(
                    get: { statusCenter.settings.isClaudeEnabled },
                    set: { statusCenter.setClaudeEnabled($0) }
                )
            )
            .toggleStyle(.switch)

            Toggle(
                "启用Codex状态灯",
                isOn: Binding(
                    get: { statusCenter.settings.isCodexEnabled },
                    set: { statusCenter.setCodexEnabled($0) }
                )
            )
            .toggleStyle(.switch)

            Toggle(
                "显示桌面悬浮窗",
                isOn: Binding(
                    get: { statusCenter.settings.isFloatingWindowEnabled },
                    set: { statusCenter.setFloatingWindowEnabled($0) }
                )
            )
            .toggleStyle(.switch)

            Toggle(
                "启用故障灯",
                isOn: Binding(
                    get: { statusCenter.settings.isFaultLightEnabled },
                    set: { statusCenter.setFaultLightEnabled($0) }
                )
            )
            .toggleStyle(.switch)

            Toggle(
                "显示悬浮窗标题",
                isOn: Binding(
                    get: { statusCenter.settings.isFloatingWindowTitleVisible },
                    set: { statusCenter.setFloatingWindowTitleVisible($0) }
                )
            )
            .toggleStyle(.switch)

            Toggle(
                "显示悬浮窗状态文案",
                isOn: Binding(
                    get: { statusCenter.settings.isFloatingWindowStateTextVisible },
                    set: { statusCenter.setFloatingWindowStateTextVisible($0) }
                )
            )
            .toggleStyle(.switch)

            themeModeSelector
            pollingIntervalSelector
            floatingWindowModeSelector
            floatingWindowLayoutSelector
            if statusCenter.settings.floatingWindowLampLayoutMode == .horizontal {
                floatingWindowArrangementSelector
            }
            floatingWindowScaleControl

            voiceAlertToggle
            popupAlertToggle
            alertAudioPathField
            alertAudioActionRow
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .tint(palette.titleColor)
    }

    /**
     * 语音提醒开关
     */
    private var voiceAlertToggle: some View {
        Toggle(
            "启用语音提醒",
            isOn: Binding(
                get: { statusCenter.settings.isVoiceAlertEnabled },
                set: { statusCenter.setVoiceAlertEnabled($0) }
            )
        )
        .toggleStyle(.switch)
    }

    /**
     * 弹窗提醒开关
     */
    private var popupAlertToggle: some View {
        Toggle(
            "启用弹窗提醒",
            isOn: Binding(
                get: { statusCenter.settings.isPopupAlertEnabled },
                set: { statusCenter.setPopupAlertEnabled($0) }
            )
        )
        .toggleStyle(.switch)
    }

    /**
     * 提醒音频路径输入框
     */
    private var alertAudioPathField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("提醒音频路径")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryTextColor)

            TextField(
                "请输入自定义音频路径",
                text: Binding(
                    get: {
                        statusCenter.settings.alertAudioPath == StatusAlertDefaults.defaultAudioPath
                        ? ""
                        : statusCenter.settings.alertAudioPath
                    },
                    set: { statusCenter.setAlertAudioPath($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
        }
    }

    /**
     * 提醒音频操作区
     */
    private var alertAudioActionRow: some View {
        HStack(spacing: 10) {
            Button("恢复默认音频") {
                // 快速恢复预设提醒音频路径。
                statusCenter.setAlertAudioPath(StatusAlertDefaults.defaultAudioPath)
            }
            .buttonStyle(.bordered)

            Text(StatusAlertDefaults.defaultAudioDisplayName)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(palette.secondaryTextColor)
                .lineLimit(2)
        }
    }

    /**
     * 自绘主题模式选择器，避免深色模式下系统分段控件未选中文字过暗
     */
    private var themeModeSelector: some View {
        segmentedSelector(
            title: "主题模式",
            content: {
                ForEach(DisplayThemeMode.allCases) { mode in
                    themeModeButton(for: mode)
                }
            }
        )
    }

    /**
     * 生成单个主题模式按钮
     * @param mode 主题模式
     * @return 按钮视图
     */
    private func themeModeButton(for mode: DisplayThemeMode) -> some View {
        let isSelected = statusCenter.settings.displayThemeMode == mode

        return Button {
            // 点击后立即切换主题模式。
            statusCenter.setDisplayThemeMode(mode)
        } label: {
            Text(mode.displayName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? selectedThemeModeTextColor : palette.titleColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? selectedThemeModeBackgroundColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    /**
     * 当前选中主题按钮的文字颜色
     */
    private var selectedThemeModeTextColor: Color {
        SharedTheme.resolveColorScheme(for: statusCenter.settings.displayThemeMode, colorScheme: colorScheme) == .dark
        ? Color.white.opacity(0.96)
        : Color.black.opacity(0.88)
    }

    /**
     * 当前选中主题按钮的背景色
     */
    private var selectedThemeModeBackgroundColor: Color {
        SharedTheme.resolveColorScheme(for: statusCenter.settings.displayThemeMode, colorScheme: colorScheme) == .dark
        ? Color.white.opacity(0.14)
        : Color.black.opacity(0.08)
    }

    /**
     * 轮询频率选择器
     */
    private var pollingIntervalSelector: some View {
        segmentedSelector(
            title: "轮询频率",
            content: {
                ForEach(PollingInterval.allCases) { interval in
                    pollingIntervalButton(for: interval)
                }
            }
        )
    }

    /**
     * 悬浮窗模式选择器
     */
    private var floatingWindowModeSelector: some View {
        segmentedSelector(
            title: "悬浮窗模式",
            content: {
                ForEach(FloatingWindowDisplayMode.allCases) { mode in
                    floatingWindowModeButton(for: mode)
                }
            }
        )
    }

    /**
     * 悬浮窗方向选择器
     */
    private var floatingWindowLayoutSelector: some View {
        segmentedSelector(
            title: "悬浮窗方向",
            content: {
                ForEach(FloatingWindowLampLayoutMode.allCases) { mode in
                    floatingWindowLayoutButton(for: mode)
                }
            }
        )
    }

    /**
     * 横向灯位排列方式选择器
     */
    private var floatingWindowArrangementSelector: some View {
        segmentedSelector(
            title: "横向排列",
            content: {
                ForEach(FloatingWindowHorizontalPanelArrangement.allCases) { arrangement in
                    floatingWindowArrangementButton(for: arrangement)
                }
            }
        )
    }

    /**
     * 悬浮窗大小控制区
     */
    private var floatingWindowScaleControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("悬浮窗大小")
                    .foregroundStyle(palette.titleColor)

                Spacer(minLength: 0)

                Text("\(Int(statusCenter.settings.floatingWindowScale * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryTextColor)
            }

            Slider(
                value: Binding(
                    get: { statusCenter.settings.floatingWindowScale },
                    set: { statusCenter.setFloatingWindowScale($0) }
                ),
                in: FloatingWindowScaleDefaults.minimumScale...FloatingWindowScaleDefaults.maximumScale,
                step: FloatingWindowScaleDefaults.step
            )

            HStack(spacing: 10) {
                Button("恢复默认大小") {
                    // 快速恢复默认缩放，避免拖拽后不好回到初始值。
                    statusCenter.resetFloatingWindowScale()
                }
                .buttonStyle(.bordered)
                .disabled(statusCenter.settings.floatingWindowScale == FloatingWindowScaleDefaults.defaultScale)

                Text("支持拖拽悬浮窗右下角")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.secondaryTextColor)
            }
        }
    }

    /**
     * 生成单个轮询频率按钮
     * @param interval 轮询频率
     * @return 按钮视图
     */
    private func pollingIntervalButton(for interval: PollingInterval) -> some View {
        let isSelected = statusCenter.settings.pollingInterval == interval

        return Button {
            // 点击后立即切换轮询兜底频率。
            statusCenter.setPollingInterval(interval)
        } label: {
            Text(interval.displayName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? selectedThemeModeTextColor : palette.titleColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? selectedThemeModeBackgroundColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    /**
     * 生成单个悬浮窗模式按钮
     * @param mode 悬浮窗模式
     * @return 按钮视图
     */
    private func floatingWindowModeButton(for mode: FloatingWindowDisplayMode) -> some View {
        let isSelected = statusCenter.settings.floatingWindowDisplayMode == mode

        return Button {
            // 点击后立即切换悬浮窗展示模式。
            statusCenter.setFloatingWindowDisplayMode(mode)
        } label: {
            Text(mode.displayName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? selectedThemeModeTextColor : palette.titleColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? selectedThemeModeBackgroundColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    /**
     * 生成单个悬浮窗方向按钮
     * @param mode 悬浮窗方向
     * @return 按钮视图
     */
    private func floatingWindowLayoutButton(for mode: FloatingWindowLampLayoutMode) -> some View {
        let isSelected = statusCenter.settings.floatingWindowLampLayoutMode == mode

        return Button {
            // 点击后立即切换悬浮窗灯位方向。
            statusCenter.setFloatingWindowLampLayoutMode(mode)
        } label: {
            Text(mode.displayName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? selectedThemeModeTextColor : palette.titleColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? selectedThemeModeBackgroundColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    /**
     * 生成单个横向排列方式按钮
     * @param arrangement 排列方式
     * @return 按钮视图
     */
    private func floatingWindowArrangementButton(for arrangement: FloatingWindowHorizontalPanelArrangement) -> some View {
        let isSelected = statusCenter.settings.floatingWindowHorizontalPanelArrangement == arrangement

        return Button {
            // 点击后立即切换横向灯位的面板排列方式。
            statusCenter.setFloatingWindowHorizontalPanelArrangement(arrangement)
        } label: {
            Text(arrangement.displayName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? selectedThemeModeTextColor : palette.titleColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? selectedThemeModeBackgroundColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    /**
     * 统一的分段选择器容器
     * @param title 标题
     * @param content 内容
     * @return 视图
     */
    private func segmentedSelector<Content: View>(title: String,
                                                  @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundStyle(palette.titleColor)

            HStack(spacing: 4) {
                content()
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.panelFill)
            )
        }
    }

    /**
     * 数据源诊断区域
     */
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("诊断区")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryTextColor)

            diagnosticsCard(for: .claude)
            diagnosticsCard(for: .codex)
            watchedDirectoriesCard
        }
    }

    /**
     * 生成单个 Agent 的诊断卡片
     * @param agent Agent 类型
     * @return 视图
     */
    private func diagnosticsCard(for agent: AgentKind) -> some View {
        let snapshot = statusCenter.latestSnapshot(for: agent)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(agent.displayName)状态源")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.titleColor)

                Spacer(minLength: 0)

                Text(snapshot.runtimeState.displayText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(snapshot.lightColor.adaptiveColor(for: resolvedColorScheme))
            }

            diagnosticLine(title: "状态摘要", value: snapshot.headline)
            diagnosticLine(title: "最近刷新", value: StatusFormatting.relativeTimeText(for: snapshot.updatedAt))
            diagnosticLine(title: "状态文件", value: snapshot.sourcePath ?? "暂无可用状态源")

            HStack(spacing: 10) {
                Button("打开数据目录") {
                    // 打开当前 Agent 的状态源根目录。
                    statusCenter.openSourceDirectories(for: agent)
                }
                .buttonStyle(.bordered)

                Button("定位状态文件") {
                    // 直接在 Finder 中定位当前生效的状态文件。
                    statusCenter.revealSourceFile(for: agent)
                }
                .buttonStyle(.bordered)
                .disabled(snapshot.sourcePath == nil)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.panelFill)
        )
    }

    /**
     * 监听目录信息卡片
     */
    private var watchedDirectoriesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当前监听目录")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.titleColor)

            if statusCenter.watchedDirectoryPaths.isEmpty {
                Text("当前没有启用任何目录监听")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.secondaryTextColor)
            } else {
                ForEach(statusCenter.watchedDirectoryPaths, id: \.self) { path in
                    Text(path)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(palette.secondaryTextColor)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.panelFill)
        )
    }

    /**
     * 单行诊断信息
     * @param title 标题
     * @param value 值
     * @return 视图
     */
    private func diagnosticLine(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryTextColor)

            Text(value)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(palette.titleColor)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /**
     * 灯规则说明区域
     */
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("亮灯规则")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryTextColor)

            ForEach(statusCenter.lampRuleDescriptions(), id: \.self) { rule in
                Text(rule)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.panelFill)
        )
    }

    /**
     * 底部操作区域
     */
    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button("立即刷新") {
                    // 点击后主动拉取一次最新状态。
                    statusCenter.refreshNow()
                }
                .buttonStyle(.borderedProminent)

                Button("恢复默认") {
                    // 一键恢复为默认配置，方便排查设置问题。
                    statusCenter.resetSettings()
                }
                .buttonStyle(.bordered)

                if presentationStyle == .desktopSettings {
                    Button {
                        // 退出菜单栏应用。
                        statusCenter.quitApplication()
                    } label: {
                        Text("退出")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(footerSecondaryButtonTextColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(palette.panelFill)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("说明：目录监听负责实时刷新，轮询频率只作为兜底；若状态异常，可先用“定位状态文件”核对采集源。")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(palette.secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /**
     * 深浅主题下次级按钮的文字颜色
     */
    private var footerSecondaryButtonTextColor: Color {
        SharedTheme.resolveColorScheme(for: statusCenter.settings.displayThemeMode, colorScheme: colorScheme) == .dark
        ? Color.white.opacity(0.96)
        : Color.black.opacity(0.82)
    }
}
