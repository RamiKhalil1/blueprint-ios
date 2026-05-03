import SwiftUI
import SwiftData
import Combine

// MARK: - Claude Check-in View

struct ClaudeCheckInView: View {
    @StateObject private var vm: ClaudeCheckInViewModel
    @FocusState private var inputFocused: Bool

    init(modelContext: ModelContext) {
        _vm = StateObject(wrappedValue: ClaudeCheckInViewModel(modelContext: modelContext))
    }

    var body: some View {
        ZStack {
            Color(hex: "#120D05").ignoresSafeArea()

            VStack(spacing: 0) {
                canvasBanner

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if vm.isLoading {
                                TypingIndicator().id("typing")
                            }

                            if vm.isAtLimit {
                                limitNotice.id("limit")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        withAnimation {
                            if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: vm.isLoading) { _, loading in
                        if loading {
                            withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                        }
                    }
                }

                // Error banner
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(Color.red.opacity(0.75))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                }

                // Input bar (hidden when at limit)
                if !vm.isAtLimit {
                    inputBar
                }
            }
        }
        .navigationTitle("Check in with Claude")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#120D05"), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onTapGesture { inputFocused = false }
    }

    // MARK: - Canvas areas banner

    private var canvasBanner: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#BA7517"))

                ForEach(vm.lifeAreas) { area in
                    Text("\(area.emoji) \(area.name)")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.07))
                        .foregroundColor(.white.opacity(0.5))
                        .cornerRadius(20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("What's on your mind?", text: $vm.inputText, axis: .vertical)
                .lineLimit(1...5)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .tint(Color(hex: "#BA7517"))
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(22)

            Button {
                vm.send()
                inputFocused = false
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(vm.canSend ? Color(hex: "#BA7517") : Color.white.opacity(0.18))
            }
            .disabled(!vm.canSend)
            .animation(.easeInOut(duration: 0.2), value: vm.canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "#1A1208"))
    }

    // MARK: - Limit notice

    private var limitNotice: some View {
        Text("You've had 6 exchanges this session — come back anytime to start fresh.")
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.3))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: CheckInMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 52) }

            // Blueprint avatar (Claude side only)
            if !isUser {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#BA7517").opacity(0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: "map.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#BA7517"))
                }
                .alignmentGuide(.bottom) { d in d[.bottom] }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 5) {
                Text(message.content)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(isUser ? Color(hex: "#1A1208") : .white.opacity(0.88))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(isUser ? Color(hex: "#BA7517") : Color.white.opacity(0.09))
                    .cornerRadius(18)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.22))
            }

            if !isUser { Spacer(minLength: 52) }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var activeIndex = 0

    // Timer published on main thread for animation cycling.
    let timer = Timer.publish(every: 0.38, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Blueprint avatar
            ZStack {
                Circle()
                    .fill(Color(hex: "#BA7517").opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: "map.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#BA7517"))
            }

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(activeIndex == i ? 0.78 : 0.22))
                        .frame(width: 7, height: 7)
                        .scaleEffect(activeIndex == i ? 1.25 : 1.0)
                        .animation(.easeInOut(duration: 0.28), value: activeIndex)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.09))
            .cornerRadius(18)

            Spacer(minLength: 52)
        }
        .padding(.horizontal, 2)
        .onReceive(timer) { _ in
            activeIndex = (activeIndex + 1) % 3
        }
    }
}
