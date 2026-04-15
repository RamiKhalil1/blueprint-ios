import SwiftUI

struct ReflectionsView: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var currentAnswer = ""
    @FocusState private var isTextFocused: Bool

    private var question: String {
        vm.reflectionQuestions[vm.currentQuestionIndex]
    }

    private var progress: Double {
        Double(vm.currentQuestionIndex + 1) / Double(vm.reflectionQuestions.count)
    }

    var body: some View {
        ZStack {
            Color(hex: "#FAC775").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                HStack {
                    Text("Based on your board")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#633806"))

                    Spacer()

                    Button("Skip") { vm.skipReflectionQuestion() }
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#854F0B"))
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)

                Text("Q \(String(format: "%02d", vm.currentQuestionIndex + 1)) / \(String(format: "%02d", vm.reflectionQuestions.count))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#412402"))
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#412402"))
                            .frame(width: geo.size.width * progress, height: 3)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 0) {
                    Text(question)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: "#412402"))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color.white.opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                TextField("Write freely...", text: $currentAnswer, axis: .vertical)
                    .lineLimit(4...8)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#412402"))
                    .padding(14)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#BA7517").opacity(0.3), lineWidth: 0.5)
                    )
                    .focused($isTextFocused)
                    .padding(.horizontal, 24)

                Text("You can edit this later")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#854F0B"))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 24)
                    .padding(.top, 6)

                Spacer()

                Button {
                    isTextFocused = false
                    vm.submitReflectionAnswer(currentAnswer)
                    currentAnswer = ""
                } label: {
                    Text("Continue →")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#412402"))
                        .foregroundColor(Color(hex: "#FAEEDA"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .onChange(of: vm.currentQuestionIndex) { _, _ in
            currentAnswer = vm.reflectionAnswers[vm.currentQuestionIndex] ?? ""
        }
        .onAppear {
            currentAnswer = vm.reflectionAnswers[vm.currentQuestionIndex] ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFocused = true
            }
        }
    }
}
