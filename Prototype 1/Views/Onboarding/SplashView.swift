import SwiftUI

struct SplashView: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var logoOpacity   = 0.0
    @State private var taglineOffset = 20.0
    @State private var ctaOpacity    = 0.0

    var body: some View {
        ZStack {
            BPColor.amber900.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text("BLUePRiNT")
                    .font(BPFont.display(38, weight: .light))
                    .tracking(5)
                    .foregroundColor(BPColor.amber100)
                    .opacity(logoOpacity)

                Spacer().frame(height: 18)

                Text("\"I don't wait for opportunities.\nI manifest them into existence.\"")
                    .font(BPFont.body(14, weight: .light))
                    .italic()
                    .foregroundColor(BPColor.amber400)
                    .lineSpacing(5)
                    .offset(y: taglineOffset)
                    .opacity(logoOpacity)

                Spacer()

                VStack(spacing: 10) {
                    BPPrimaryButton("Start my canvas") { vm.advance() }
                        .background(BPColor.amber200)
                        .foregroundColor(BPColor.amber900)
                        .cornerRadius(BPRadius.button)

                    Text("No account needed to start")
                        .font(BPFont.caption)
                        .foregroundColor(BPColor.amber800)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .opacity(ctaOpacity)

                Spacer().frame(height: 48)
            }
            .bpScreenPadding()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7))              { logoOpacity = 1 }
            withAnimation(.easeOut(duration: 0.7).delay(0.15))  { taglineOffset = 0 }
            withAnimation(.easeOut(duration: 0.6).delay(0.55))  { ctaOpacity = 1 }
        }
    }
}
