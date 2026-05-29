//
//  MenuBarStatusLabel.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import SwiftUI

/**
 * 菜单栏单个Agent灯展示模型
 * @author 程序员阿鑫
 */
struct MenuBarAgentLamp: Identifiable {

    /**
     * 唯一标识
     */
    let id: AgentKind

    /**
     * 对应的Agent类型
     */
    let agent: AgentKind

    /**
     * 当前灯颜色
     */
    let lightColor: LightColor

    /**
     * 是否为故障态
     */
    let isFault: Bool
}

/**
 * 菜单栏状态标签视图，按 Claude 与 Codex 分别展示状态灯
 * @author 程序员阿鑫
 */
struct MenuBarStatusLabel: View {

    /**
     * 当前需要展示的Agent灯列表
     */
    let lamps: [MenuBarAgentLamp]

    /**
     * 当前系统颜色方案
     */
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(lamps) { lamp in
                lampView(for: lamp)
            }
        }
        .frame(height: 18)
        .fixedSize()
    }

    /**
     * 计算菜单栏推荐宽度
     * @param lampCount 当前灯数量
     * @return 推荐宽度
     */
    static func preferredWidth(for lampCount: Int) -> CGFloat {
        switch lampCount {
        case ...0:
            return 18
        case 1:
            return 18
        default:
            return 34
        }
    }

    /**
     * 生成单盏菜单栏状态灯
     * @param lamp 菜单栏灯模型
     * @return 视图
     */
    private func lampView(for lamp: MenuBarAgentLamp) -> some View {
        let activeColor = resolvedColor(for: lamp)
        let isDimmed = lamp.lightColor == .gray && !lamp.isFault

        return ZStack {
            Circle()
                .fill(shellColor)
                .frame(width: 15, height: 15)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.20), lineWidth: 0.7)
                )

            Circle()
                .fill(activeColor.opacity(isDimmed ? 0.28 : 0.98))
                .frame(width: 10, height: 10)
                .shadow(color: activeColor.opacity(isDimmed ? 0.0 : 0.42), radius: 2.2, x: 0, y: 0.6)
        }
    }

    /**
     * 解析单盏灯的实际颜色
     * @param lamp 菜单栏灯模型
     * @return 展示颜色
     */
    private func resolvedColor(for lamp: MenuBarAgentLamp) -> Color {
        if lamp.isFault {
            // 外部故障优先映射成红灯，保持顶部栏的告警感知一致。
            return LightColor.red.adaptiveColor(for: colorScheme)
        }

        switch lamp.lightColor {
        case .red, .yellow, .green, .gray:
            return lamp.lightColor.adaptiveColor(for: colorScheme)
        case .fault:
            return LightColor.red.adaptiveColor(for: colorScheme)
        }
    }

    /**
     * 灯座外壳颜色
     */
    private var shellColor: Color {
        Color.white.opacity(0.10)
    }
}
