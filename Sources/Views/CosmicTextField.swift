import SwiftUI

struct CosmicTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.leading, 10)
            }
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.28))
                        .padding(.horizontal, icon != nil ? 0 : 10)
                }
                TextField("", text: $text)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, icon != nil ? 0 : 10)
                    .padding(.vertical, 13)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}
