import SwiftUI

struct LocationPermissionPrompt: View {
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(AdventureTheme.ember)
                    .frame(width: 72, height: 72)
                    .background(AdventureTheme.ember.opacity(0.16), in: Circle())

                VStack(spacing: 8) {
                    Text("See where you are")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AdventureTheme.forest)
                    Text("Adventure Buddy uses your location to center the journey map on you, so the places you go with your dog are easy to find again. Your location stays on this device.")
                        .font(.subheadline)
                        .foregroundStyle(AdventureTheme.trail)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button("Use my location", action: onAllow)
                        .font(.headline)
                        .foregroundStyle(AdventureTheme.sand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AdventureTheme.ember, in: Capsule())

                    Button("Not now", action: onNotNow)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AdventureTheme.trail)
                        .padding(.vertical, 4)
                }
            }
            .padding(24)
            .background(AdventureTheme.sand, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: AdventureTheme.trail.opacity(0.28), radius: 16, y: 8)
            .padding(.horizontal, 28)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    LocationPermissionPrompt(onAllow: {}, onNotNow: {})
}
