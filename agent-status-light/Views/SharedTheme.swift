//
//  SharedTheme.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import SwiftUI

/**
 * 共享主题工具，负责根据设置生成白天/夜晚配色
 * @author 程序员阿鑫
 */
enum SharedTheme {

    /**
     * 主题色板模型
     */
    struct Palette {
        let backgroundTop: Color
        let backgroundBottom: Color
        let panelFill: Color
        let panelStroke: Color
        let titleColor: Color
        let secondaryTextColor: Color
    }

    /**
     * 解析当前实际主题
     * @param mode 设置中的主题模式
     * @param colorScheme 系统颜色方案
     * @return 实际颜色方案
     */
    static func resolveColorScheme(for mode: DisplayThemeMode, colorScheme: ColorScheme) -> ColorScheme {
        switch mode {
        case .system:
            return colorScheme
        case .daylight:
            return .light
        case .night:
            return .dark
        }
    }

    /**
     * 生成主题色板
     * @param mode 设置中的主题模式
     * @param colorScheme 系统颜色方案
     * @return 色板
     */
    static func palette(for mode: DisplayThemeMode, colorScheme: ColorScheme) -> Palette {
        let resolvedScheme = resolveColorScheme(for: mode, colorScheme: colorScheme)

        if resolvedScheme == .dark {
            return Palette(
                backgroundTop: Color(red: 0.23, green: 0.24, blue: 0.27),
                backgroundBottom: Color(red: 0.16, green: 0.17, blue: 0.20),
                panelFill: Color.white.opacity(0.08),
                panelStroke: Color.white.opacity(0.12),
                titleColor: Color.white.opacity(0.96),
                secondaryTextColor: Color.white.opacity(0.72)
            )
        }

        return Palette(
            backgroundTop: Color(red: 0.98, green: 0.985, blue: 0.992),
            backgroundBottom: Color(red: 0.94, green: 0.955, blue: 0.972),
            panelFill: Color.white.opacity(0.86),
            panelStroke: Color.black.opacity(0.07),
            titleColor: Color.black.opacity(0.82),
            secondaryTextColor: Color.black.opacity(0.42)
        )
    }
}
