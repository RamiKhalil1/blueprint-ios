//
//  PhotoQuestionView.swift
//  Prototype 1
//
//  Created by Rami Khalil on 20/4/2026.
//

import SwiftUI

struct PhotoQuestionView: View {
    @ObservedObject var vm: OnboardingViewModel
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if vm.isLoadingQuestions {
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView().scaleEffect(1.3)
                    VStack(spacing: 8) {
                        Text("Thinking of the right questions...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Claude is analysing what this photo means to you")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
            } else if vm.currentQuestions.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Text("No questions generated.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    Button("Continue swiping →") {
                        vm.skipQuestions()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#FAEEDA"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#412402"))
                    .cornerRadius(12)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tell me more")
                                .font(.custom("Georgia", size: 26))
                            Text("Based on what you swiped, I want to understand you better.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineSpacing(3)
                        }
                        .padding(.top, 60)

                        ForEach(Array(vm.currentQuestions.enumerated()), id: \.offset) { index, question in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(question)
                                    .font(.system(size: 16, weight: .medium))
                                    .lineSpacing(3)

                                TextField(
                                    "Write freely...",
                                    text: index < vm.currentAnswers.count
                                        ? $vm.currentAnswers[index]
                                        : .constant(""),
                                    axis: .vertical
                                )
                                .lineLimit(3...6)
                                .font(.system(size: 15))
                                .padding(14)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            .padding(16)
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                        }

                        Text("You can edit this later")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        VStack(spacing: 12) {
                            Button {
                                vm.submitAnswers()
                            } label: {
                                Text("Continue →")
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color(hex: "#412402"))
                                    .foregroundColor(Color(hex: "#FAEEDA"))
                                    .cornerRadius(12)
                            }
                        }
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}
