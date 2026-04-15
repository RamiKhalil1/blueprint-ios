import SwiftUI
import SwiftData

struct IncomeIntentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm: IncomeIntentViewModel

    init(modelContext: ModelContext) {
        _vm = StateObject(wrappedValue: IncomeIntentViewModel(modelContext: modelContext))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("Monthly income")
                        .font(BPFont.caption)
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("$")
                            .font(BPFont.display(30, weight: .light))
                            .foregroundColor(.secondary)
                        TextField("0", text: $vm.incomeInput)
                            .font(BPFont.display(40, weight: .light))
                            .keyboardType(.decimalPad)
                            .onChange(of: vm.incomeInput) { _, _ in vm.updateIncome() }
                    }

                    if vm.isOverAllocated {
                        Label("You've allocated more than 100%", systemImage: "exclamationmark.triangle.fill")
                            .font(BPFont.caption)
                            .foregroundColor(.red)
                    }
                }
                .bpScreenPadding()
                .padding(.top, 24)
                .padding(.bottom, 28)

                VStack(spacing: 0) {
                    ForEach($vm.allocations) { $alloc in
                        AllocationRow(allocation: $alloc, amount: vm.amount(for: alloc))
                        Divider().padding(.leading, BPSpacing.screenH)
                    }

                    HStack {
                        Text("Unallocated")
                            .font(BPFont.cardBody)
                            .foregroundColor(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(Int(vm.unallocatedAmount))")
                                .font(BPFont.body(15, weight: .medium))
                                .foregroundColor(vm.isOverAllocated ? .red : BPColor.amber400)
                            Text("\(Int(vm.unallocatedPercentage))%")
                                .font(BPFont.micro)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, BPSpacing.screenH)
                    .padding(.vertical, 14)
                }
                .background(Color(.systemBackground))
                .cornerRadius(BPRadius.card)
                .padding(.horizontal, 16)

                BPPrimaryButton(
                    "Save intent",
                    icon: vm.isSaved ? "checkmark" : nil,
                    isDisabled: vm.isOverAllocated
                ) { vm.save() }
                .bpScreenPadding()
                .padding(.top, 24)

                Text("Set this at the start of each month so your money has direction before it's spent.")
                    .font(BPFont.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .bpScreenPadding()
                    .padding(.top, 12)

                Spacer().frame(height: 48)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Income intent")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct AllocationRow: View {
    @Binding var allocation: IncomeAllocation
    let amount: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(allocation.areaType.displayName).font(BPFont.cardBody)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(Int(amount))").font(BPFont.body(15, weight: .medium))
                    Text("\(Int(allocation.percentage))%").font(BPFont.micro).foregroundColor(.secondary)
                }
            }
            Slider(value: $allocation.percentage, in: 0...60, step: 1)
                .tint(BPColor.amber400)
        }
        .padding(.horizontal, BPSpacing.screenH)
        .padding(.vertical, 12)
    }
}
