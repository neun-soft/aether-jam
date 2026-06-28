import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        GeometryReader { geo in
            // Reproduce the 393×852 mock canvas, scaled uniformly into the device's safe area.
            // Measured once here at the window root (reliable, unlike a GeometryReader inside
            // a NavigationStack destination). Passed down so every screen scales identically.
            let scale = min(geo.size.width / DesignCanvas.width,
                            geo.size.height / DesignCanvas.height)
            NavigationStack(path: $store.path) {
                Group {
                    if store.hasStarted {
                        StackHubScreen()
                    } else {
                        StartScreen()
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .track(let id):
                        switch store.track(id)?.role {
                        case .bass:   BassInsideScreen(trackID: id)
                        case .chords: ChordsInsideScreen(trackID: id)
                        case .drums:  DrumsInsideScreen(trackID: id)
                        case .lead:   LeadJamScreen(trackID: id)
                        case .none:   EmptyView()
                        }
                    case .synthEditor(let id): SynthEditorScreen(trackID: id)
                    case .mySounds:            MySoundsScreen()
                    case .addInstrument:       MySoundsScreen(addMode: true)
                    }
                }
            }
            .environment(\.canvasScale, scale)
            .tint(Theme.textPrimary)
        }
    }
}

// MARK: - Canvas scale environment

private struct CanvasScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}
extension EnvironmentValues {
    var canvasScale: CGFloat {
        get { self[CanvasScaleKey.self] }
        set { self[CanvasScaleKey.self] = newValue }
    }
}

enum DesignCanvas {
    static let width: CGFloat = 393
    static let height: CGFloat = 852
}

// MARK: - Shared screen chrome (393×852 canvas scaled to fit, hidden nav bar)

private struct ScreenChrome: ViewModifier {
    @Environment(\.canvasScale) private var scale

    func body(content: Content) -> some View {
        content
            .frame(width: DesignCanvas.width, height: DesignCanvas.height, alignment: .top)
            .scaleEffect(scale, anchor: .top)
            .frame(width: DesignCanvas.width * scale, height: DesignCanvas.height * scale, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.bgGradient.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
    }
}

extension View {
    func screen() -> some View { modifier(ScreenChrome()) }
}

// MARK: - Small shared header pieces

struct ScreenHeader<Leading: View, Trailing: View>: View {
    var eyebrowColor: Color
    var title: String
    var titleColor: Color
    var subtitle: String
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).ui(17, .semibold).foregroundStyle(titleColor)
                    .tracking(0.4)
                Text(subtitle).mono(11).foregroundStyle(Theme.textDim)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}
