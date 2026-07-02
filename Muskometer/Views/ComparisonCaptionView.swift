import SwiftUI

/// Displays a single fun comparison line beneath the combined gain card.
struct ComparisonCaptionView: View {
    let line: ComparisonLine?

    var body: some View {
        if let line {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: line.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, alignment: .center)
                    .padding(.top, 1)

                captionText(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(line.text)
        }
    }

    @ViewBuilder
    private func captionText(_ line: ComparisonLine) -> some View {
        if let highlight = line.highlight, !highlight.isEmpty, line.text.contains(highlight) {
            let parts = line.text.components(separatedBy: highlight)
            if parts.count == 2 {
                (
                    Text(parts[0])
                    + Text(highlight).fontWeight(.semibold).foregroundStyle(.primary)
                    + Text(parts[1])
                )
            } else {
                Text(line.text)
            }
        } else {
            Text(line.text)
        }
    }
}

#if DEBUG
struct ComparisonCaptionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ComparisonCaptionView(
                line: ComparisonLine(
                    text: "Today's gain equals 412,000 median US household incomes.",
                    highlight: "412,000",
                    systemImage: "person.3.fill"
                )
            )
            .previewDisplayName("With highlight")

            ComparisonCaptionView(
                line: ComparisonLine(
                    text: "Enough to fund a Falcon Heavy launch with change left over.",
                    systemImage: "airplane.departure"
                )
            )
            .previewDisplayName("Plain")

            ComparisonCaptionView(line: nil)
                .previewDisplayName("Hidden")
        }
        .padding()
        .frame(width: 328)
    }
}
#endif