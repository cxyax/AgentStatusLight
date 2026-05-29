//
//  SettingsWindowView.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/28.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/**
 * 设置窗口分类枚举，用于切换不同设置与信息区域
 * @author 程序员阿鑫
 */
private enum SettingsCategoryTab: String, CaseIterable, Identifiable {
    case general
    case runtime
    case diagnostics
    case about

    /**
     * 唯一标识
     */
    var id: String {
        rawValue
    }

    /**
     * 分类展示名称
     */
    var displayName: String {
        switch self {
        case .general:
            return "常规设置"
        case .runtime:
            return "运行状态"
        case .diagnostics:
            return "诊断排查"
        case .about:
            return "关于我们"
        }
    }
}

/**
 * 独立设置窗口视图，负责以标准窗体样式承载应用配置与诊断信息
 * @author 程序员阿鑫
 */
struct SettingsWindowView: View {

    /**
     * 关于我们中的开发者微信
     */
    private let developerWeChat = "cxyax_"

    /**
     * 关于我们中的联系邮箱
     */
    private let developerEmail = "gaoxin1153@163.com"

    /**
     * 状态中心
     */
    @ObservedObject var statusCenter: StatusCenter

    /**
     * 当前系统颜色方案
     */
    @Environment(\.colorScheme) private var colorScheme

    /**
     * 当前选中的设置分类
     */
    @AppStorage("settings.window.selected.category") private var selectedCategoryRawValue = SettingsCategoryTab.general.rawValue

    /**
     * 当前实际生效的颜色方案
     */
    private var resolvedColorScheme: ColorScheme {
        SharedTheme.resolveColorScheme(for: statusCenter.settings.displayThemeMode, colorScheme: colorScheme)
    }

    /**
     * 当前分类绑定
     */
    private var selectedCategoryBinding: Binding<SettingsCategoryTab> {
        Binding(
            get: {
                SettingsCategoryTab(rawValue: selectedCategoryRawValue) ?? .general
            },
            set: { selectedCategoryRawValue = $0.rawValue }
        )
    }

    /**
     * 当前选中的分类
     */
    private var selectedCategory: SettingsCategoryTab {
        SettingsCategoryTab(rawValue: selectedCategoryRawValue) ?? .general
    }

    /**
     * 当前应用展示名称
     */
    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "Agent Status Light"
    }

    /**
     * 当前应用版本文案
     */
    private var appVersionText: String {
        let marketingVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(marketingVersion) (\(buildVersion))"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            currentCategoryContent
                .formStyle(.grouped)

            Divider()

            footerSection
        }
        .frame(minWidth: 820, minHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(resolvedColorScheme)
    }

    /**
     * 顶部说明与分类切换区域
     */
    private var headerSection: some View {
        HStack(spacing: 0) {
            Picker("", selection: selectedCategoryBinding) {
                ForEach(SettingsCategoryTab.allCases) { category in
                    Text(category.displayName).tag(category)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /**
     * 当前分类对应的内容区域
     */
    private var currentCategoryContent: some View {
        Form {
            switch selectedCategory {
            case .general:
                generalSections
            case .runtime:
                runtimeSections
            case .diagnostics:
                diagnosticsSections
            case .about:
                aboutSections
            }
        }
    }

    /**
     * 常规设置分类内容
     */
    @ViewBuilder
    private var generalSections: some View {
        Section("状态灯") {
            Toggle("启用Claude状态灯", isOn: claudeEnabledBinding)
            Toggle("启用Codex状态灯", isOn: codexEnabledBinding)
            Toggle("显示桌面悬浮窗", isOn: floatingWindowEnabledBinding)
            Toggle("启用故障灯", isOn: faultLightEnabledBinding)
            Toggle("显示悬浮窗标题", isOn: floatingWindowTitleVisibleBinding)
            Toggle("显示悬浮窗状态文案", isOn: floatingWindowStateTextVisibleBinding)
        }

        Section("外观与刷新") {
            Picker("主题模式", selection: displayThemeModeBinding) {
                ForEach(DisplayThemeMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("轮询频率", selection: pollingIntervalBinding) {
                ForEach(PollingInterval.allCases) { interval in
                    Text(interval.displayName).tag(interval)
                }
            }
            .pickerStyle(.segmented)

            Picker("悬浮窗模式", selection: floatingWindowDisplayModeBinding) {
                ForEach(FloatingWindowDisplayMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("悬浮窗方向", selection: floatingWindowLampLayoutModeBinding) {
                ForEach(FloatingWindowLampLayoutMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if statusCenter.settings.floatingWindowLampLayoutMode == .horizontal {
                Picker("横向排列方式", selection: floatingWindowHorizontalPanelArrangementBinding) {
                    ForEach(FloatingWindowHorizontalPanelArrangement.allCases) { arrangement in
                        Text(arrangement.displayName).tag(arrangement)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("悬浮窗大小")
                    Spacer(minLength: 0)
                    Text(floatingWindowScalePercentText)
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: floatingWindowScaleBinding,
                    in: FloatingWindowScaleDefaults.minimumScale...FloatingWindowScaleDefaults.maximumScale,
                    step: FloatingWindowScaleDefaults.step
                )

                HStack(spacing: 10) {
                    Button("恢复默认大小") {
                        // 一键恢复默认缩放，便于快速回到初始尺寸。
                        statusCenter.resetFloatingWindowScale()
                    }
                    .disabled(statusCenter.settings.floatingWindowScale == FloatingWindowScaleDefaults.defaultScale)

                    Text("也可直接拖拽悬浮窗右下角调整")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }

        Section("提醒设置") {
            Toggle("启用语音提醒", isOn: voiceAlertEnabledBinding)
            Toggle("启用弹窗提醒", isOn: popupAlertEnabledBinding)

            LabeledContent("提醒音频路径") {
                TextField("请输入自定义音频路径", text: alertAudioPathBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 360)
            }

            HStack(spacing: 10) {
                Button("选择音频文件") {
                    // 打开系统文件面板，允许用户选择自定义提醒音频。
                    selectAlertAudioFile()
                }

                Button("恢复默认音频") {
                    // 一键恢复到预设提醒音频路径，方便快速回退。
                    statusCenter.setAlertAudioPath(StatusAlertDefaults.defaultAudioPath)
                }
                .disabled(statusCenter.settings.alertAudioPath == StatusAlertDefaults.defaultAudioPath)

                Text(StatusAlertDefaults.defaultAudioDisplayName)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /**
     * 运行状态分类内容
     */
    @ViewBuilder
    private var runtimeSections: some View {
        Section("当前运行状态") {
            ForEach(AgentKind.allCases) { agent in
                runtimeRow(for: agent)
            }
        }
    }

    /**
     * 诊断排查分类内容
     */
    @ViewBuilder
    private var diagnosticsSections: some View {
        Section("诊断与数据源") {
            watchedDirectoriesView

            ForEach(AgentKind.allCases) { agent in
                diagnosticsActions(for: agent)
            }
        }
    }

    /**
     * 关于我们分类内容
     */
    @ViewBuilder
    private var aboutSections: some View {
        Section("关于我们") {
            aboutCard
        }
    }

    /**
     * 作者与产品信息卡片
     */
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            appIdentityCard

            Divider()

            authorInfoCard
        }
        .padding(.vertical, 12)
    }

    /**
     * 作者信息卡片
     */
    private var authorInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("作者信息")
                .font(.system(size: 14, weight: .bold, design: .rounded))

            aboutLine(title: "开发者", value: "程序员阿鑫")
            aboutLine(title: "微信", value: developerWeChat)
            aboutLine(title: "邮箱", value: developerEmail)
            aboutLine(title: "说明", value: "如果状态显示不准确，可以先点“立即刷新”，再用“定位状态文件”核对采集源。")

            HStack(spacing: 10) {
                aboutActionButton(title: "复制微信", systemImage: "doc.on.doc") {
                    copyToPasteboard(developerWeChat)
                }

                aboutActionButton(title: "复制邮箱", systemImage: "doc.on.doc.fill") {
                    copyToPasteboard(developerEmail)
                }

                aboutActionButton(title: "发邮件", systemImage: "envelope.fill") {
                    openMailComposer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /**
     * 底部操作区域
     */
    private var footerSection: some View {
        HStack(alignment: .bottom, spacing: 28) {
            VStack(alignment: .leading, spacing: 4) {
                Text("设置会自动保存")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))

                Text("如果状态显示不准确，可以先点“立即刷新”，再用“定位状态文件”核对采集源。")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("恢复默认") {
                    // 一键恢复默认设置，便于快速回到初始状态。
                    statusCenter.resetSettings()
                }
                .buttonStyle(.bordered)

                Button("立即刷新") {
                    // 主动触发一次状态采集，方便用户即时核对结果。
                    statusCenter.refreshNow()
                }
                .buttonStyle(.borderedProminent)

                Button("退出应用", role: .destructive) {
                    // 从设置窗口直接退出应用，保持和普通程序一致的收口方式。
                    statusCenter.quitApplication()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.85)
        }
    }

    /**
     * 关于我们信息单行展示
     * @param title 标题
     * @param value 内容
     * @return 视图
     */
    private func aboutLine(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /**
     * 应用品牌信息卡片
     */
    private var appIdentityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(appDisplayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(appVersionText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Text("一款面向 Claude 与 Codex 使用场景的桌面状态灯工具，用于快速感知 Agent 当前是否在运行、等待、空闲或异常。")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        )
    }

    /**
     * 关于我们操作按钮
     * @param title 按钮标题
     * @param systemImage 系统图标
     * @param action 点击动作
     * @return 视图
     */
    private func aboutActionButton(title: String,
                                   systemImage: String,
                                   action: @escaping () -> Void) -> some View {
        Button {
            // 点击后立即执行关于我们中的联系动作。
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .buttonStyle(.bordered)
    }

    /**
     * 复制文本到系统剪贴板
     * @param text 待复制文本
     */
    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general

        // 先清空旧内容，避免粘贴板里残留过时数据。
        pasteboard.clearContents()

        // 将当前文本写入系统剪贴板，方便用户一键复制联系方式。
        pasteboard.setString(text, forType: .string)
    }

    /**
     * 打开系统邮件客户端并预填联系邮箱
     */
    private func openMailComposer() {
        guard let mailURL = URL(string: "mailto:\(developerEmail)") else {
            return
        }

        // 使用系统默认邮件客户端打开 mailto 链接，便于直接发信联系开发者。
        NSWorkspace.shared.open(mailURL)
    }

    /**
     * Claude 开关绑定
     */
    private var claudeEnabledBinding: Binding<Bool> {
        Binding(
            get: { statusCenter.settings.isClaudeEnabled },
            set: { statusCenter.setClaudeEnabled($0) }
        )
    }

    /**
     * Codex 开关绑定
     */
    private var codexEnabledBinding: Binding<Bool> {
        Binding(
            get: { statusCenter.settings.isCodexEnabled },
            set: { statusCenter.setCodexEnabled($0) }
        )
    }

    /**
     * 悬浮窗开关绑定
     */
    private var floatingWindowEnabledBinding: Binding<Bool> {
        Binding(
            get: { statusCenter.settings.isFloatingWindowEnabled },
            set: { statusCenter.setFloatingWindowEnabled($0) }
        )
    }

    /**
     * 故障灯开关绑定
     */
    private var faultLightEnabledBinding: Binding<Bool> {
        Binding(
            get: { statusCenter.settings.isFaultLightEnabled },
            set: { statusCenter.setFaultLightEnabled($0) }
        )
    }

    /**
     * 悬浮窗标题显示绑定
     */
    private var floatingWindowTitleVisibleBinding: Binding<Bool> {
        Binding(
            get: { statusCenter.settings.isFloatingWindowTitleVisible },
            set: { statusCenter.setFloatingWindowTitleVisible($0) }
        )
    }

    /**
     * 悬浮窗状态文案显示绑定
     */
    private var floatingWindowStateTextVisibleBinding: Binding<Bool> {
        Binding(
            get: { statusCenter.settings.isFloatingWindowStateTextVisible },
            set: { statusCenter.setFloatingWindowStateTextVisible($0) }
        )
    }

    /**
     * 语音提醒开关绑定
     */
    private var voiceAlertEnabledBinding: Binding<Bool> {
        Binding(
            get: { statusCenter.settings.isVoiceAlertEnabled },
            set: { statusCenter.setVoiceAlertEnabled($0) }
        )
    }

    /**
     * 弹窗提醒开关绑定
     */
    private var popupAlertEnabledBinding: Binding<Bool> {
        Binding(
            get: { statusCenter.settings.isPopupAlertEnabled },
            set: { statusCenter.setPopupAlertEnabled($0) }
        )
    }

    /**
     * 提醒音频路径绑定
     */
    private var alertAudioPathBinding: Binding<String> {
        Binding(
            get: {
                statusCenter.settings.alertAudioPath == StatusAlertDefaults.defaultAudioPath
                ? ""
                : statusCenter.settings.alertAudioPath
            },
            set: { statusCenter.setAlertAudioPath($0) }
        )
    }

    /**
     * 主题模式绑定
     */
    private var displayThemeModeBinding: Binding<DisplayThemeMode> {
        Binding(
            get: { statusCenter.settings.displayThemeMode },
            set: { statusCenter.setDisplayThemeMode($0) }
        )
    }

    /**
     * 轮询频率绑定
     */
    private var pollingIntervalBinding: Binding<PollingInterval> {
        Binding(
            get: { statusCenter.settings.pollingInterval },
            set: { statusCenter.setPollingInterval($0) }
        )
    }

    /**
     * 悬浮窗模式绑定
     */
    private var floatingWindowDisplayModeBinding: Binding<FloatingWindowDisplayMode> {
        Binding(
            get: { statusCenter.settings.floatingWindowDisplayMode },
            set: { statusCenter.setFloatingWindowDisplayMode($0) }
        )
    }

    /**
     * 悬浮窗方向绑定
     */
    private var floatingWindowLampLayoutModeBinding: Binding<FloatingWindowLampLayoutMode> {
        Binding(
            get: { statusCenter.settings.floatingWindowLampLayoutMode },
            set: { statusCenter.setFloatingWindowLampLayoutMode($0) }
        )
    }

    /**
     * 横向灯位排列方式绑定
     */
    private var floatingWindowHorizontalPanelArrangementBinding: Binding<FloatingWindowHorizontalPanelArrangement> {
        Binding(
            get: { statusCenter.settings.floatingWindowHorizontalPanelArrangement },
            set: { statusCenter.setFloatingWindowHorizontalPanelArrangement($0) }
        )
    }

    /**
     * 悬浮窗缩放绑定
     */
    private var floatingWindowScaleBinding: Binding<Double> {
        Binding(
            get: { statusCenter.settings.floatingWindowScale },
            set: { statusCenter.setFloatingWindowScale($0) }
        )
    }

    /**
     * 悬浮窗缩放百分比文案
     */
    private var floatingWindowScalePercentText: String {
        "\(Int(statusCenter.settings.floatingWindowScale * 100))%"
    }

    /**
     * 生成单个 Agent 的运行状态行
     * @param agent Agent 类型
     * @return 视图
     */
    private func runtimeRow(for agent: AgentKind) -> some View {
        let snapshot = statusCenter.latestSnapshot(for: agent)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Text(agent.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Spacer(minLength: 0)

                statusBadge(for: snapshot)
            }

            Text(snapshot.headline)
                .font(.system(size: 12, weight: .medium, design: .rounded))

            Text(snapshot.detail)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent("最近刷新", value: StatusFormatting.relativeTimeText(for: snapshot.updatedAt))
                .font(.system(size: 11, weight: .regular, design: .rounded))

            if let sourcePath = snapshot.sourcePath {
                LabeledContent("状态文件") {
                    Text(sourcePath)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /**
     * 生成状态徽标
     * @param snapshot 状态快照
     * @return 视图
     */
    private func statusBadge(for snapshot: AgentStatusSnapshot) -> some View {
        let badgeColor = snapshot.lightColor.adaptiveColor(for: resolvedColorScheme)

        return Text(snapshot.runtimeState.displayText)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.14))
            .clipShape(Capsule(style: .continuous))
    }

    /**
     * 当前监听目录视图
     */
    private var watchedDirectoriesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前监听目录")
                .font(.system(size: 12, weight: .semibold, design: .rounded))

            if statusCenter.watchedDirectoryPaths.isEmpty {
                Text("当前没有启用任何目录监听")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(statusCenter.watchedDirectoryPaths, id: \.self) { path in
                    Text(path)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /**
     * 生成单个 Agent 的诊断操作区
     * @param agent Agent 类型
     * @return 视图
     */
    private func diagnosticsActions(for agent: AgentKind) -> some View {
        let snapshot = statusCenter.latestSnapshot(for: agent)

        return VStack(alignment: .leading, spacing: 8) {
            Text("\(agent.displayName)诊断")
                .font(.system(size: 12, weight: .semibold, design: .rounded))

            HStack(spacing: 10) {
                Button("打开数据目录") {
                    // 直接打开当前 Agent 的状态源根目录。
                    statusCenter.openSourceDirectories(for: agent)
                }

                Button("定位状态文件") {
                    // 在 Finder 中定位当前判定所使用的状态文件。
                    statusCenter.revealSourceFile(for: agent)
                }
                .disabled(snapshot.sourcePath == nil)
            }
        }
        .padding(.vertical, 4)
    }

    /**
     * 选择提醒音频文件
     */
    private func selectAlertAudioFile() {
        let openPanel = NSOpenPanel()

        // 仅允许选择单个音频文件，避免路径配置歧义。
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.mp3, .wav, .mpeg4Audio, .aiff]

        if openPanel.runModal() == .OK, let url = openPanel.url {
            statusCenter.setAlertAudioPath(url.path)
        }
    }
}
