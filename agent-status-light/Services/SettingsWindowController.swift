//
//  SettingsWindowController.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import AppKit
import SwiftUI

/**
 * 设置窗口控制器，负责管理桌面端独立配置窗口
 * @author 程序员阿鑫
 */
@MainActor
final class SettingsWindowController {

    /**
     * 设置窗口实例
     */
    private var window: NSWindow?

    /**
     * 显示设置窗口
     * @param statusCenter 状态中心
     */
    func show(statusCenter: StatusCenter) {
        let window = window ?? buildWindow(statusCenter: statusCenter)
        updateContent(statusCenter: statusCenter)
        applyWindowAppearance(statusCenter: statusCenter)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /**
     * 更新设置窗口内容
     * @param statusCenter 状态中心
     */
    func updateContent(statusCenter: StatusCenter) {
        guard let host = window?.contentViewController as? NSHostingController<SettingsWindowView> else {
            return
        }

        // 使用最新状态中心刷新设置窗口内容。
        host.rootView = SettingsWindowView(statusCenter: statusCenter)
        applyWindowAppearance(statusCenter: statusCenter)
    }

    /**
     * 构建设置窗口
     * @param statusCenter 状态中心
     * @return 窗口实例
     */
    private func buildWindow(statusCenter: StatusCenter) -> NSWindow {
        let host = NSHostingController(rootView: SettingsWindowView(statusCenter: statusCenter))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        // 按普通应用窗口配置设置页，保持独立窗体交互体验。
        window.title = "设置"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 820, height: 680)
        window.setFrameAutosaveName("AgentStatusLight.SettingsWindow")
        window.tabbingMode = .disallowed
        window.toolbarStyle = .preference
        window.center()
        window.contentViewController = host
        applyWindowAppearance(window: window, statusCenter: statusCenter)

        self.window = window
        return window
    }

    /**
     * 根据主题模式同步设置窗口原生外观
     * @param statusCenter 状态中心
     */
    private func applyWindowAppearance(statusCenter: StatusCenter) {
        guard let window else {
            return
        }

        applyWindowAppearance(window: window, statusCenter: statusCenter)
    }

    /**
     * 根据主题模式同步指定窗口的原生外观
     * @param window 目标窗口
     * @param statusCenter 状态中心
     */
    private func applyWindowAppearance(window: NSWindow, statusCenter: StatusCenter) {
        switch statusCenter.settings.displayThemeMode {
        case .system:
            // 跟随系统时清空显式 appearance，让 AppKit 回到系统外观。
            window.appearance = nil
            window.contentView?.appearance = nil
            window.contentViewController?.view.appearance = nil
        case .daylight:
            let appearance = NSAppearance(named: .aqua)
            window.appearance = appearance
            window.contentView?.appearance = appearance
            window.contentViewController?.view.appearance = appearance
        case .night:
            let appearance = NSAppearance(named: .darkAqua)
            window.appearance = appearance
            window.contentView?.appearance = appearance
            window.contentViewController?.view.appearance = appearance
        }
    }
}
