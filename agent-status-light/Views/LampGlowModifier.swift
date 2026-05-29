//
//  LampGlowModifier.swift
//  agent-status-light
//
//  Created by 高鑫 on 2026/5/27.
//

import SwiftUI

/**
 * 灯光效果修饰器，负责常亮、慢闪与快闪动效
 * @author 程序员阿鑫
 */
struct LampGlowModifier: ViewModifier {

    /**
     * 当前是否点亮
     */
    let isActive: Bool

    /**
     * 当前灯效行为
     */
    let behavior: LampBehavior

    /**
     * 当前灯基础色
     */
    let baseColor: Color

    /**
     * 动画状态
     */
    @State private var glowScale: CGFloat = 1.0

    /**
     * 呼吸透明度状态
     */
    @State private var animatedOpacity: Double = 1.0

    /**
     * 主辉光半径
     */
    @State private var primaryGlowRadius: CGFloat = 0

    /**
     * 主辉光透明度
     */
    @State private var primaryGlowOpacity: Double = 0

    /**
     * 外扩辉光半径
     */
    @State private var secondaryGlowRadius: CGFloat = 0

    /**
     * 外扩辉光透明度
     */
    @State private var secondaryGlowOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(glowScale)
            .opacity(animatedOpacity)
            // 第一层辉光贴近灯体，强调灯芯发亮的质感。
            .shadow(
                color: baseColor.opacity(primaryGlowOpacity),
                radius: primaryGlowRadius,
                x: 0,
                y: 0
            )
            // 第二层辉光向外扩散，形成更明显的氛围光晕。
            .shadow(
                color: baseColor.opacity(secondaryGlowOpacity),
                radius: secondaryGlowRadius,
                x: 0,
                y: 0
            )
            .onAppear {
                applyAnimation()
            }
            .onChange(of: isActive, perform: { _ in
                applyAnimation()
            })
            .onChange(of: behavior, perform: { _ in
                applyAnimation()
            })
    }

    /**
     * 应用对应灯效动画
     */
    private func applyAnimation() {
        guard isActive else {
            withAnimation(.easeOut(duration: 0.2)) {
                glowScale = 1.0
                animatedOpacity = 0.20
                primaryGlowRadius = 0
                primaryGlowOpacity = 0
                secondaryGlowRadius = 0
                secondaryGlowOpacity = 0
            }
            return
        }

        switch behavior {
        case .off, .solid:
            applyLitState(scale: 1.07,
                          opacity: 1.0,
                          primaryRadius: 14,
                          primaryOpacity: 0.42,
                          secondaryRadius: 24,
                          secondaryOpacity: 0.16)
        case .pulseSlow:
            applyLitState(scale: 1.08,
                          opacity: 1.0,
                          primaryRadius: 15,
                          primaryOpacity: 0.40,
                          secondaryRadius: 25,
                          secondaryOpacity: 0.16)
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowScale = 1.12
                animatedOpacity = 1.0
                primaryGlowRadius = 17
                primaryGlowOpacity = 0.44
                secondaryGlowRadius = 28
                secondaryGlowOpacity = 0.18
            }
        case .pulseFast:
            applyLitState(scale: 1.10,
                          opacity: 1.0,
                          primaryRadius: 17,
                          primaryOpacity: 0.44,
                          secondaryRadius: 28,
                          secondaryOpacity: 0.18)
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                glowScale = 1.15
                animatedOpacity = 1.0
                primaryGlowRadius = 20
                primaryGlowOpacity = 0.48
                secondaryGlowRadius = 32
                secondaryGlowOpacity = 0.22
            }
        }
    }

    /**
     * 先立即落到点亮基态，再让后续动画在此基础上继续变化
     * @param scale 基础缩放
     * @param opacity 基础透明度
     * @param primaryRadius 第一层辉光半径
     * @param primaryOpacity 第一层辉光透明度
     * @param secondaryRadius 第二层辉光半径
     * @param secondaryOpacity 第二层辉光透明度
     */
    private func applyLitState(scale: CGFloat,
                               opacity: Double,
                               primaryRadius: CGFloat,
                               primaryOpacity: Double,
                               secondaryRadius: CGFloat,
                               secondaryOpacity: Double) {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            glowScale = scale
            animatedOpacity = opacity
            primaryGlowRadius = primaryRadius
            primaryGlowOpacity = primaryOpacity
            secondaryGlowRadius = secondaryRadius
            secondaryGlowOpacity = secondaryOpacity
        }
    }
}
