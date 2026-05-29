//
//  ClaudeStatusProvider.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import Foundation

/**
 * Claude 本地状态采集器，负责解析 todo 与项目会话文件
 * @author 程序员阿鑫
 */
struct ClaudeStatusProvider: AgentStatusProvider {

    /**
     * Claude todo 目录
     */
    private let todoDirectory = "~/.claude/todos"

    /**
     * Claude 项目会话目录
     */
    private let projectDirectory = "~/.claude/projects"

    /**
     * 最近异常判定窗口，避免历史错误长期污染灯色
     */
    private let recentFailureWindowSeconds: TimeInterval = 120

    /**
     * 最近 Claude 会话读取窗口
     */
    private let recentProjectLineCount = 120

    /**
     * 活跃回合保活阈值，覆盖 Claude 思考与工具处理阶段
     */
    private let activeTurnGraceSeconds: TimeInterval = 90

    /**
     * 读取 Claude 状态快照
     * @return 状态快照
     */
    func fetchStatus() async -> AgentStatusSnapshot {
        // 项目会话日志是当前最可靠的状态源，优先作为主判定依据。
        let projectSnapshot = snapshotFromProjectLogs()
        let todoSnapshot = snapshotFromTodoFiles()

        if let preferredSnapshot = preferredSnapshot(
            projectSnapshot: projectSnapshot,
            todoSnapshot: todoSnapshot
        ) {
            return preferredSnapshot
        }

        // 目录不存在或完全无可用数据时返回灰态。
        return AgentStatusSnapshot(
            agent: .claude,
            lightColor: .gray,
            runtimeState: .unavailable,
            headline: "未发现Claude状态源",
            detail: "未读取到todo或项目会话文件",
            isFault: false,
            updatedAt: nil,
            sourcePath: nil
        )
    }

    /**
     * 从 todo 文件推断状态
     * @return 状态快照
     */
    private func snapshotFromTodoFiles() -> AgentStatusSnapshot? {
        let newestTodoFiles = FileSystemUtilities.newestFiles(
            in: todoDirectory,
            allowedExtensions: ["json"],
            limit: 5
        )

        guard !newestTodoFiles.isEmpty else {
            return nil
        }

        for fileURL in newestTodoFiles {
            guard let items: [ClaudeTodoItem] = FileSystemUtilities.decodeJSON(from: fileURL, as: [ClaudeTodoItem].self) else {
                continue
            }

            let modifiedAt = FileSystemUtilities.modificationDate(for: fileURL)

            // 若存在进行中任务，则优先判定为运行中。
            if let inProgressItem = items.first(where: { $0.status == "in_progress" }) {
                return AgentStatusSnapshot(
                    agent: .claude,
                    lightColor: .yellow,
                    runtimeState: .running,
                    headline: inProgressItem.activeForm ?? inProgressItem.content,
                    detail: "最近Todo任务进行中",
                    isFault: false,
                    updatedAt: modifiedAt,
                    sourcePath: fileURL.path
                )
            }

            // 文件非空且全部完成时，可认为当前无活跃任务。
            if !items.isEmpty && items.allSatisfy({ $0.status == "completed" }) {
                return AgentStatusSnapshot(
                    agent: .claude,
                    lightColor: .green,
                    runtimeState: .idle,
                    headline: "最近Todo已完成",
                    detail: "暂无进行中的Claude任务",
                    isFault: false,
                    updatedAt: modifiedAt,
                    sourcePath: fileURL.path
                )
            }
        }

        return nil
    }

    /**
     * 从项目会话 JSONL 推断状态
     * @return 状态快照
     */
    private func snapshotFromProjectLogs() -> AgentStatusSnapshot? {
        let newestProjectFiles = FileSystemUtilities.newestFiles(
            in: projectDirectory,
            allowedExtensions: ["jsonl"],
            limit: 8
        )

        guard !newestProjectFiles.isEmpty else {
            return nil
        }

        let snapshots = newestProjectFiles.compactMap(snapshotFromProjectLog)
        return preferredProjectSnapshot(from: snapshots)
    }

    /**
     * 从单个项目会话 JSONL 推断状态
     * @param projectFile 会话文件URL
     * @return 状态快照
     */
    private func snapshotFromProjectLog(projectFile: URL) -> AgentStatusSnapshot? {
        let newestProjectFile = projectFile
        let recentLines = FileSystemUtilities.readLastLines(from: newestProjectFile, count: recentProjectLineCount)
        guard !recentLines.isEmpty else {
            return nil
        }

        let modifiedAt = FileSystemUtilities.modificationDate(for: newestProjectFile)
        let allEvents = extractEvents(from: recentLines)
        let activeTurnEvents = activeTurnEvents(from: allEvents)
        let recentEvents = latestRelevantEvents(from: activeTurnEvents.isEmpty ? allEvents : activeTurnEvents)
        let joinedText = recentEvents.map(\.searchableText).joined(separator: "\n").lowercased()
        let now = Date()

        // 最近出现等待输入相关调用时，判定为等待用户。
        if recentEvents.contains(where: { $0.indicatesUserInputRequest }) {
            return AgentStatusSnapshot(
                agent: .claude,
                lightColor: .yellow,
                runtimeState: .waitingUser,
                headline: "等待用户处理",
                detail: "最近会话包含用户输入或确认请求",
                isFault: false,
                updatedAt: modifiedAt,
                sourcePath: newestProjectFile.path
            )
        }

        // 令牌不足、接口失败或鉴权异常时，标记为故障灯场景。
        if let modifiedAt,
           now.timeIntervalSince(modifiedAt) <= recentFailureWindowSeconds,
           recentEvents.contains(where: { $0.indicatesFault }) {
            return AgentStatusSnapshot(
                agent: .claude,
                lightColor: .red,
                runtimeState: .failed,
                headline: "Claude接口或令牌故障",
                detail: "检测到API请求失败、认证异常或额度不足",
                isFault: true,
                updatedAt: modifiedAt,
                sourcePath: newestProjectFile.path
            )
        }

        // 最近会话若出现明确错误关键词，则标记为异常。
        if let modifiedAt,
           now.timeIntervalSince(modifiedAt) <= recentFailureWindowSeconds,
           recentEvents.contains(where: { $0.indicatesFailure }) {
            return AgentStatusSnapshot(
                agent: .claude,
                lightColor: .red,
                runtimeState: .failed,
                headline: "最近会话出现异常",
                detail: "检测到Claude会话错误或阻塞信号",
                isFault: false,
                updatedAt: modifiedAt,
                sourcePath: newestProjectFile.path
            )
        }

        if !activeTurnEvents.isEmpty,
           let modifiedAt,
           now.timeIntervalSince(modifiedAt) <= activeTurnGraceSeconds {
            // 最近一轮由用户发起且尚未被 turn_duration 收尾时，保持运行中。
            return AgentStatusSnapshot(
                agent: .claude,
                lightColor: .yellow,
                runtimeState: .running,
                headline: activeTurnEvents.last(where: { $0.isAssistantThinking })?.runningHeadline ?? "Claude任务运行中",
                detail: "检测到Claude仍在思考、处理或等待生成最终输出",
                isFault: false,
                updatedAt: modifiedAt,
                sourcePath: newestProjectFile.path
            )
        }

        // 最近存在 assistant 正常输出时，将其视为近期空闲。
        if recentEvents.contains(where: { $0.indicatesCompleted })
            || containsAnyKeyword(in: joinedText, keywords: ["\"subtype\":\"turn_duration\"", "\"type\":\"assistant\""]) {
            return AgentStatusSnapshot(
                agent: .claude,
                lightColor: .green,
                runtimeState: .idle,
                headline: "最近会话已结束",
                detail: "未检测到进行中或等待用户信号",
                isFault: false,
                updatedAt: modifiedAt,
                sourcePath: newestProjectFile.path
            )
        }

        return AgentStatusSnapshot(
            agent: .claude,
            lightColor: .gray,
            runtimeState: .unavailable,
            headline: "Claude状态未明确",
            detail: "已读取会话文件，但未识别到明确状态",
            isFault: false,
            updatedAt: modifiedAt,
            sourcePath: newestProjectFile.path
        )
    }

    /**
     * 选择最可信的 Claude 状态快照
     * @param projectSnapshot 项目日志快照
     * @param todoSnapshot Todo快照
     * @return 优先后的状态快照
     */
    private func preferredSnapshot(projectSnapshot: AgentStatusSnapshot?,
                                   todoSnapshot: AgentStatusSnapshot?) -> AgentStatusSnapshot? {
        if let projectSnapshot, projectSnapshot.runtimeState != .unavailable {
            // 项目日志已给出明确状态时，优先采用更贴近真实回合的日志结果。
            return projectSnapshot
        }

        if let todoSnapshot, todoSnapshot.runtimeState == .running {
            // 当日志未能识别，但 Todo 明确显示进行中时，保留运行态兜底。
            return todoSnapshot
        }

        if let projectSnapshot {
            return projectSnapshot
        }

        return todoSnapshot
    }

    /**
     * 从多个项目会话快照中选择最应展示的一条
     * @param snapshots 候选快照
     * @return 最优快照
     */
    private func preferredProjectSnapshot(from snapshots: [AgentStatusSnapshot]) -> AgentStatusSnapshot? {
        snapshots.max { left, right in
            let leftPriority = snapshotPriority(left)
            let rightPriority = snapshotPriority(right)

            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }

            return (left.updatedAt ?? .distantPast) < (right.updatedAt ?? .distantPast)
        }
    }

    /**
     * 计算状态快照优先级
     * @param snapshot 状态快照
     * @return 优先级数值，值越大越优先
     */
    private func snapshotPriority(_ snapshot: AgentStatusSnapshot) -> Int {
        switch snapshot.runtimeState {
        case .running:
            return 5
        case .waitingUser:
            return 4
        case .failed:
            return 3
        case .idle:
            return 2
        case .disabled:
            return 1
        case .unavailable:
            return 0
        }
    }

    /**
     * 判断文本中是否含有任一关键字
     * @param text 原始文本
     * @param keywords 关键字列表
     * @return 是否命中
     */
    private func containsAnyKeyword(in text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    /**
     * 提取最近可用于状态判断的 Claude 事件
     * @param lines 原始日志行
     * @return 事件数组
     */
    private func extractEvents(from lines: [String]) -> [ClaudeProjectEvent] {
        let events = lines.compactMap(ClaudeProjectEvent.init(rawLine:))
            .filter { !$0.isIgnorable }

        return events
    }

    /**
     * 提取最近可用于状态判断的 Claude 事件
     * @param events 原始事件数组
     * @return 事件数组
     */
    private func latestRelevantEvents(from events: [ClaudeProjectEvent]) -> [ClaudeProjectEvent] {
        Array(events.suffix(16))
    }

    /**
     * 获取当前仍处于活跃状态的最近一轮事件
     * @param events 原始事件数组
     * @return 活跃回合事件数组
     */
    private func activeTurnEvents(from events: [ClaudeProjectEvent]) -> [ClaudeProjectEvent] {
        guard let lastTurnStartIndex = events.lastIndex(where: { $0.isTurnStart }) else {
            return []
        }

        if let lastTurnCompleteIndex = events.lastIndex(where: { $0.isTurnComplete }),
           lastTurnCompleteIndex > lastTurnStartIndex {
            return []
        }

        // 截取从最近一轮用户输入开始到当前末尾的事件，识别仍在执行中的回合。
        return Array(events.suffix(from: lastTurnStartIndex))
    }
}

/**
 * Claude todo 项模型
 * @author 程序员阿鑫
 */
private struct ClaudeTodoItem: Decodable {
    /**
     * Todo 内容
     */
    let content: String

    /**
     * Todo 状态
     */
    let status: String

    /**
     * 当前动作描述
     */
    let activeForm: String?
}

/**
 * Claude 项目会话事件模型
 * @author 程序员阿鑫
 */
private struct ClaudeProjectEvent {

    /**
     * 顶层事件类型
     */
    let type: String

    /**
     * 子类型
     */
    let subtype: String

    /**
     * 日志级别
     */
    let level: String

    /**
     * 当前工作目录
     */
    let cwd: String

    /**
     * Assistant 内容块类型
     */
    let contentTypes: [String]

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

        self.type = (object["type"] as? String ?? "").lowercased()
        self.subtype = (object["subtype"] as? String ?? "").lowercased()
        self.level = (object["level"] as? String ?? "").lowercased()
        self.cwd = (object["cwd"] as? String ?? "").lowercased()
        self.contentTypes = ClaudeProjectEvent.extractContentTypes(from: object)
        self.searchableText = rawLine.lowercased()
    }

    /**
     * 从原始对象中提取 assistant 内容块类型
     * @param object 原始对象
     * @return 内容类型数组
     */
    nonisolated private static func extractContentTypes(from object: [String: Any]) -> [String] {
        guard
            let message = object["message"] as? [String: Any],
            let content = message["content"] as? [[String: Any]]
        else {
            return []
        }

        // 记录 content block 的 type，便于区分 thinking 与最终文本。
        return content.compactMap { item in
            (item["type"] as? String)?.lowercased()
        }
    }

    /**
     * 是否属于可忽略的元数据噪音
     */
    var isIgnorable: Bool {
        type == "permission-mode"
            || type == "file-history-snapshot"
            || type == "attachment"
            || type == "last-prompt"
    }

    /**
     * 是否表示等待用户
     */
    var indicatesUserInputRequest: Bool {
        searchableText.contains("request_user_input")
            || searchableText.contains("请确认")
            || searchableText.contains("等待用户")
            || searchableText.contains("是否继续")
    }

    /**
     * 是否表示外部接口故障
     */
    var indicatesFault: Bool {
        subtype == "api_error"
            || containsAnyKeyword(in: searchableText, keywords: [
                "insufficient quota",
                "insufficient_quota",
                "authentication failed",
                "unauthorized",
                "invalid_api_key",
                "余额不足",
                "模型负载过高"
            ])
    }

    /**
     * 是否表示普通失败
     */
    var indicatesFailure: Bool {
        level == "error"
            || containsAnyKeyword(in: searchableText, keywords: [
                "failed",
                "失败",
                "blocked",
                "无法"
            ])
    }

    /**
     * 是否表示任务完成
     */
    var indicatesCompleted: Bool {
        isTurnComplete
            || isAssistantFinalText
    }

    /**
     * 是否为回合开始事件
     */
    var isTurnStart: Bool {
        type == "user"
    }

    /**
     * 是否为回合完成事件
     */
    var isTurnComplete: Bool {
        type == "system" && subtype == "turn_duration"
    }

    /**
     * 是否为 assistant 思考阶段
     */
    var isAssistantThinking: Bool {
        type == "assistant" && contentTypes.contains("thinking")
    }

    /**
     * 是否为 assistant 最终文本输出
     */
    var isAssistantFinalText: Bool {
        type == "assistant" && contentTypes.contains("text")
    }

    /**
     * 运行中标题
     */
    var runningHeadline: String {
        if isAssistantThinking {
            return "Claude正在思考"
        }

        if type == "user" {
            return "Claude已收到新任务"
        }

        if cwd.isEmpty {
            return "Claude任务运行中"
        }

        return "Claude正在处理\(cwd)"
    }

    /**
     * 判断文本中是否命中关键字
     * @param text 原始文本
     * @param keywords 关键字列表
     * @return 是否命中
     */
    private func containsAnyKeyword(in text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }
}
