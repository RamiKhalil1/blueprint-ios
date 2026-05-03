//
//  AddPhotoPromptView.swift
//  Prototype 1
//
//  Created by Rami Khalil on 20/4/2026.
//

import SwiftUI

struct AddPhotoPromptView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#FAEEDA"))
                            .frame(width: 80, height: 80)
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: "#BA7517"))
                    }

                    // Text
                    VStack(spacing: 10) {
                        Text("Almost there!")
                            .font(.custom("Georgia", size: 26))
                            .foregroundColor(.primary)

                        Text("You've swiped through all \(onboardingPhotos.count) photos. Want to add any of your own before we build your Blueprint?")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                    }

                    // Stats
                    HStack(spacing: 32) {
                        VStack(spacing: 4) {
                            Text("\(vm.likedCount)")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(Color(hex: "#BA7517"))
                            Text("liked")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        VStack(spacing: 4) {
                            Text("\(vm.dislikedCount)")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("disliked")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        VStack(spacing: 4) {
                            Text("\(vm.allAnswers.count)")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(Color(hex: "#1D9E75"))
                            Text("answers")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        vm.showCustomPhotoSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Add my own photo")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .foregroundColor(Color(hex: "#412402"))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#BA7517").opacity(0.4), lineWidth: 1)
                        )
                    }

                    Button {
                        vm.proceedToGenerate()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 16))
                            Text("Build my Blueprint")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#412402"))
                        .foregroundColor(Color(hex: "#FAEEDA"))
                        .cornerRadius(12)
                    }

                    Text("Your Blueprint is built from your swipes and answers")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $vm.showCustomPhotoSheet) {
            CustomPhotoSheet(vm: vm)
        }
    }
}
