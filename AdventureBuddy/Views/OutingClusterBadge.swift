import SwiftUI

struct OutingClusterBadge: View {
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(AdventureTheme.forest)
                    .frame(width: size, height: size)
                    .shadow(color: AdventureTheme.trail.opacity(0.35), radius: 5, y: 3)
                Circle()
                    .stroke(AdventureTheme.sand.opacity(0.9), lineWidth: 2)
                    .frame(width: size, height: size)
                Text(label)
                    .font(count > 9 ? .caption.weight(.bold) : .subheadline.weight(.bold))
                    .foregroundStyle(AdventureTheme.sand)
                    .minimumScaleFactor(0.7)
            }
            Image(systemName: "triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(AdventureTheme.forest)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) outings")
        .accessibilityHint("Zooms in or lists the outings in this group")
    }

    private var size: CGFloat {
        if count >= 100 { return 52 }
        if count >= 10 { return 46 }
        return 40
    }

    private var label: String {
        count > 99 ? "99+" : "\(count)"
    }
}

#Preview {
    ZStack {
        AdventureTheme.sand
        OutingClusterBadge(count: 12)
    }
}
