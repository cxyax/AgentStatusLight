//
//  FloatingWindowController.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import AppKit
import SwiftUI

/**
 * 可自由拖动的桌面悬浮面板
 * @author 程序员阿鑫
 */
@MainActor
final class FloatingPanel: NSPanel {

    /**
     * 允许窗口通过背景区域拖动
     */
    override var canBecomeKey: Bool {
        false
    }

    /**
     * 允许窗口通过背景区域拖动
     */
    override var canBecomeMain: Bool {
        false
    }
}

/**
 * 桌面悬浮窗控制器，负责管理四灯悬浮视图
 * @author 程序员阿鑫
 */
@MainActor
final class FloatingWindowController {

    /**
     * 悬浮窗实例
     */
    private var panel: NSPanel?

    /**
     * 延后执行的尺寸同步任务
     */
    private var pendingResizeWorkItem: DispatchWorkItem?

    /**
     * 显示悬浮窗
     * @param statusCenter 状态中心
     */
    func show(statusCenter: StatusCenter) {
        let isInitialBuild = panel == nil
        let panel = panel ?? buildPanel(statusCenter: statusCenter)

        if !isInitialBuild {
            updateContent(statusCenter: statusCenter)
        }

        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    /**
     * 隐藏悬浮窗
     */
    func hide() {
        pendingResizeWorkItem?.cancel()
        pendingResizeWorkItem = nil
        panel?.orderOut(nil)
    }

    /**
     * 更新悬浮窗内容
     * @param statusCenter 状态中心
     */
    func updateContent(statusCenter: StatusCenter) {
        guard panel?.contentViewController as? NSHostingController<FloatingStatusView> != nil else {
            return
        }

        // 根视图已持有同一个状态中心对象，直接依赖 ObservedObject 刷新即可，避免拖拽缩放时重建视图打断手势状态。
        schedulePanelSizeSync(with: statusCenter)
    }

    /**
     * 在拖拽缩放过程中立即同步悬浮窗尺寸
     * @param statusCenter 状态中心
     */
    func syncPanelSizeImmediately(with statusCenter: StatusCenter, scaleOverride: Double? = nil) {
        pendingResizeWorkItem?.cancel()
        pendingResizeWorkItem = nil

        // 拖拽期间直接刷新窗口尺寸，减少异步调度带来的跳动感。
        syncPanelSize(with: statusCenter, scaleOverride: scaleOverride)
    }

    /**
     * 构建悬浮窗
     * @param statusCenter 状态中心
     * @return 窗体
     */
    private func buildPanel(statusCenter: StatusCenter) -> NSPanel {
        let host = NSHostingController(rootView: FloatingStatusView(statusCenter: statusCenter))
        let panelSize = panelSize(statusCenter: statusCenter)
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelSize.width, height: panelSize.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // 配置为桌面端常驻悬浮窗口，同时保持任意位置可拖动。
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentViewController = host
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
        host.view.frame = NSRect(x: 0, y: 0, width: panelSize.width, height: panelSize.height)
        panel.center()

        self.panel = panel
        return panel
    }

    /**
     * 同步悬浮窗尺寸
     * @param statusCenter 状态中心
     */
    private func syncPanelSize(with statusCenter: StatusCenter, scaleOverride: Double? = nil) {
        guard let panel else {
            return
        }

        let targetSize = panelSize(statusCenter: statusCenter, scaleOverride: scaleOverride)
        let currentFrame = panel.frame

        guard currentFrame.size != targetSize else {
            return
        }

        // 保持左上角位置稳定，仅同步尺寸，避免切换模式时窗口跳动。
        let targetOrigin = NSPoint(
            x: currentFrame.minX,
            y: currentFrame.maxY - targetSize.height
        )
        let targetFrame = NSRect(origin: targetOrigin, size: targetSize)

        panel.contentViewController?.view.frame = NSRect(origin: .zero, size: targetSize)
        panel.setFrame(targetFrame, display: true, animate: false)
    }

    /**
     * 延后同步悬浮窗尺寸，避开 SwiftUI 当前布局事务
     * @param statusCenter 状态中心
     */
    private func schedulePanelSizeSync(with statusCenter: StatusCenter) {
        pendingResizeWorkItem?.cancel()

        let resizeWorkItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            // 等当前一轮 SwiftUI 视图更新结束后再改窗口尺寸，避免触发布局期崩溃。
            self.syncPanelSize(with: statusCenter)
        }

        pendingResizeWorkItem = resizeWorkItem
        DispatchQueue.main.async(execute: resizeWorkItem)
    }

    /**
     * 计算悬浮窗尺寸
     * @return 窗口尺寸
     */
    private func panelSize(statusCenter: StatusCenter, scaleOverride: Double? = nil) -> NSSize {
        let resolvedScale = scaleOverride ?? statusCenter.settings.floatingWindowScale

        return NSSize(
            width: FloatingStatusView.panelWidth(
                for: statusCenter.settings.floatingWindowDisplayMode,
                lampLayoutMode: statusCenter.settings.floatingWindowLampLayoutMode,
                horizontalPanelArrangement: statusCenter.settings.floatingWindowHorizontalPanelArrangement,
                isTitleVisible: statusCenter.settings.isFloatingWindowTitleVisible,
                isStateTextVisible: statusCenter.settings.isFloatingWindowStateTextVisible,
                count: statusCenter.visibleSnapshots.count,
                scale: resolvedScale
            ),
            height: FloatingStatusView.panelHeight(
                for: statusCenter.settings.floatingWindowDisplayMode,
                lampLayoutMode: statusCenter.settings.floatingWindowLampLayoutMode,
                horizontalPanelArrangement: statusCenter.settings.floatingWindowHorizontalPanelArrangement,
                isTitleVisible: statusCenter.settings.isFloatingWindowTitleVisible,
                isStateTextVisible: statusCenter.settings.isFloatingWindowStateTextVisible,
                count: statusCenter.visibleSnapshots.count,
                scale: resolvedScale
            )
        )
    }
}
