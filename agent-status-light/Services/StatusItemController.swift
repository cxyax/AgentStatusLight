//
//  StatusItemController.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/28.
//

import AppKit
import Combine
import SwiftUI

/**
 * 穿透点击的菜单栏宿主视图，确保点击事件交给状态栏按钮处理
 * @author 程序员阿鑫
 */
@MainActor
final class StatusItemHostingView: NSHostingView<AnyView> {

    /**
     * 使用AnyView初始化宿主视图
     * @param rootView 需要承载的根视图
     */
    required init(rootView: AnyView) {
        super.init(rootView: rootView)
    }

    /**
     * 使用任意SwiftUI视图初始化宿主视图
     * @param rootView 需要承载的根视图
     */
    convenience init<Content: View>(rootView: Content) {
        // 使用AnyView擦除泛型参数，规避归档场景下Swift编译器对泛型宿主视图析构优化的崩溃。
        self.init(rootView: AnyView(rootView))
    }

    /**
     * 通过归档初始化宿主视图
     * @param coder 解码器
     */
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /**
     * 忽略自身命中测试，将点击交还给父级按钮
     * @param point 点击位置
     * @return 永远返回空，表示不拦截事件
     */
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

/**
 * 菜单栏状态项控制器，负责展示聚合灯并在点击时打开设置窗口
 * @author 程序员阿鑫
 */
@MainActor
final class StatusItemController: NSObject {

    /**
     * 菜单栏状态项
     */
    private var statusItem: NSStatusItem?

    /**
     * 状态灯宿主视图
     */
    private var hostingView: StatusItemHostingView?

    /**
     * 状态灯宿主视图宽度约束
     */
    private var hostingViewWidthConstraint: NSLayoutConstraint?

    /**
     * 状态灯宿主视图高度约束
     */
    private var hostingViewHeightConstraint: NSLayoutConstraint?

    /**
     * 状态中心
     */
    private weak var statusCenter: StatusCenter?

    /**
     * 状态订阅集合
     */
    private var cancellables: Set<AnyCancellable> = []

    /**
     * 安装菜单栏状态项
     * @param statusCenter 状态中心
     */
    func install(statusCenter: StatusCenter) {
        self.statusCenter = statusCenter

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        guard let button = statusItem.button else {
            return
        }

        // 直接响应左键点击，打开独立设置窗口。
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp])
        button.title = ""
        button.image = nil

        let lamps = buildMenuBarLamps(from: statusCenter)
        let hostingView = StatusItemHostingView(
            rootView: MenuBarStatusLabel(lamps: lamps)
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        button.addSubview(hostingView)

        let widthConstraint = hostingView.widthAnchor.constraint(
            equalToConstant: MenuBarStatusLabel.preferredWidth(for: lamps.count)
        )
        let heightConstraint = hostingView.heightAnchor.constraint(equalToConstant: 18)
        self.hostingViewWidthConstraint = widthConstraint
        self.hostingViewHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            hostingView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            widthConstraint,
            heightConstraint
        ])

        self.hostingView = hostingView
        bindStatusCenter(statusCenter)
        refreshAppearance()
    }

    /**
     * 卸载菜单栏状态项
     */
    func uninstall() {
        cancellables.removeAll()

        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }

        hostingView = nil
        statusItem = nil
        statusCenter = nil
    }

    /**
     * 绑定状态中心变化
     * @param statusCenter 状态中心
     */
    private func bindStatusCenter(_ statusCenter: StatusCenter) {
        cancellables.removeAll()

        statusCenter.objectWillChange
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            // 等本轮状态写回完成后，再统一刷新菜单栏外观。
            DispatchQueue.main.async {
                self?.refreshAppearance()
            }
        }
        .store(in: &cancellables)
    }

    /**
     * 刷新菜单栏状态灯外观
     */
    private func refreshAppearance() {
        guard let statusCenter else {
            return
        }

        let lamps = buildMenuBarLamps(from: statusCenter)

        // 统一擦除为AnyView，保持宿主视图类型稳定，避免重新引入泛型宿主类。
        hostingView?.rootView = AnyView(MenuBarStatusLabel(lamps: lamps))
        hostingViewWidthConstraint?.constant = MenuBarStatusLabel.preferredWidth(for: lamps.count)
        statusItem?.length = MenuBarStatusLabel.preferredWidth(for: lamps.count) + 10
    }

    /**
     * 构建菜单栏状态灯列表，固定左侧Claude、右侧Codex
     * @param statusCenter 状态中心
     * @return 菜单栏灯列表
     */
    private func buildMenuBarLamps(from statusCenter: StatusCenter) -> [MenuBarAgentLamp] {
        var lamps: [MenuBarAgentLamp] = []

        if statusCenter.settings.isClaudeEnabled {
            let snapshot = statusCenter.latestSnapshot(for: .claude)
            lamps.append(
                MenuBarAgentLamp(
                    id: .claude,
                    agent: .claude,
                    lightColor: snapshot.lightColor,
                    isFault: statusCenter.settings.isFaultLightEnabled && snapshot.isFault
                )
            )
        }

        if statusCenter.settings.isCodexEnabled {
            let snapshot = statusCenter.latestSnapshot(for: .codex)
            lamps.append(
                MenuBarAgentLamp(
                    id: .codex,
                    agent: .codex,
                    lightColor: snapshot.lightColor,
                    isFault: statusCenter.settings.isFaultLightEnabled && snapshot.isFault
                )
            )
        }

        return lamps
    }

    /**
     * 点击菜单栏状态项后打开设置窗口
     */
    @objc
    private func handleStatusItemClick() {
        statusCenter?.openSettingsWindow()
    }
}
