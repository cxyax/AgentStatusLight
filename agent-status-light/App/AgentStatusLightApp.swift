//
//  AgentStatusLightApp.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import AppKit
import SwiftUI

/**
 * 应用代理，负责初始化菜单栏状态项
 * @author 程序员阿鑫
 */
@MainActor
final class AgentStatusLightAppDelegate: NSObject, NSApplicationDelegate {

    /**
     * 状态中心，统一管理配置、刷新与状态聚合
     */
    let statusCenter = StatusCenter()

    /**
     * 菜单栏状态项控制器
     */
    private let statusItemController = StatusItemController()

    /**
     * 应用启动完成后安装菜单栏状态项
     * @param notification 启动通知
     */
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 启动后立即安装菜单栏状态项，并绑定到统一状态中心。
        statusItemController.install(statusCenter: statusCenter)
    }

    /**
     * 应用退出前清理菜单栏状态项
     * @param notification 退出通知
     */
    func applicationWillTerminate(_ notification: Notification) {
        // 退出前主动移除状态项，避免菜单栏残留无效引用。
        statusItemController.uninstall()
    }
}

/**
 * 应用入口，负责启动菜单栏状态灯应用
 * @author 程序员阿鑫
 */
@main
struct AgentStatusLightApp: App {

    /**
     * 应用代理
     */
    @NSApplicationDelegateAdaptor(AgentStatusLightAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
