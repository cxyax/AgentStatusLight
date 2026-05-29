//
//  StatusAlertService.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/28.
//

import AppKit
import AVFoundation
import Foundation
import UserNotifications

/**
 * 状态提醒服务，负责统一处理语音提醒与系统弹窗提醒
 * @author 程序员阿鑫
 */
@MainActor
final class StatusAlertService: NSObject, UNUserNotificationCenterDelegate {

    /**
     * 通知中心
     */
    private let notificationCenter = UNUserNotificationCenter.current()

    /**
     * 应用内弹窗控制器
     */
    private let popupController = StatusAlertPopupController()

    /**
     * 当前音频播放器
     */
    private var audioPlayer: AVAudioPlayer?

    /**
     * 是否已经完成首次状态基线初始化
     */
    private var hasInitializedAlertBaseline = false

    /**
     * 初始化提醒服务
     */
    override init() {
        super.init()

        // 让应用前台也能展示系统横幅提醒。
        notificationCenter.delegate = self
    }

    /**
     * 根据状态变化触发提醒
     * @param previousSnapshots 变化前快照
     * @param currentSnapshots 变化后快照
     * @param settings 当前设置
     */
    func notifyIfNeeded(previousSnapshots: [AgentStatusSnapshot],
                        currentSnapshots: [AgentStatusSnapshot],
                        settings: AgentLightSettings) {
        guard shouldNotify(previousSnapshots: previousSnapshots, currentSnapshots: currentSnapshots) else {
            return
        }

        let summary = alertSummary(from: currentSnapshots)

        // 语音提醒与弹窗提醒分开控制，互不影响。
        if settings.isVoiceAlertEnabled {
            playAudioAlert(audioPath: settings.alertAudioPath)
        }

        if settings.isPopupAlertEnabled {
            presentPopupAlert(summary: summary)
        }
    }

    /**
     * 请求弹窗提醒所需的通知权限
     */
    func requestPopupAuthorization() {
        requestNotificationAuthorizationIfNeeded { _ in
        }
    }

    /**
     * 前台展示通知时仍然显示横幅与声音
     * @param center 通知中心
     * @param notification 当前通知
     * @param completionHandler 展示回调
     */
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 保持应用在前台时也能看到横幅提醒。
        completionHandler([.banner, .list, .sound])
    }

    /**
     * 判断本轮刷新是否需要提醒
     * @param previousSnapshots 变化前快照
     * @param currentSnapshots 变化后快照
     * @return 是否需要提醒
     */
    private func shouldNotify(previousSnapshots: [AgentStatusSnapshot],
                              currentSnapshots: [AgentStatusSnapshot]) -> Bool {
        guard !currentSnapshots.isEmpty else {
            return false
        }

        guard hasInitializedAlertBaseline else {
            // 应用启动后的首轮状态仅用于建立基线，避免刚启动就触发提醒。
            hasInitializedAlertBaseline = true
            return false
        }

        let previousMap = Dictionary(uniqueKeysWithValues: previousSnapshots.map { ($0.agent, $0) })

        return currentSnapshots.contains { snapshot in
            guard let previousSnapshot = previousMap[snapshot.agent] else {
                // 新出现的Agent状态若此前没有基线，也不立即提醒，避免开关切换时造成误报。
                return false
            }

            // 仅在状态发生关键流转时提醒，避免重复播报相同状态。
            return shouldNotifyTransition(from: previousSnapshot, to: snapshot)
        }
    }

    /**
     * 判断单个Agent状态转场是否需要提醒
     * @param previousSnapshot 变化前快照
     * @param currentSnapshot 变化后快照
     * @return 是否需要提醒
     */
    private func shouldNotifyTransition(from previousSnapshot: AgentStatusSnapshot,
                                        to currentSnapshot: AgentStatusSnapshot) -> Bool {
        let previousAlertState = alertState(for: previousSnapshot)
        let currentAlertState = alertState(for: currentSnapshot)

        // 相同提醒态不重复触发，避免轮询刷新导致连续提示。
        guard previousAlertState != currentAlertState else {
            return false
        }

        guard let currentAlertState else {
            return false
        }

        switch currentAlertState {
        case .idle:
            // 仅当任务从运行/等待/异常态回落为空闲时，才视为“本轮已完成”。
            return previousAlertState != nil
        case .running, .waitingUser, .failed, .fault:
            return true
        }
    }

    /**
     * 申请本地通知权限
     */
    private func requestNotificationAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self else {
                completion(false)
                return
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                // 已授权时直接回调成功，避免重复拉起系统权限框。
                completion(true)
            case .notDetermined:
                // 首次使用时补齐系统授权申请。
                self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            case .denied:
                // 已被拒绝时直接走应用内弹窗兜底。
                completion(false)
            @unknown default:
                // 未知授权态按未授权处理，避免提醒链路中断。
                completion(false)
            }
        }
    }

    /**
     * 播放本地语音提醒
     * @param audioPath 音频路径
     */
    private func playAudioAlert(audioPath: String) {
        guard let audioURL = resolvedAudioURL(from: audioPath) else {
            NSSound.beep()
            return
        }

        do {
            // 每次状态变化都从头播放当前配置音频，保证提醒完整可感知。
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            NSSound.beep()
        }
    }

    /**
     * 将配置中的音频标识解析为实际可播放地址
     * @param audioPath 音频配置值
     * @return 音频地址
     */
    private func resolvedAudioURL(from audioPath: String) -> URL? {
        if audioPath == StatusAlertDefaults.defaultAudioPath {
            return bundledAudioURL()
        }

        let resolvedPath = FileSystemUtilities.expandTildePath(audioPath)
        if FileSystemUtilities.fileExists(at: resolvedPath) {
            return URL(fileURLWithPath: resolvedPath)
        }

        // 兼容旧配置中仍保存着历史文件名或绝对路径，但资源已改为内置音频的场景。
        if URL(fileURLWithPath: resolvedPath).lastPathComponent == StatusAlertDefaults.defaultAudioFileName {
            return bundledAudioURL()
        }

        return nil
    }

    /**
     * 获取内置默认提醒音频地址
     * @return 音频地址
     */
    private func bundledAudioURL() -> URL? {
        if let exactURL = Bundle.main.url(
            forResource: StatusAlertDefaults.defaultAudioResourceName,
            withExtension: "mp3",
            subdirectory: StatusAlertDefaults.defaultAudioSubdirectory
        ) {
            return exactURL
        }

        // 若资源被打平复制到Bundle根目录，则退回根目录查找。
        return Bundle.main.url(
            forResource: StatusAlertDefaults.defaultAudioResourceName,
            withExtension: "mp3"
        )
    }

    /**
     * 发送系统弹窗提醒
     * @param summary 提醒摘要
     */
    private func presentPopupAlert(summary: StatusAlertSummary) {
        requestNotificationAuthorizationIfNeeded { [weak self] isAuthorized in
            guard let self else {
                return
            }

            Task { @MainActor in
                // 应用当前处于前台时优先展示应用内弹窗，避免系统横幅被自身界面吞掉。
                if NSApplication.shared.isActive || !isAuthorized {
                    self.popupController.show(title: summary.title, body: summary.body)
                    return
                }

                // 应用在后台且拥有权限时继续沿用系统通知横幅。
                self.enqueueSystemNotification(summary: summary)
            }
        }
    }

    /**
     * 投递系统通知横幅
     * @param summary 提醒摘要
     */
    private func enqueueSystemNotification(summary: StatusAlertSummary) {
        let content = UNMutableNotificationContent()
        content.title = summary.title
        content.body = summary.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "agent-status-light.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        // 使用系统本地通知作为后台场景的轻量提醒。
        notificationCenter.add(request) { [weak self] error in
            guard let self, error != nil else {
                return
            }

            Task { @MainActor in
                // 系统通知投递失败时，立刻回退到应用内弹窗，避免本次提醒丢失。
                self.popupController.show(title: summary.title, body: summary.body)
            }
        }
    }

    /**
     * 生成提醒摘要
     * @param snapshots 当前快照
     * @return 提醒摘要
     */
    private func alertSummary(from snapshots: [AgentStatusSnapshot]) -> StatusAlertSummary {
        if let faultSnapshot = snapshots.first(where: { $0.isFault }) {
            return StatusAlertSummary(
                title: "\(faultSnapshot.agent.displayName)故障提醒",
                body: faultSnapshot.detail
            )
        }

        if let failedSnapshot = snapshots.first(where: { $0.runtimeState == .failed }) {
            return StatusAlertSummary(
                title: "\(failedSnapshot.agent.displayName)异常提醒",
                body: failedSnapshot.detail
            )
        }

        if let waitingSnapshot = snapshots.first(where: { $0.runtimeState == .waitingUser }) {
            return StatusAlertSummary(
                title: "\(waitingSnapshot.agent.displayName)等待处理",
                body: waitingSnapshot.detail
            )
        }

        if let runningSnapshot = snapshots.first(where: { $0.runtimeState == .running }) {
            return StatusAlertSummary(
                title: "\(runningSnapshot.agent.displayName)运行中",
                body: runningSnapshot.detail
            )
        }

        if let idleSnapshot = snapshots.first(where: { $0.runtimeState == .idle }) {
            return StatusAlertSummary(
                title: "\(idleSnapshot.agent.displayName)当前空闲",
                body: idleSnapshot.detail
            )
        }

        let fallbackSnapshot = snapshots.first ?? AgentStatusSnapshot.disabled(for: .claude)
        return StatusAlertSummary(
            title: "\(fallbackSnapshot.agent.displayName)状态更新",
            body: fallbackSnapshot.detail
        )
    }

    /**
     * 提取当前快照对应的提醒状态
     * @param snapshot 状态快照
     * @return 提醒状态
     */
    private func alertState(for snapshot: AgentStatusSnapshot) -> StatusAlertTriggerState? {
        if snapshot.isFault {
            return .fault
        }

        switch snapshot.runtimeState {
        case .idle:
            return .idle
        case .running:
            return .running
        case .failed:
            return .failed
        case .waitingUser:
            return .waitingUser
        case .unavailable, .disabled:
            return nil
        }
    }
}

/**
 * 状态提醒摘要
 * @author 程序员阿鑫
 */
private struct StatusAlertSummary {
    /**
     * 提醒标题
     */
    let title: String

    /**
     * 提醒正文
     */
    let body: String
}

/**
 * 需要触发提醒的高关注状态枚举
 * @author 程序员阿鑫
 */
private enum StatusAlertTriggerState: Equatable {
    /**
     * 当前空闲，代表上一轮任务已完成
     */
    case idle

    /**
     * 当前正在运行
     */
    case running

    /**
     * 外部故障
     */
    case fault

    /**
     * 任务失败
     */
    case failed

    /**
     * 等待用户处理
     */
    case waitingUser
}
