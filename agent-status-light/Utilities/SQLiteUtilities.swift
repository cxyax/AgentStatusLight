//
//  SQLiteUtilities.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import Foundation
import SQLite3

/**
 * SQLite 只读查询工具，负责读取 Codex 本地状态库
 * @author 程序员阿鑫
 */
enum SQLiteUtilities {

    /**
     * 执行只读查询并返回字符串字典数组
     * @param databasePath 数据库路径
     * @param query SQL语句
     * @return 查询结果
     */
    static func query(databasePath: String, sql: String) -> [[String: String]] {
        let expandedPath = FileSystemUtilities.expandTildePath(databasePath)
        var database: OpaquePointer?
        var results: [[String: String]] = []

        // 以只读模式打开数据库，避免对外部进程造成写入干扰。
        guard sqlite3_open_v2(expandedPath, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(database)
            return []
        }

        defer {
            sqlite3_close(database)
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return []
        }

        defer {
            sqlite3_finalize(statement)
        }

        // 遍历结果集并按列名生成字符串字典。
        while sqlite3_step(statement) == SQLITE_ROW {
            let columnCount = sqlite3_column_count(statement)
            var row: [String: String] = [:]

            for index in 0..<columnCount {
                guard let columnNamePointer = sqlite3_column_name(statement, index) else {
                    continue
                }

                let key = String(cString: columnNamePointer)

                if let valuePointer = sqlite3_column_text(statement, index) {
                    row[key] = String(cString: valuePointer)
                } else {
                    row[key] = nil
                }
            }

            results.append(row)
        }

        return results
    }
}
