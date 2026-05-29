//
//  CodexStatusProvider.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import Foundation

/**
 * Codex 本地状态采集器，负责解析 SQLite 状态库与 session JSONL
 * @author 程序员阿鑫
 */
struct CodexStatusProvider: AgentStatusProvider {

    /**
     * 最近有效事件窗口，只分析最后几条事件避免历史噪音干扰
     */
    private let recentEventWindowCount = 24

    /**
     * 活跃回合最大保活时长，覆盖思考和编辑文件等长耗时阶段
     */
    private let activeTurnGraceSeconds: TimeInterval = 90

    /**
     * Codex 状态数据库路径
     */
    private let stateDatabasePath = "~/.codex/state_5.sqlite"

    /**
     * Codex 会话索引路径
     */
    private let sessionIndexPath = "~/.codex/session_index.jsonl"

    /**
     * Codex 会话目录
     */
    private let sessionsDirectory = "~/.codex/sessions"

    /**
     * 活跃会话静默阈值，超过后视为结束
     */
    private let activeWindowSeconds: TimeInterval = 15

    /**
     * 正常结束静默阈值
     */
    private let idleWindowSeconds: TimeInterval = 120

    /**
     * 最近会话文件读取窗口
     */
    private let recentSessionLineCount = 400

    /**
     * 明确的外部接口或认证故障关键字
     */
    private let faultErrorKeywords = [
        "\"subtype\":\"api_error\"",
        "\"type\":\"error\"",
        "\"level\":\"error\"",
        "insufficient_quota",
        "insufficient quota",
        "authentication failed",
        "unauthorized",
        "rate limit",
        "rate_limit",
        "负载过高",
        "请求失败",
        "network error",
        "invalid_api_key"
    ]

    /**
     * 明确的通用失败关键字
     */
    private let failureKeywords = [
        "process exited with code 1",
        "process exited with code 2",
        "command failed",
        "apply patch failed",
        "error:",
        "\"subtype\":\"failed\"",
        "\"level\":\"error\"",
        "执行失败",
        "发生异常",
        "无法完成"
    ]

    /**
     * 明确的运行中事件关键字
     */
    private let runningKeywords = [
        "response.output_text.delta",
        "\"type\":\"function_call\"",
        "\"type\":\"reasoning\"",
        "\"type\":\"function_call_output\""
    ]

    /**
     * 明确的已结束事件关键字
     */
    private let completedKeywords = [
        "\"phase\":\"final_answer\"",
        "\"phase\":\"final\"",
        "\"event\":\"task_complete\"",
        "\"type\":\"task_complete\""
    ]

    /**
     * 读取 Codex 状态快照
     * @return 状态快照
     */
    func fetchStatus() async -> AgentStatusSnapshot {
        let latestThread = latestThreadRecord()
        let latestSessionFile = latestSessionFileURL(from: latestThread)

        guard let latestSessionFile else {
            return AgentStatusSnapshot(
                agent: .codex,
                lightColor: .gray,
                runtimeState: .unavailable,
                headline: "未发现Codex状态源",
                detail: "未读取到最近线程或会话文件",
                isFault: false,
                updatedAt: latestThread?.updatedAt,
                sourcePath: nil
            )
        }

        let recentLines = FileSystemUtilities.readLastLines(from: latestSessionFile, count: recentSessionLineCount)
        let modifiedAt = FileSystemUtilities.modificationDate(for: latestSessionFile) ?? latestThread?.updatedAt
        let allEvents = extractSessionEvents(from: recentLines)
        let activeTurnEvents = activeTurnEvents(from: allEvents)
        let recentEvents = latestRelevantEvents(from: activeTurnEvents.isEmpty ? allEvents : activeTurnEvents)
        let recentEventTexts = recentEvents.map(\.searchableText)
        let joinedText = recentEventTexts.joined(separator: "\n").lowercased()
        let latestStateEvent = recentEvents.last(where: { $0.stateMarker != .none })
        let now = Date()

        // 若最近一轮已经结束且没有新的 turn 开始，则应回到空闲态。
        if activeTurnEvents.isEmpty,
           latestStateEvent?.stateMarker == .completed,
           hasCompletedTurn(in: allEvents) {
            return AgentStatusSnapshot(
                agent: .codex,
                lightColor: .green,
                runtimeState: .idle,
                headline: latestThread?.title ?? "最近会话已结束",
                detail: "最近一轮任务已完成，当前无新任务执行",
                isFault: false,
                updatedAt: modifiedAt,
                sourcePath: latestSessionFile.path
            )
        }

        // 以最近一个明确状态事件作为最终判定，避免旧事件长期污染当前灯色。
        if let latestStateEvent,
           let modifiedAt {
            switch latestStateEvent.stateMarker {
            case .waitingUser:
                // 手动暂停与正常等待输入都归到黄灯常亮，但文案要区分清楚。
                let isManualPause = latestStateEvent.isTurnAborted
                return AgentStatusSnapshot(
                    agent: .codex,
                    lightColor: .yellow,
                    runtimeState: .waitingUser,
                    headline: isManualPause ? "任务已手动暂停" : "等待用户处理",
                    detail: isManualPause ? "最近一轮任务已被中断，当前不再继续呼吸闪烁" : "最近会话包含输入或确认请求",
                    isFault: false,
                    updatedAt: modifiedAt,
                    sourcePath: latestSessionFile.path
                )
            case .fault where now.timeIntervalSince(modifiedAt) <= idleWindowSeconds:
                return AgentStatusSnapshot(
                    agent: .codex,
                    lightColor: .red,
                    runtimeState: .failed,
                    headline: "Codex接口或令牌故障",
                    detail: "检测到API请求失败、认证异常或额度不足",
                    isFault: true,
                    updatedAt: modifiedAt,
                    sourcePath: latestSessionFile.path
                )
            case .failed where now.timeIntervalSince(modifiedAt) <= idleWindowSeconds:
                return AgentStatusSnapshot(
                    agent: .codex,
                    lightColor: .red,
                    runtimeState: .failed,
                    headline: "最近会话出现异常",
                    detail: "检测到Codex会话错误或命令失败信号",
                    isFault: false,
                    updatedAt: modifiedAt,
                    sourcePath: latestSessionFile.path
                )
            case .running where now.timeIntervalSince(modifiedAt) <= activeTurnGraceSeconds:
                return AgentStatusSnapshot(
                    agent: .codex,
                    lightColor: .yellow,
                    runtimeState: .running,
                    headline: latestThread?.title ?? "Codex任务运行中",
                    detail: "检测到最近会话仍在执行思考、工具调用或文件修改",
                    isFault: false,
                    updatedAt: modifiedAt,
                    sourcePath: latestSessionFile.path
                )
            case .running where now.timeIntervalSince(modifiedAt) <= activeWindowSeconds:
                return AgentStatusSnapshot(
                    agent: .codex,
                    lightColor: .yellow,
                    runtimeState: .running,
                    headline: latestThread?.title ?? "Codex任务运行中",
                    detail: "检测到最近会话仍在持续输出",
                    isFault: false,
                    updatedAt: modifiedAt,
                    sourcePath: latestSessionFile.path
                )
            case .completed, .none:
                break
            default:
                break
            }
        }

        if !activeTurnEvents.isEmpty,
           let modifiedAt,
           now.timeIntervalSince(modifiedAt) <= activeTurnGraceSeconds {
            // 回合尚未结束时，优先保持运行态，避免刚下发指令或长时间编辑时错误熄灯。
            return AgentStatusSnapshot(
                agent: .codex,
                lightColor: .yellow,
                runtimeState: .running,
                headline: latestThread?.title ?? "Codex任务运行中",
                detail: "检测到任务回合尚未结束，当前继续保活显示运行中",
                isFault: false,
                updatedAt: modifiedAt,
                sourcePath: latestSessionFile.path
            )
        }

        // 最近存在正常输出且没有新的活跃信号时，可视为空闲。
        if recentEvents.contains(where: { $0.indicatesCompleted })
            || containsAnyKeyword(in: joinedText, keywords: completedKeywords) {
            return AgentStatusSnapshot(
                agent: .codex,
                lightColor: .green,
                runtimeState: .idle,
                headline: latestThread?.title ?? "最近会话已结束",
                detail: "未检测到继续输出或等待用户信号",
                isFault: false,
                updatedAt: modifiedAt,
                sourcePath: latestSessionFile.path
            )
        }

        return AgentStatusSnapshot(
            agent: .codex,
            lightColor: .gray,
            runtimeState: .unavailable,
            headline: "Codex状态未明确",
            detail: "已读取会话文件，但未识别到明确状态",
            isFault: false,
            updatedAt: modifiedAt,
            sourcePath: latestSessionFile.path
        )
    }

    /**
     * 读取最近线程记录
     * @return 最近线程
     */
    private func latestThreadRecord() -> CodexThreadRecord? {
        let rows = SQLiteUtilities.query(
            databasePath: stateDatabasePath,
            sql: """
            select id, title, updated_at_ms, cwd
            from threads
            order by updated_at_ms desc
            limit 1;
            """
        )

        guard let row = rows.first else {
            return nil
        }

        return CodexThreadRecord(
            id: row["id"] ?? "",
            title: row["title"] ?? "Codex最近会话",
            updatedAt: millisecondsToDate(row["updated_at_ms"]),
            cwd: row["cwd"] ?? ""
        )
    }

    /**
     * 根据最近线程推导会话文件
     * @param latestThread 最近线程
     * @return 会话文件URL
     */
    private func latestSessionFileURL(from latestThread: CodexThreadRecord?) -> URL? {
        if let latestThread,
           let indexURL = newestSessionURLFromIndex(threadID: latestThread.id) {
            return indexURL
        }

        // 索引缺失时退回扫描 sessions 目录。
        return FileSystemUtilities.newestFile(
            in: sessionsDirectory,
            allowedExtensions: ["jsonl"]
        )
    }

    /**
     * 通过 session_index.jsonl 查找指定线程会话文件
     * @param threadID 线程ID
     * @return 文件URL
     */
    private func newestSessionURLFromIndex(threadID: String) -> URL? {
        let expandedIndexPath = FileSystemUtilities.expandTildePath(sessionIndexPath)
        guard let indexContent = try? String(contentsOfFile: expandedIndexPath, encoding: .utf8) else {
            return nil
        }

        let lines = indexContent
            .split(separator: "\n", omittingEmptySubsequences: true)
            .reversed()

        for line in lines {
            let components = line.split(separator: "|", omittingEmptySubsequences: false)
            guard components.count >= 2 else {
                continue
            }

            // 使用线程ID精确定位最近 rollout 文件。
            if String(components[0]) == threadID {
                let latestSessionURL = FileSystemUtilities.newestFile(
                    in: sessionsDirectory,
                    allowedExtensions: ["jsonl"],
                    nameContains: threadID
                )

                if let latestSessionURL {
                    return latestSessionURL
                }
            }
        }

        return nil
    }

    /**
     * 毫秒时间戳转日期
     * @param value 毫秒字符串
     * @return 日期
     */
    private func millisecondsToDate(_ value: String?) -> Date? {
        guard let value, let milliseconds = Double(value) else {
            return nil
        }

        return Date(timeIntervalSince1970: milliseconds / 1000.0)
    }

    /**
     * 判断文本中是否含有任一关键字
     * @param text 文本
     * @param keywords 关键字
     * @return 是否命中
     */
    private func containsAnyKeyword(in text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    /**
     * 提取最近几条有效事件
     * @param lines 原始行数组
     * @return 有效事件数组
     */
    private func extractSessionEvents(from lines: [String]) -> [CodexSessionEvent] {
        let allEvents = lines.compactMap(CodexSessionEvent.init(rawLine:))
            .filter { !$0.isIgnorable }

        return allEvents
    }

    /**
     * 获取用于最近状态判定的事件窗口
     * @param events 原始事件数组
     * @return 最近事件数组
     */
    private func latestRelevantEvents(from events: [CodexSessionEvent]) -> [CodexSessionEvent] {
        // 只保留尾部窗口参与最终判定，避免历史事件长期污染当前灯色。
        Array(events.suffix(recentEventWindowCount))
    }

    /**
     * 判断是否存在已完成且当前未继续的新一轮任务
     * @param events 原始事件数组
     * @return 是否已有完成回合
     */
    private func hasCompletedTurn(in events: [CodexSessionEvent]) -> Bool {
        events.lastIndex(where: { $0.isTurnComplete }) != nil
    }

    /**
     * 获取当前仍处于活跃状态的最近一轮事件
     * @param events 原始事件数组
     * @return 活跃回合事件数组
     */
    private func activeTurnEvents(from events: [CodexSessionEvent]) -> [CodexSessionEvent] {
        guard let lastTurnStartIndex = events.lastIndex(where: { $0.isTurnStart }) else {
            return []
        }

        if let lastTurnCompleteIndex = events.lastIndex(where: { $0.isTurnFinished }),
           lastTurnCompleteIndex > lastTurnStartIndex {
            return []
        }

        return Array(events.suffix(from: lastTurnStartIndex))
    }
}

/**
 * Codex 线程记录模型
 * @author 程序员阿鑫
 */
private struct CodexThreadRecord {
    /**
     * 线程ID
     */
    let id: String

    /**
     * 线程标题
     */
    let title: String

    /**
     * 最近更新时间
     */
    let updatedAt: Date?

    /**
     * 工作目录
     */
    let cwd: String
}

/**
 * Codex 会话事件模型，负责把 JSONL 解析为可判定状态的结构
 * @author 程序员阿鑫
 */
private struct CodexSessionEvent {

    /**
     * 状态标记枚举
     */
    enum StateMarker {
        case none
        case running
        case waitingUser
        case failed
        case fault
        case completed
    }

    /**
     * 顶层事件类型
     */
    let rootType: String

    /**
     * 载荷事件类型
     */
    let payloadType: String

    /**
     * 当前阶段
     */
    let phase: String

    /**
     * 顶层子类型
     */
    let subtype: String

    /**
     * 顶层日志级别
     */
    let level: String

    /**
     * 工具或事件名称
     */
    let name: String

    /**
     * 中断或结束原因
     */
    let reason: String

    /**
     * 角色
     */
    let role: String

    /**
     * 原始文本的小写形式
     */
    let searchableText: String

    /**
     * 使用原始 JSON 行构造事件
     * @param rawLine 原始日志行
     */
    nonisolated init?(rawLine: String) {
        guard let data = rawLine.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let payload = object["payload"] as? [String: Any]
        self.rootType = (object["type"] as? String ?? "").lowercased()
        self.payloadType = (payload?["type"] as? String ?? "").lowercased()
        self.phase = (payload?["phase"] as? String ?? "").lowercased()
        self.subtype = (object["subtype"] as? String ?? "").lowercased()
        self.level = (object["level"] as? String ?? "").lowercased()
        self.name = (payload?["name"] as? String ?? "").lowercased()
        self.reason = (payload?["reason"] as? String ?? "").lowercased()
        self.role = (payload?["role"] as? String ?? "").lowercased()
        self.searchableText = rawLine.lowercased()
    }

    /**
     * 是否属于可忽略噪音事件
     */
    var isIgnorable: Bool {
        payloadType == "token_count"
            || payloadType == "turn_context"
            || rootType == "session_meta"
            || rootType == "turn_context"
            || searchableText.contains("chunk id:")
    }

    /**
     * 是否为回合开始事件
     */
    var isTurnStart: Bool {
        payloadType == "task_started" || rootType == "event_msg" && payloadType == "task_started"
    }

    /**
     * 是否为回合完成事件
     */
    var isTurnComplete: Bool {
        payloadType == "task_complete"
    }

    /**
     * 是否为回合结束事件，包含正常结束与手动中断
     */
    var isTurnFinished: Bool {
        // 手动暂停会写入 turn_aborted/interrupted，需要和正常完成一样终止运行态保活。
        isTurnComplete || isTurnAborted
    }

    /**
     * 是否为手动中断或暂停导致的回合结束
     */
    var isTurnAborted: Bool {
        rootType == "event_msg"
            && payloadType == "turn_aborted"
            && (reason == "interrupted"
                || reason == "cancelled"
                || reason == "canceled"
                || reason == "aborted")
    }

    /**
     * 是否表示等待用户
     */
    var indicatesUserInputRequest: Bool {
        (payloadType == "custom_tool_call" && name == "request_user_input")
            || (payloadType == "function_call" && name == "request_user_input")
            || isTurnAborted
            || searchableText.contains("request_user_input")
    }

    /**
     * 是否表示外部接口故障
     */
    var indicatesFault: Bool {
        subtype == "api_error"
            || (rootType == "system" && level == "error")
    }

    /**
     * 是否表示普通失败
     */
    var indicatesFailure: Bool {
        searchableText.contains("exit code: 1")
            || searchableText.contains("exit code: 2")
            || searchableText.contains("process exited with code 1")
            || searchableText.contains("process exited with code 2")
            || searchableText.contains("\"subtype\":\"failed\"")
    }

    /**
     * 是否表示正在运行
     */
    var indicatesRunning: Bool {
        payloadType == "task_started"
            || payloadType == "function_call"
            || payloadType == "function_call_output"
            || payloadType == "agent_message"
            || payloadType == "reasoning"
            || rootType == "reasoning"
            || payloadType == "custom_tool_call_output"
            || (payloadType == "message" && phase == "commentary" && role == "assistant")
    }

    /**
     * 是否表示最近一次回合已完成
     */
    var indicatesCompleted: Bool {
        (payloadType == "message" && phase == "final_answer" && role == "assistant")
            || payloadType == "task_complete"
            || payloadType == "patch_apply_end"
    }

    /**
     * 当前事件可映射出的状态标记
     */
    var stateMarker: StateMarker {
        if indicatesFault {
            return .fault
        }
        if indicatesFailure {
            return .failed
        }
        if indicatesUserInputRequest {
            return .waitingUser
        }
        if indicatesCompleted {
            return .completed
        }
        if indicatesRunning {
            return .running
        }
        return .none
    }

}
