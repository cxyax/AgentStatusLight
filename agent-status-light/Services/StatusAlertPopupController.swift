//
//  StatusAlertPopupController.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/29.
//

import AppKit
import SwiftUI

/**
 * 状态提醒弹窗控制器，负责展示应用内轻量消息提醒
 * @author 程序员阿鑫
 */
@MainActor
final class StatusAlertPopupController {

    /**
     * 弹窗面板实例
     */
    private var panel: NSPanel?

    /**
     * 延后自动关闭任务
     */
    private var dismissWorkItem: DispatchWorkItem?

    /**
     * 展示提醒弹窗
     * @param title 提醒标题
     * @param body 提醒正文
     */
    func show(title: String, body: String) {
        let panel = panel ?? buildPanel()
        let popupView = StatusAlertPopupView(title: title, message: body)

        if let host = panel.contentViewController as? NSHostingController<StatusAlertPopupView> {
            // 已存在宿主视图时直接替换内容，避免频繁重建面板对象。
            host.rootView = popupView
        } else {
            // 首次展示时创建 SwiftUI 宿主视图。
            panel.contentViewController = NSHostingController(rootView: popupView)
        }

        // 根据正文内容动态计算面板尺寸，避免长文案被截断。
        syncPanelSize(for: panel)

        // 将弹窗固定到当前主屏幕右上角，便于快速感知。
        updatePanelOrigin(for: panel)

        dismissWorkItem?.cancel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        // 使用轻微淡入动画，让提醒更容易被注意到。
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }

        // 每次展示后重新计时自动关闭，避免弹窗长期占据桌面。
        scheduleDismiss(for: panel)
    }

    /**
     * 构建提醒面板
     * @return 面板对象
     */
    private func buildPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 328, height: 118),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // 配置为不抢焦点的桌面顶层浮窗，既醒目又不打断当前操作。
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        self.panel = panel
        return panel
    }

    /**
     * 同步弹窗尺寸
     * @param panel 目标面板
     */
    private func syncPanelSize(for panel: NSPanel) {
        guard let hostView = panel.contentViewController?.view else {
            return
        }

        // 强制布局一次，确保读取到最新的内容高度。
        hostView.layoutSubtreeIfNeeded()

        let fittingSize = hostView.fittingSize
        let targetSize = NSSize(
            width: max(328, min(420, fittingSize.width)),
            height: max(118, fittingSize.height)
        )

        panel.setContentSize(targetSize)
        hostView.frame = NSRect(origin: .zero, size: targetSize)
    }

    /**
     * 更新弹窗位置
     * @param panel 目标面板
     */
    private func updatePanelOrigin(for panel: NSPanel) {
        let targetScreen = NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen else {
            return
        }

        let visibleFrame = targetScreen.visibleFrame
        let targetOrigin = NSPoint(
            x: visibleFrame.maxX - panel.frame.width - 20,
            y: visibleFrame.maxY - panel.frame.height - 20
        )

        // 每次提醒都贴靠屏幕右上角，避免被悬浮窗或其他窗口遮住。
        panel.setFrameOrigin(targetOrigin)
    }

    /**
     * 安排自动关闭任务
     * @param panel 目标面板
     */
    private func scheduleDismiss(for panel: NSPanel) {
        let dismissWorkItem = DispatchWorkItem { [weak self] in
            self?.dismiss(panel: panel)
        }

        self.dismissWorkItem = dismissWorkItem

        // 停留数秒后自动关闭，兼顾提醒可见性与桌面整洁。
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: dismissWorkItem)
    }

    /**
     * 关闭弹窗
     * @param panel 目标面板
     */
    private func dismiss(panel: NSPanel) {
        // 使用淡出动画收尾，避免弹窗瞬间消失显得生硬。
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }
}

/**
 * 状态提醒弹窗视图，负责渲染标题与正文
 * @author 程序员阿鑫
 */
private struct StatusAlertPopupView: View {

    /**
     * 提醒标题
     */
    let title: String

    /**
     * 提醒正文
     */
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("状态提醒")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))

            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.96))
                .lineLimit(2)

            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 328, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.18, blue: 0.22).opacity(0.96),
                            Color(red: 0.10, green: 0.11, blue: 0.14).opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: 10)
    }
}
