//
//  StatusLightRowView.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import SwiftUI

/**
 * 单个 Agent 状态灯行视图
 * @author 程序员阿鑫
 */
struct StatusLightRowView: View {

    /**
     * 当前状态快照
     */
    let snapshot: AgentStatusSnapshot

    /**
     * 当前主题色板
     */
    let palette: SharedTheme.Palette

    /**
     * 当前实际生效的颜色方案
     */
    let resolvedColorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(snapshot.lightColor.adaptiveColor(for: resolvedColorScheme))
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(palette.panelStroke, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(snapshot.agent.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.titleColor)

                    Text(snapshot.runtimeState.displayText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryTextColor)
                }

                Text(snapshot.headline)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.titleColor)
                    .lineLimit(1)

                Text(snapshot.detail)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.secondaryTextColor)
                    .lineLimit(2)

                Text("刷新于\(StatusFormatting.relativeTimeText(for: snapshot.updatedAt))")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.secondaryTextColor.opacity(0.85))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.panelFill)
        )
    }
}
