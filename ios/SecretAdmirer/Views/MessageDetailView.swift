import SwiftUI

struct MessageDetailView: View {
    let message: Message
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.velvetNight.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("A secret note")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.whisper)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.dustyBlush)
                    }
                }
                ScrollView {
                    Text(message.body)
                        .foregroundStyle(Theme.whisper)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Theme.midnightPlum)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Text(message.receivedAt, format: .relative(presentation: .named))
                    .font(.footnote)
                    .foregroundStyle(Theme.dustyBlush)
                Spacer()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("Delete this note")
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(20)
        }
    }
}
