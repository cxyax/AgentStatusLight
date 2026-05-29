//
//  FloatingStatusView.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import SwiftUI

/**
 * 桌面端悬浮状态视图，按 Agent 独立展示灯箱
 * @author 程序员阿鑫
 */
struct FloatingStatusView: View {
    /**
     * 当前是否处于拖拽缩放中
     */
    @State private var resizeGestureStartScale: Double?

    /**
     * 拖拽过程中生效的临时缩放比例
     */
    @State private var liveFloatingWindowScale: Double?

    /**
     * 当前是否正在拖拽缩放
     */
    @State private var isResizeHandleDragging = false

    /**
     * 最大灯箱数量，对应当前支持的 Agent 数量
     */
    static let maximumPanelCount = 2

    /**
     * 单个灯箱宽度
     */
    static let singlePanelWidth: CGFloat = 92

    /**
     * 单个灯箱高度
     */
    static let singlePanelHeight: CGFloat = 272

    /**
     * 横向灯位时单个灯箱宽度
     */
    static let horizontalPanelWidth: CGFloat = 228

    /**
     * 横向灯位时单个灯箱高度
     */
    static let horizontalPanelHeight: CGFloat = 136

    /**
     * 聚合单灯面板宽度
     */
    static let aggregatePanelWidth: CGFloat = 156

    /**
     * 聚合单灯面板高度
     */
    static let aggregatePanelHeight: CGFloat = 216

    /**
     * 多灯箱横向间距
     */
    static let panelSpacing: CGFloat = 14

    /**
     * 外层左右边距
     */
    static let horizontalPadding: CGFloat = 12

    /**
     * 外层上下边距
     */
    static let verticalPadding: CGFloat = 12

    /**
     * 状态中心
     */
    @ObservedObject var statusCenter: StatusCenter

    /**
     * 当前系统颜色方案
     */
    @Environment(\.colorScheme) private var colorScheme

    /**
     * 当前悬浮窗使用的主题色板
     */
    private var palette: SharedTheme.Palette {
        // 根据主题设置与系统外观解析当前悬浮窗配色。
        SharedTheme.palette(for: statusCenter.settings.displayThemeMode, colorScheme: colorScheme)
    }

    /**
     * 当前实际颜色方案
     */
    private var resolvedColorScheme: ColorScheme {
        SharedTheme.resolveColorScheme(for: statusCenter.settings.displayThemeMode, colorScheme: colorScheme)
    }

    /**
     * 根据当前颜色方案解析状态灯颜色
     * @param lightColor 状态灯颜色枚举
     * @return 适配后的颜色
     */
    private func adaptiveColor(for lightColor: LightColor) -> Color {
        lightColor.adaptiveColor(for: resolvedColorScheme)
    }

    /**
     * 当前应展示的悬浮快照
     */
    private var floatingSnapshots: [AgentStatusSnapshot] {
        statusCenter.visibleSnapshots
    }

    /**
     * 当前悬浮窗显示模式
     */
    private var displayMode: FloatingWindowDisplayMode {
        statusCenter.settings.floatingWindowDisplayMode
    }

    /**
     * 当前悬浮窗灯位布局
     */
    private var lampLayoutMode: FloatingWindowLampLayoutMode {
        statusCenter.settings.floatingWindowLampLayoutMode
    }

    /**
     * 横向灯位时的悬浮窗排列方式
     */
    private var horizontalPanelArrangement: FloatingWindowHorizontalPanelArrangement {
        statusCenter.settings.floatingWindowHorizontalPanelArrangement
    }

    /**
     * 是否显示悬浮窗标题
     */
    private var isTitleVisible: Bool {
        statusCenter.settings.isFloatingWindowTitleVisible
    }

    /**
     * 是否显示悬浮窗状态文案
     */
    private var isStateTextVisible: Bool {
        statusCenter.settings.isFloatingWindowStateTextVisible
    }

    /**
     * 当前悬浮窗缩放比例
     */
    private var floatingWindowScale: CGFloat {
        CGFloat(liveFloatingWindowScale ?? statusCenter.settings.floatingWindowScale)
    }

    /**
     * 当前是否使用横向灯位的上下排列
     */
    private var usesUpDownArrangement: Bool {
        displayMode == .dualPanel
        && lampLayoutMode == .horizontal
        && horizontalPanelArrangement == .upDown
    }

    /**
     * 当前悬浮窗总宽度
     */
    static func panelWidth(for mode: FloatingWindowDisplayMode,
                           lampLayoutMode: FloatingWindowLampLayoutMode,
                           horizontalPanelArrangement: FloatingWindowHorizontalPanelArrangement,
                           isTitleVisible: Bool,
                           isStateTextVisible: Bool,
                           count: Int,
                           scale: Double) -> CGFloat {
        basePanelWidth(
            for: mode,
            lampLayoutMode: lampLayoutMode,
            horizontalPanelArrangement: horizontalPanelArrangement,
            isTitleVisible: isTitleVisible,
            isStateTextVisible: isStateTextVisible,
            count: count
        ) * CGFloat(scale)
    }

    /**
     * 当前悬浮窗总宽度（未缩放）
     */
    static func basePanelWidth(for mode: FloatingWindowDisplayMode,
                               lampLayoutMode: FloatingWindowLampLayoutMode,
                               horizontalPanelArrangement: FloatingWindowHorizontalPanelArrangement,
                               isTitleVisible: Bool,
                               isStateTextVisible: Bool,
                               count: Int) -> CGFloat {
        switch mode {
        case .dualPanel:
            let clampedCount = max(count, 1)
            let agentPanelWidth = agentPanelSize(for: lampLayoutMode,
                                                 isTitleVisible: isTitleVisible,
                                                 isStateTextVisible: isStateTextVisible).width
            let totalLampWidth = CGFloat(clampedCount) * agentPanelWidth
            let totalSpacing = CGFloat(max(clampedCount - 1, 0)) * panelSpacing

            // 横向灯位允许切换上下堆叠，避免双灯并排时整体过宽。
            if lampLayoutMode == .horizontal && horizontalPanelArrangement == .upDown {
                return agentPanelWidth + horizontalPadding * 2
            }

            return totalLampWidth + totalSpacing + horizontalPadding * 2
        case .singleLamp:
            return aggregatePanelSize(isTitleVisible: isTitleVisible,
                                      isStateTextVisible: isStateTextVisible).width + horizontalPadding * 2
        }
    }

    /**
     * 当前悬浮窗总高度
     */
    static func panelHeight(for mode: FloatingWindowDisplayMode,
                            lampLayoutMode: FloatingWindowLampLayoutMode,
                            horizontalPanelArrangement: FloatingWindowHorizontalPanelArrangement,
                            isTitleVisible: Bool,
                            isStateTextVisible: Bool,
                            count: Int,
                            scale: Double) -> CGFloat {
        basePanelHeight(
            for: mode,
            lampLayoutMode: lampLayoutMode,
            horizontalPanelArrangement: horizontalPanelArrangement,
            isTitleVisible: isTitleVisible,
            isStateTextVisible: isStateTextVisible,
            count: count
        ) * CGFloat(scale)
    }

    /**
     * 当前悬浮窗总高度（未缩放）
     */
    static func basePanelHeight(for mode: FloatingWindowDisplayMode,
                                lampLayoutMode: FloatingWindowLampLayoutMode,
                                horizontalPanelArrangement: FloatingWindowHorizontalPanelArrangement,
                                isTitleVisible: Bool,
                                isStateTextVisible: Bool,
                                count: Int) -> CGFloat {
        switch mode {
        case .dualPanel:
            let clampedCount = max(count, 1)
            let agentPanelHeight = agentPanelSize(for: lampLayoutMode,
                                                  isTitleVisible: isTitleVisible,
                                                  isStateTextVisible: isStateTextVisible).height

            if lampLayoutMode == .horizontal && horizontalPanelArrangement == .upDown {
                let totalHeight = CGFloat(clampedCount) * agentPanelHeight
                let totalSpacing = CGFloat(max(clampedCount - 1, 0)) * panelSpacing
                return totalHeight + totalSpacing + verticalPadding * 2
            }

            return agentPanelHeight + verticalPadding * 2
        case .singleLamp:
            return aggregatePanelSize(isTitleVisible: isTitleVisible,
                                      isStateTextVisible: isStateTextVisible).height + verticalPadding * 2
        }
    }

    var body: some View {
        let basePanelSize = CGSize(
            width: Self.basePanelWidth(
                for: displayMode,
                lampLayoutMode: lampLayoutMode,
                horizontalPanelArrangement: horizontalPanelArrangement,
                isTitleVisible: isTitleVisible,
                isStateTextVisible: isStateTextVisible,
                count: floatingSnapshots.count
            ),
            height: Self.basePanelHeight(
                for: displayMode,
                lampLayoutMode: lampLayoutMode,
                horizontalPanelArrangement: horizontalPanelArrangement,
                isTitleVisible: isTitleVisible,
                isStateTextVisible: isStateTextVisible,
                count: floatingSnapshots.count
            )
        )

        return Group {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    switch displayMode {
                    case .dualPanel:
                        Group {
                            if usesUpDownArrangement {
                                VStack(spacing: Self.panelSpacing) {
                                    ForEach(floatingSnapshots) { snapshot in
                                        agentPanel(for: snapshot)
                                    }
                                }
                            } else {
                                HStack(spacing: Self.panelSpacing) {
                                    ForEach(floatingSnapshots) { snapshot in
                                        agentPanel(for: snapshot)
                                    }
                                }
                            }
                        }
                    case .singleLamp:
                        aggregatePanel
                    }
                }
                .padding(.horizontal, Self.horizontalPadding)
                .padding(.vertical, Self.verticalPadding)
                .frame(width: basePanelSize.width, height: basePanelSize.height, alignment: .topLeading)
                .scaleEffect(floatingWindowScale, anchor: .topLeading)
                .frame(width: basePanelSize.width * floatingWindowScale,
                       height: basePanelSize.height * floatingWindowScale,
                       alignment: .topLeading)

                resizeHandle(basePanelSize: basePanelSize)
            }
        }
        .frame(width: basePanelSize.width * floatingWindowScale,
               height: basePanelSize.height * floatingWindowScale,
               alignment: .topLeading)
        .compositingGroup()
    }

    /**
     * 右下角缩放手柄
     * @param basePanelSize 当前未缩放的面板尺寸
     * @return 视图
     */
    private func resizeHandle(basePanelSize: CGSize) -> some View {
        Color.clear
            .frame(width: 26, height: 26)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(palette.panelFill.opacity(0.94))
                    .overlay(
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(palette.secondaryTextColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(palette.panelStroke, lineWidth: 0.8)
                    )
                    .frame(width: 18, height: 18)
                    .opacity(isResizeHandleDragging ? 1 : 0)
            )
            .padding(.trailing, 6)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let startScale = resizeGestureStartScale ?? statusCenter.settings.floatingWindowScale

                        if resizeGestureStartScale == nil {
                            // 仅在拖拽开始时记录起始缩放值，确保整次手势按同一基准计算。
                            resizeGestureStartScale = startScale
                        }

                        let resolvedScale = resolvedScale(
                            from: value.translation,
                            basePanelSize: basePanelSize,
                            startScale: startScale
                        )

                        // 拖拽过程中先走临时缩放，减少频繁持久化导致的卡顿。
                        liveFloatingWindowScale = resolvedScale
                        isResizeHandleDragging = true
                        statusCenter.updateFloatingWindowScaleDuringDrag(resolvedScale)
                    }
                    .onEnded { _ in
                        let finalScale = liveFloatingWindowScale ?? statusCenter.settings.floatingWindowScale

                        // 手势结束后清理起始缩放值，避免影响下一次拖拽。
                        liveFloatingWindowScale = nil
                        resizeGestureStartScale = nil
                        isResizeHandleDragging = false

                        // 仅在拖拽结束时落盘最终缩放结果，兼顾流畅度与配置持久化。
                        statusCenter.setFloatingWindowScale(finalScale)
                    }
            )
    }

    /**
     * 根据拖拽位移计算新的缩放比例
     * @param translation 拖拽位移
     * @param basePanelSize 未缩放面板尺寸
     * @param startScale 拖拽开始时的缩放比例
     * @return 目标缩放比例
     */
    private func resolvedScale(from translation: CGSize,
                               basePanelSize: CGSize,
                               startScale: Double) -> Double {
        let currentWidth = max(basePanelSize.width * CGFloat(startScale), 1)
        let currentHeight = max(basePanelSize.height * CGFloat(startScale), 1)
        let normalizedWidthDelta = translation.width / currentWidth
        let normalizedHeightDelta = translation.height / currentHeight
        let normalizedDiagonalDelta = (normalizedWidthDelta + normalizedHeightDelta) / 2

        // 使用对角线方向的综合位移做等比缩放，避免自由拉伸破坏灯位布局。
        return FloatingWindowScaleDefaults.clampedScale(startScale * Double(1 + normalizedDiagonalDelta))
    }

    /**
     * 聚合单灯面板
     */
    private var aggregatePanel: some View {
        let presentation = aggregateLampPresentation

        return VStack(spacing: 12) {
            if isTitleVisible {
                Text("状态总览")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.titleColor)
            }

            lampShape(baseColor: presentation.color, isActive: true)
                .frame(width: 62, height: 62)
                .modifier(
                    LampGlowModifier(
                        isActive: true,
                        behavior: presentation.behavior,
                        baseColor: presentation.color
                    )
                )

            if isStateTextVisible {
                VStack(spacing: 4) {
                    Text(presentation.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.titleColor)

                    Text(presentation.detail)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 6) {
                ForEach(floatingSnapshots) { snapshot in
                    aggregateStatusRow(for: snapshot)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(width: Self.aggregatePanelSize(isTitleVisible: isTitleVisible,
                                              isStateTextVisible: isStateTextVisible).width,
               height: Self.aggregatePanelSize(isTitleVisible: isTitleVisible,
                                               isStateTextVisible: isStateTextVisible).height)
        .background(panelBackground)
    }

    /**
     * 生成单个 Agent 的灯箱
     * @param snapshot 状态快照
     * @return 视图
     */
    private func agentPanel(for snapshot: AgentStatusSnapshot) -> some View {
        let lampPresentation = lampPresentation(for: snapshot)
        let isHorizontalLayout = lampLayoutMode == .horizontal
        let hasHeaderContent = isTitleVisible || isStateTextVisible

        return VStack(spacing: hasHeaderContent ? 10 : 0) {
            if hasHeaderContent {
                VStack(spacing: 3) {
                    if isTitleVisible {
                        Text(snapshot.agent.displayName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.titleColor)
                    }

                    if isStateTextVisible {
                        Text(snapshot.runtimeState.displayText)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(adaptiveColor(for: snapshot.lightColor).opacity(0.92))
                    }
                }
            }

            if isHorizontalLayout {
                HStack(spacing: 12) {
                    lampItem(
                        for: .red,
                        presentation: lampPresentation[.red] ?? LampPresentation()
                    )
                    lampItem(
                        for: .yellow,
                        presentation: lampPresentation[.yellow] ?? LampPresentation()
                    )
                    lampItem(
                        for: .green,
                        presentation: lampPresentation[.green] ?? LampPresentation()
                    )
                    faultIndicator(
                        presentation: lampPresentation[.fault] ?? LampPresentation()
                    )
                }
            } else {
                VStack(spacing: 14) {
                    lampItem(
                        for: .red,
                        presentation: lampPresentation[.red] ?? LampPresentation()
                    )
                    lampItem(
                        for: .yellow,
                        presentation: lampPresentation[.yellow] ?? LampPresentation()
                    )
                    lampItem(
                        for: .green,
                        presentation: lampPresentation[.green] ?? LampPresentation()
                    )
                    faultIndicator(
                        presentation: lampPresentation[.fault] ?? LampPresentation()
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(width: Self.agentPanelSize(for: lampLayoutMode,
                                          isTitleVisible: isTitleVisible,
                                          isStateTextVisible: isStateTextVisible).width,
               height: Self.agentPanelSize(for: lampLayoutMode,
                                           isTitleVisible: isTitleVisible,
                                           isStateTextVisible: isStateTextVisible).height)
        .background(panelBackground)
    }

    /**
     * 生成单个悬浮灯项
     * @param lamp 灯类型
     * @param presentation 灯展示信息
     * @return 视图
     */
    private func lampItem(for lamp: SignalLampKind,
                          presentation: LampPresentation) -> some View {
        let baseColor = adaptiveColor(for: lamp.lightColor)

        return lampShape(baseColor: baseColor, isActive: presentation.isActive)
            // 当前点亮的灯放到更高层，确保呼吸辉光不会被邻位暗灯抢走视觉焦点。
            .zIndex(presentation.isActive ? 1 : 0)
            .modifier(
                LampGlowModifier(
                    isActive: presentation.isActive,
                    behavior: presentation.behavior,
                    baseColor: baseColor
                )
            )
            // 灯状态或主题变化时强制重建灯视图，避免首次点亮沿用旧的浅色渲染态。
            .id(lampRenderIdentity(for: lamp, presentation: presentation))
    }

    /**
     * 生成单灯渲染标识
     * @param lamp 灯类型
     * @param presentation 灯展示信息
     * @return 渲染标识
     */
    private func lampRenderIdentity(for lamp: SignalLampKind,
                                    presentation: LampPresentation) -> String {
        let colorSchemeToken = resolvedColorScheme == .dark ? "dark" : "light"
        let activeToken = presentation.isActive ? "active" : "inactive"
        return "\(lamp.rawValue)-\(activeToken)-\(presentation.behavior.rawValue)-\(colorSchemeToken)"
    }

    /**
     * 生成圆灯形状
     * @param baseColor 灯基础色
     * @param isActive 是否点亮
     * @return 视图
     */
    private func lampShape(baseColor: Color,
                           isActive: Bool) -> some View {
        Circle()
            .fill(lampShellFillColor)
            .frame(width: 46, height: 46)
            .overlay(
                Circle()
                    .stroke(lampShellStrokeColor, lineWidth: 0.9)
            )
            .overlay(
                Circle()
                    .stroke(lampOuterRingColor(isActive: isActive), lineWidth: 0.45)
                    .padding(1.4)
            )
            .overlay(
                Circle()
                    .fill(circleFillStyle(isActive: isActive, baseColor: baseColor))
                    .frame(width: 42, height: 42)
            )
            .overlay(
                Circle()
                    .fill(lampCoreHighlightStyle(isActive: isActive, baseColor: baseColor))
                    .frame(width: isActive ? 28 : 16, height: isActive ? 28 : 16)
            )
    }

    /**
     * 聚合模式下的单行状态摘要
     * @param snapshot 状态快照
     * @return 视图
     */
    private func aggregateStatusRow(for snapshot: AgentStatusSnapshot) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(adaptiveColor(for: snapshot.lightColor).opacity(snapshot.runtimeState == .disabled ? 0.18 : 0.92))
                .frame(width: 8, height: 8)

            Text(snapshot.agent.displayName)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.titleColor)

            if isStateTextVisible {
                Spacer(minLength: 0)

                Text(snapshot.runtimeState.displayText)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(adaptiveColor(for: snapshot.lightColor).opacity(0.94))
            }
        }
    }

    /**
     * 灯箱背景
     */
    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.backgroundTop,
                        palette.backgroundBottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(palette.panelStroke, lineWidth: 1)
            )
    }

    /**
     * 底部故障指示灯
     * @param presentation 灯展示信息
     * @return 视图
     */
    private func faultIndicator(presentation: LampPresentation) -> some View {
        let baseColor = adaptiveColor(for: SignalLampKind.fault.lightColor)

        return Capsule(style: .continuous)
            .fill(faultFillStyle(isActive: presentation.isActive, baseColor: baseColor))
            .frame(width: 24, height: 7)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(faultStrokeColor, lineWidth: 0.8)
            )
            .modifier(
                LampGlowModifier(
                    isActive: presentation.isActive,
                    behavior: presentation.behavior,
                    baseColor: baseColor
                )
            )
    }

    /**
     * 灯座填充颜色
     */
    private var lampShellFillColor: Color {
        resolvedColorScheme == .dark
        ? Color.black.opacity(0.26)
        : Color.black.opacity(0.08)
    }

    /**
     * 灯座描边颜色
     */
    private var lampShellStrokeColor: Color {
        resolvedColorScheme == .dark
        ? Color.black.opacity(0.68)
        : Color.black.opacity(0.20)
    }

    /**
     * 灯体外圈颜色
     */
    private func lampOuterRingColor(isActive: Bool) -> Color {
        if resolvedColorScheme == .dark {
            return isActive ? Color.white.opacity(0.08) : Color.white.opacity(0.04)
        }

        return isActive ? Color.white.opacity(0.24) : Color.white.opacity(0.14)
    }

    /**
     * 故障灯描边颜色
     */
    private var faultStrokeColor: Color {
        resolvedColorScheme == .dark
        ? Color.white.opacity(0.10)
        : Color.black.opacity(0.10)
    }

    /**
     * 生成圆灯渐变填充
     * @param isActive 是否点亮
     * @param baseColor 灯基础色
     * @return 渐变填充样式
     */
    private func circleFillStyle(isActive: Bool, baseColor: Color) -> AnyShapeStyle {
        let inactiveGray = adaptiveColor(for: .gray)

        return AnyShapeStyle(
            RadialGradient(
                colors: isActive
                ? [
                    baseColor.opacity(resolvedColorScheme == .dark ? 1.0 : 0.98),
                    baseColor.opacity(0.98),
                    baseColor.opacity(0.90),
                    baseColor.opacity(0.62)
                ]
                : [
                    Color.white.opacity(resolvedColorScheme == .dark ? 0.05 : 0.20),
                    inactiveGray.opacity(resolvedColorScheme == .dark ? 0.42 : 0.30),
                    inactiveGray.opacity(resolvedColorScheme == .dark ? 0.18 : 0.12)
                ],
                center: .center,
                startRadius: 2,
                endRadius: 18
            )
        )
    }

    /**
     * 生成灯芯高光填充
     * @param isActive 是否点亮
     * @param baseColor 灯基础色
     * @return 灯芯高光样式
     */
    private func lampCoreHighlightStyle(isActive: Bool, baseColor: Color) -> AnyShapeStyle {
        let inactiveGray = adaptiveColor(for: .gray)

        return AnyShapeStyle(
            RadialGradient(
                colors: isActive
                ? [
                    baseColor.opacity(resolvedColorScheme == .dark ? 0.94 : 0.86),
                    baseColor.opacity(0.76),
                    baseColor.opacity(0.34)
                ]
                : [
                    Color.white.opacity(resolvedColorScheme == .dark ? 0.035 : 0.10),
                    inactiveGray.opacity(resolvedColorScheme == .dark ? 0.12 : 0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: isActive ? 18 : 7
            )
        )
    }

    /**
     * 生成故障灯渐变填充
     * @param isActive 是否点亮
     * @param baseColor 灯基础色
     * @return 渐变填充样式
     */
    private func faultFillStyle(isActive: Bool, baseColor: Color) -> AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: isActive
                ? [
                    baseColor.opacity(0.88),
                    baseColor.opacity(0.52)
                ]
                : [
                    baseColor.opacity(0.18),
                    baseColor.opacity(0.08)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    /**
     * 根据快照计算灯展示信息
     * @param snapshot 状态快照
     * @return 灯展示字典
     */
    private func lampPresentation(for snapshot: AgentStatusSnapshot) -> [SignalLampKind: LampPresentation] {
        var presentations = Dictionary(
            uniqueKeysWithValues: SignalLampKind.allCases.map { ($0, LampPresentation()) }
        )

        if snapshot.isFault && statusCenter.settings.isFaultLightEnabled {
            presentations[.fault] = LampPresentation(
                isActive: true,
                behavior: .pulseFast
            )
            return presentations
        }

        switch snapshot.lightColor {
        case .red:
            presentations[.red] = LampPresentation(
                isActive: true,
                behavior: snapshot.runtimeState == .failed ? .solid : .pulseFast
            )
        case .yellow:
            presentations[.yellow] = LampPresentation(
                isActive: true,
                behavior: snapshot.runtimeState == .running ? .pulseSlow : .solid
            )
        case .green:
            presentations[.green] = LampPresentation(
                isActive: true,
                behavior: .solid
            )
        case .gray, .fault:
            break
        }

        return presentations
    }

    /**
     * 计算双灯模式下单个 Agent 灯箱尺寸
     * @param lampLayoutMode 灯位布局
     * @return 灯箱尺寸
     */
    private static func agentPanelSize(for lampLayoutMode: FloatingWindowLampLayoutMode,
                                       isTitleVisible: Bool,
                                       isStateTextVisible: Bool) -> CGSize {
        switch lampLayoutMode {
        case .vertical:
            return CGSize(width: singlePanelWidth,
                          height: resolvedVerticalPanelHeight(isTitleVisible: isTitleVisible,
                                                              isStateTextVisible: isStateTextVisible))
        case .horizontal:
            return CGSize(width: horizontalPanelWidth,
                          height: resolvedHorizontalPanelHeight(isTitleVisible: isTitleVisible,
                                                                isStateTextVisible: isStateTextVisible))
        }
    }

    /**
     * 计算聚合单灯面板尺寸
     * @param isTitleVisible 是否显示标题
     * @param isStateTextVisible 是否显示状态文案
     * @return 面板尺寸
     */
    private static func aggregatePanelSize(isTitleVisible: Bool,
                                           isStateTextVisible: Bool) -> CGSize {
        CGSize(width: aggregatePanelWidth,
               height: resolvedAggregatePanelHeight(isTitleVisible: isTitleVisible,
                                                    isStateTextVisible: isStateTextVisible))
    }

    /**
     * 计算竖向灯位面板高度
     * @param isTitleVisible 是否显示标题
     * @param isStateTextVisible 是否显示状态文案
     * @return 面板高度
     */
    private static func resolvedVerticalPanelHeight(isTitleVisible: Bool,
                                                    isStateTextVisible: Bool) -> CGFloat {
        230 + headerContentHeight(isTitleVisible: isTitleVisible, isStateTextVisible: isStateTextVisible)
    }

    /**
     * 计算横向灯位面板高度
     * @param isTitleVisible 是否显示标题
     * @param isStateTextVisible 是否显示状态文案
     * @return 面板高度
     */
    private static func resolvedHorizontalPanelHeight(isTitleVisible: Bool,
                                                      isStateTextVisible: Bool) -> CGFloat {
        94 + headerContentHeight(isTitleVisible: isTitleVisible, isStateTextVisible: isStateTextVisible)
    }

    /**
     * 计算聚合单灯面板高度
     * @param isTitleVisible 是否显示标题
     * @param isStateTextVisible 是否显示状态文案
     * @return 面板高度
     */
    private static func resolvedAggregatePanelHeight(isTitleVisible: Bool,
                                                     isStateTextVisible: Bool) -> CGFloat {
        let visibleSectionCount = 2 + (isTitleVisible ? 1 : 0) + (isStateTextVisible ? 1 : 0)
        let spacingCount = max(visibleSectionCount - 1, 0)
        return 134 + (isTitleVisible ? 16 : 0) + (isStateTextVisible ? 30 : 0) + CGFloat(spacingCount) * 12
    }

    /**
     * 计算标题与状态文案占用高度
     * @param isTitleVisible 是否显示标题
     * @param isStateTextVisible 是否显示状态文案
     * @return 占用高度
     */
    private static func headerContentHeight(isTitleVisible: Bool,
                                            isStateTextVisible: Bool) -> CGFloat {
        let titleHeight: CGFloat = isTitleVisible ? 16 : 0
        let stateHeight: CGFloat = isStateTextVisible ? 13 : 0
        let innerSpacing: CGFloat = isTitleVisible && isStateTextVisible ? 3 : 0
        let outerSpacing: CGFloat = isTitleVisible || isStateTextVisible ? 10 : 0
        return titleHeight + stateHeight + innerSpacing + outerSpacing
    }

    /**
     * 计算聚合单灯展示信息
     */
    private var aggregateLampPresentation: AggregateLampPresentation {
        if statusCenter.isFaultLampActive {
            return AggregateLampPresentation(
                color: adaptiveColor(for: SignalLampKind.fault.lightColor),
                behavior: statusCenter.signalLampBehaviors[.fault] ?? .pulseFast,
                title: "外部故障",
                detail: "接口、令牌或额度异常"
            )
        }

        switch statusCenter.combinedLightColor {
        case .red:
            return AggregateLampPresentation(
                color: adaptiveColor(for: SignalLampKind.red.lightColor),
                behavior: statusCenter.signalLampBehaviors[.red] ?? .solid,
                title: "存在异常",
                detail: "最近任务出现失败或阻塞"
            )
        case .yellow:
            let waitingUser = floatingSnapshots.contains(where: { $0.runtimeState == .waitingUser })
            return AggregateLampPresentation(
                color: adaptiveColor(for: SignalLampKind.yellow.lightColor),
                behavior: statusCenter.signalLampBehaviors[.yellow] ?? .pulseSlow,
                title: waitingUser ? "等待处理" : "运行中",
                detail: waitingUser ? "当前等待用户输入或确认" : "Claude或Codex正在工作"
            )
        case .green:
            return AggregateLampPresentation(
                color: adaptiveColor(for: SignalLampKind.green.lightColor),
                behavior: statusCenter.signalLampBehaviors[.green] ?? .solid,
                title: "当前空闲",
                detail: "最近任务已结束"
            )
        case .gray, .fault:
            return AggregateLampPresentation(
                color: adaptiveColor(for: .gray),
                behavior: .off,
                title: "状态未明确",
                detail: "暂未读取到可用状态"
            )
        }
    }
}

/**
 * 单盏灯展示信息
 * @author 程序员阿鑫
 */
private struct LampPresentation {
    /**
     * 是否点亮
     */
    var isActive: Bool = false

    /**
     * 灯效行为
     */
    var behavior: LampBehavior = .off
}

/**
 * 聚合单灯展示信息
 * @author 程序员阿鑫
 */
private struct AggregateLampPresentation {
    /**
     * 灯颜色
     */
    let color: Color

    /**
     * 灯效行为
     */
    let behavior: LampBehavior

    /**
     * 标题
     */
    let title: String

    /**
     * 说明
     */
    let detail: String
}
