import SwiftUI

struct PriorityRankView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        ZStack {
            Color(hex: "#FAEEDA").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("What matters most right now?")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "#854F0B"))

                    Text("Drag to rank. Be honest, not aspirational.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#BA7517"))
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 28)

                List {
                    ForEach(Array(vm.rankedAreas.enumerated()), id: \.element) { index, area in
                        HStack(spacing: 16) {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#633806"))
                                .frame(width: 20)

                            Text(area.displayName)
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#412402"))

                            Spacer()

                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(Color(hex: "#BA7517").opacity(0.6))
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(
                            index == 0
                            ? Color(hex: "#FAC775")
                            : Color.white.opacity(0.5)
                        )
                    }
                    .onMove { source, destination in
                        vm.moveArea(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(maxHeight: 340)

                Spacer()

                Button { vm.saveRanking() } label: {
                    Text("This feels right →")
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
    }
}
