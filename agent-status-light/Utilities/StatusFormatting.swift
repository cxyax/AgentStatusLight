//
//  StatusFormatting.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import Foundation

/**
 * 状态展示格式化工具
 * @author 程序员阿鑫
 */
enum StatusFormatting {

    /**
     * 相对时间格式化器
     */
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    /**
     * 将日期格式化为相对时间文本
     * @param date 日期
     * @return 文本结果
     */
    static func relativeTimeText(for date: Date?) -> String {
        guard let date else {
            return "暂无刷新时间"
        }

        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
