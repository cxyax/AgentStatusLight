//
//  AgentStatusProvider.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import Foundation

/**
 * Agent 状态采集协议，约束不同来源的状态读取能力
 * @author 程序员阿鑫
 */
protocol AgentStatusProvider: Sendable {

    /**
     * 读取当前 Agent 的状态快照
     * @return 状态快照
     */
    func fetchStatus() async -> AgentStatusSnapshot
}
