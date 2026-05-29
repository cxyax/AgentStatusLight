//
//  FileSystemUtilities.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import Foundation
import Darwin

/**
 * 文件系统工具集合，负责目录扫描、JSONL读取与文件监听
 * @author 程序员阿鑫
 */
enum FileSystemUtilities {

    /**
     * 统一使用的文件管理器
     */
    private static let fileManager = FileManager.default

    /**
     * 展开用户目录中的波浪线路径
     * @param path 原始路径
     * @return 展开后的绝对路径
     */
    static func expandTildePath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    /**
     * 判断路径是否存在
     * @param path 待检查路径
     * @return 是否存在
     */
    static func fileExists(at path: String) -> Bool {
        fileManager.fileExists(atPath: expandTildePath(path))
    }

    /**
     * 获取目录下最近修改的文件
     * @param rootPath 根目录
     * @param allowedExtensions 允许的扩展名，为空表示不过滤
     * @return 最近修改文件URL
     */
    static func newestFile(in rootPath: String,
                           allowedExtensions: Set<String> = [],
                           nameContains: String? = nil) -> URL? {
        let expandedPath = expandTildePath(rootPath)
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: expandedPath),
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var newestURL: URL?
        var newestDate: Date?

        // 遍历目录，找到最近修改的目标文件。
        for case let fileURL as URL in enumerator {
            guard
                let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                resourceValues.isRegularFile == true
            else {
                continue
            }

            // 仅处理符合扩展名条件的文件。
            if !allowedExtensions.isEmpty && !allowedExtensions.contains(fileURL.pathExtension.lowercased()) {
                continue
            }

            // 按文件名子串过滤，优先帮助定位特定线程会话。
            if let nameContains, !fileURL.lastPathComponent.contains(nameContains) {
                continue
            }

            guard let modificationDate = resourceValues.contentModificationDate else {
                continue
            }

            if newestDate == nil || modificationDate > newestDate ?? .distantPast {
                newestDate = modificationDate
                newestURL = fileURL
            }
        }

        return newestURL
    }

    /**
     * 获取目录下最近修改的文件列表
     * @param rootPath 根目录
     * @param allowedExtensions 扩展名过滤
     * @param limit 返回数量
     * @return 按时间倒序的文件URL列表
     */
    static func newestFiles(in rootPath: String,
                            allowedExtensions: Set<String> = [],
                            limit: Int) -> [URL] {
        let expandedPath = expandTildePath(rootPath)
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: expandedPath),
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var candidates: [(url: URL, date: Date)] = []

        // 收集候选文件，后续按修改时间排序。
        for case let fileURL as URL in enumerator {
            guard
                let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                resourceValues.isRegularFile == true,
                let modificationDate = resourceValues.contentModificationDate
            else {
                continue
            }

            if !allowedExtensions.isEmpty && !allowedExtensions.contains(fileURL.pathExtension.lowercased()) {
                continue
            }

            candidates.append((url: fileURL, date: modificationDate))
        }

        return candidates
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map(\.url)
    }

    /**
     * 读取文件末尾指定数量的行
     * @param url 文件URL
     * @param count 行数
     * @return 文本行数组
     */
    static func readLastLines(from url: URL, count: Int) -> [String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        // 只取文件尾部窗口，避免大文件全量解析造成开销。
        return content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .suffix(count)
            .map(String.init)
    }

    /**
     * 读取 JSON 文件并解码
     * @param url 文件URL
     * @param type 目标类型
     * @return 解码结果
     */
    static func decodeJSON<T: Decodable>(from url: URL, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    /**
     * 获取文件修改时间
     * @param url 文件URL
     * @return 修改时间
     */
    static func modificationDate(for url: URL) -> Date? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else {
            return nil
        }

        return values.contentModificationDate
    }
}

/**
 * 目录监听器，负责在状态源变更时通知刷新
 * @author 程序员阿鑫
 */
final class DirectoryWatcher {

    /**
     * 被监听目录描述符
     */
    private var fileDescriptor: CInt = -1

    /**
     * GCD文件系统监听源
     */
    private var source: DispatchSourceFileSystemObject?

    /**
     * 监听目录URL
     */
    private let directoryURL: URL

    /**
     * 文件变化回调
     */
    private let onChange: @Sendable () -> Void

    /**
     * 构造目录监听器
     * @param directoryURL 目录URL
     * @param onChange 变化回调
     */
    init?(directoryURL: URL, onChange: @escaping @Sendable () -> Void) {
        self.directoryURL = directoryURL
        self.onChange = onChange

        // 只对存在的目录建立监听，避免无效描述符。
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return nil
        }

        // 以事件监听方式打开目录，降低轮询延迟。
        self.fileDescriptor = open(directoryURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            return nil
        }

        let queue = DispatchQueue(label: "org.cxyax.agent-status-light.watcher.\(UUID().uuidString)")
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: queue
        )

        // 文件变化后回调状态中心触发刷新。
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { [fileDescriptor] in
            if fileDescriptor >= 0 {
                close(fileDescriptor)
            }
        }

        self.source = source
        source.resume()
    }

    deinit {
        // 释放系统监听资源，避免描述符泄漏。
        source?.cancel()
        source = nil
    }
}
