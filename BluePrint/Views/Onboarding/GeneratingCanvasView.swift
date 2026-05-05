//
//  GeneratingCanvasView.swift
//  Prototype 1
//
//  Created by Rami Khalil on 20/4/2026.
//

import SwiftUI

struct GeneratingCanvasView: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var dotCount = 0
    @State private var pulseScale = 1.0
    @State private var dotTimer: Timer? = nil

    var body: some View {
        ZStack {
            Color(hex: "#412402").ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Animated logo
                ZStack {
                    Circle()
                        .fill(Color(hex: "#BA7517").opacity(0.15))
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: pulseScale
                        )

                    Image(systemName: "map.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#EF9F27"))
                }

                VStack(spacing: 12) {
                    Text("Building your Blueprint")
                        .font(.custom("Georgia", size: 24))
                        .foregroundColor(Color(hex: "#FAEEDA"))

                    Text(vm.generatingMessage)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "#BA7517"))
                        .animation(.easeInOut, value: vm.generatingMessage)
                        .multilineTextAlignment(.center)
                }

                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color(hex: "#BA7517").opacity(i == dotCount % 3 ? 1 : 0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: dotCount)
                    }
                }

                if let error = vm.errorMessage {
                    VStack(spacing: 12) {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.8))
                            .multilineTextAlignment(.center)

                        Button("Try again") {
                            vm.errorMessage = nil
                            Task { await vm.generateCanvas() }
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#FAEEDA"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#BA7517"))
                        .cornerRadius(10)
                    }
                }

                Spacer()

                Text("This usually takes 20-30 seconds")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#854F0B"))
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            pulseScale = 1.15
            dotTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                dotCount += 1
            }
        }
        .onDisappear {
            dotTimer?.invalidate()
            dotTimer = nil
        }
    }
}
