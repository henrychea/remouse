import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    var ink: NSColor { NSColor(self) }
}

enum Palette {
    static let primary = Color(hex: 0x4DA8FF)
    static let onPrimary = Color(hex: 0x001C38)
    static let primaryContainer = Color(hex: 0x0B243D)
    static let secondary = Color(hex: 0x90ADD6)
    static let warning = Color(hex: 0xFFB800)
    static let onWarning = Color(hex: 0x1F1400)
    static let warningContainer = Color(hex: 0x2A1E00)
    static let onWarningContainer = Color(hex: 0xFFD15C)
    static let error = Color(hex: 0xFF5449)
    static let onError = Color(hex: 0x410002)
    static let surface = Color(hex: 0x0A0A0A)
    static let surfaceLowest = Color(hex: 0x060607)
    static let surfaceLow = Color(hex: 0x121214)
    static let surfaceContainer = Color(hex: 0x18181B)
    static let surfaceHigh = Color(hex: 0x222226)
    static let surfaceHighest = Color(hex: 0x2C2C32)
    static let onSurface = Color(hex: 0xF0F0F2)
    static let onSurfaceVariant = Color(hex: 0x94949E)
    static let outline = Color(hex: 0x46464F)
    static let outlineVariant = Color(hex: 0x26262C)
    static let ledIdle = Color(hex: 0x222228)
    static let bodyLit = Color(hex: 0xE4FFF4)
    static let bodyDim = Color(hex: 0x52525B)
    static let seamDim = Color(hex: 0x3E3E44)
}

@MainActor
final class ConflictStore: ObservableObject {
    static let shared = ConflictStore()

    @Published private(set) var conflicts: [Conflict] = []

    func refresh() {
        conflicts = ConflictChecker.runningConflicts()
    }
}

enum Radius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
}

enum Gap {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Typo {
    static func title() -> Font { doto(16) }
    static func labelLarge() -> Font { doto(14, semibold: true) }
    static func labelMedium() -> Font { doto(12, semibold: true) }
    static func labelSmall() -> Font { doto(11, semibold: true) }
    static func bodySmall() -> Font { .system(size: 12) }
    static func bodyMedium() -> Font { .system(size: 13, weight: .medium) }
    static func caption() -> Font { .system(size: 11, weight: .medium) }

    static func doto(_ size: CGFloat, semibold: Bool = false) -> Font {
        let name = semibold ? "Doto-Black_SemiBold" : "Doto-Black_Bold"
        return Font(NSFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: semibold ? .semibold : .bold))
    }
}

struct DotGrid: View {
    var spacing: CGFloat = 8
    var opacity: Double = 0.06

    var body: some View {
        Canvas { context, size in
            let color = Color.white.opacity(opacity)
            var row = spacing / 2
            while row < size.height {
                var column = spacing / 2
                while column < size.width {
                    context.fill(
                        Path(ellipseIn: CGRect(x: column - 1, y: row - 1, width: 2, height: 2)),
                        with: .color(color)
                    )
                    column += spacing
                }
                row += spacing
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct Scanline: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = -48

    var body: some View {
        if !reduceMotion {
            LinearGradient(
                colors: [.clear, Palette.primary.opacity(0.05), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 48)
            .offset(y: offset)
            .onAppear {
                withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: false)) {
                    offset = 106
                }
            }
        }
    }
}

private struct WindowFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 360, height: 420)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(Palette.outlineVariant, lineWidth: 1)
            }
    }
}

struct MainWindowView: View {
    let permission: PermissionState
    var conflicts: [Conflict] = []
    var onQuit: (Conflict) -> Void = { _ in }

    @AppStorage(SettingsKeys.invertEnabled) private var invertEnabled = true
    @AppStorage(SettingsKeys.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(SettingsKeys.showInDock) private var showInDock = false
    @AppStorage(SettingsKeys.launchAtLogin) private var launchAtLogin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ripple: DotMatrix.Ripple?
    @State private var dismissed: Set<String> = []
    @State private var bannerExpanded = true

    private var visibleConflicts: [Conflict] {
        conflicts.filter { !dismissed.contains($0.name) }
    }

    private var circleSize: CGFloat {
        if visibleConflicts.isEmpty { return 144 }
        return visibleConflicts.count < 3 ? 128 : 96
    }

    private var matrixHeight: CGFloat {
        if visibleConflicts.isEmpty { return 104 }
        return visibleConflicts.count < 3 ? 94 : 72
    }

    var body: some View {
        ZStack {
            Palette.surface
            DotGrid()
                .opacity(0.8)
            Scanline()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .frame(height: 96, alignment: .top)
                .clipped()

            VStack(spacing: 0) {
                header
                if permission.isGranted {
                    if !visibleConflicts.isEmpty {
                        ConflictBanner(conflicts: visibleConflicts, expanded: $bannerExpanded, onQuit: quit)
                    }
                    stage
                    footer
                } else {
                    permissionStage
                }
                strip
            }
        }
        .modifier(WindowFrame())
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text("re:Mouse")
                .font(Typo.title())
                .tracking(1.6)
                .foregroundStyle(Palette.onSurface)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Gap.md)
        .padding(.top, Gap.md)
        .padding(.bottom, Gap.xs)
    }

    private var stage: some View {
        VStack(spacing: visibleConflicts.isEmpty ? Gap.md : Gap.sm) {
            ZStack {
                Circle()
                    .fill(Palette.surfaceLow)
                Circle()
                    .strokeBorder(Palette.outlineVariant, lineWidth: 1)
                DotMatrix(glyph: .mouse, inverted: invertEnabled, height: matrixHeight, ripple: ripple)
            }
            .frame(width: circleSize, height: circleSize)

            invertPill
            statusLine
        }
        .padding(.horizontal, Gap.lg)
        .padding(.vertical, visibleConflicts.isEmpty ? Gap.sm : Gap.xs)
        .frame(maxHeight: .infinity)
    }

    private var invertPill: some View {
        Button(action: toggleInvert) {
            HStack(spacing: Gap.sm) {
                Text("INVERT SCROLL")
                    .font(Typo.labelLarge())
                    .tracking(1.4)
                    .foregroundStyle(invertEnabled ? Palette.primary : Palette.onSurfaceVariant)
                    .fixedSize()
                Spacer(minLength: Gap.md)
                Capsule()
                    .fill(invertEnabled ? Palette.primary : Palette.surfaceHighest)
                    .frame(width: 36, height: 20)
                    .overlay {
                        Circle()
                            .fill(invertEnabled ? Palette.onPrimary : Palette.onSurfaceVariant)
                            .frame(width: 16, height: 16)
                            .offset(x: invertEnabled ? 8 : -8)
                    }
            }
            .padding(.horizontal, Gap.md)
            .padding(.vertical, Gap.sm)
            .frame(minWidth: 224)
            .background {
                Capsule().fill(invertEnabled ? Palette.primaryContainer : Palette.surfaceContainer)
            }
            .overlay {
                Capsule().strokeBorder(invertEnabled ? Palette.primary : Palette.outlineVariant, lineWidth: 1)
            }
            .shadow(color: invertEnabled ? Palette.primary.opacity(0.24) : .clear, radius: 22)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Invert scroll")
        .accessibilityValue(invertEnabled ? "On" : "Off")
    }

    private var statusLine: some View {
        Text(statusText)
            .font(Typo.labelMedium())
            .tracking(1)
            .foregroundStyle(invertEnabled ? Palette.primary : Palette.onSurfaceVariant)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private var statusText: String {
        return invertEnabled ? "MOUSE: INVERTED · TRACKPAD: UNTOUCHED" : "MOUSE: STANDARD · TRACKPAD: UNTOUCHED"
    }

    private var footer: some View {
        HStack(alignment: .bottom, spacing: Gap.sm) {
            VStack(alignment: .leading, spacing: Gap.xs) {
                HStack(spacing: Gap.md) {
                    switchRow("Show in menu bar", isOn: $showMenuBarIcon)
                    switchRow("Show in Dock", isOn: dockBinding)
                }
                switchRow("Launch at login", isOn: loginBinding)
            }
            Spacer(minLength: 0)
            quitPill
        }
        .padding(.horizontal, Gap.md)
        .padding(.vertical, Gap.sm)
        .background(Palette.surfaceLow)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.outlineVariant).frame(height: 1)
        }
    }

    private var permissionStage: some View {
        VStack(spacing: Gap.lg) {
            ZStack {
                Circle()
                    .fill(Palette.surfaceLow)
                Circle()
                    .strokeBorder(Palette.outlineVariant, lineWidth: 1)
                DotMatrix(glyph: .lock, inverted: false, height: 92)
            }
            .frame(width: 144, height: 144)

            Text("NEEDS ACCESSIBILITY ACCESS")
                .font(Typo.title())
                .tracking(1.6)
                .foregroundStyle(Palette.onSurface)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("OPEN SETTINGS")
                    .font(Typo.labelLarge())
                    .tracking(1.4)
                    .foregroundStyle(Palette.onPrimary)
                    .padding(.horizontal, Gap.xl)
                    .padding(.vertical, Gap.md)
                    .background(Capsule().fill(Palette.primary))
                    .shadow(color: Palette.primary.opacity(0.3), radius: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Gap.lg)
        .padding(.vertical, Gap.xl)
        .frame(maxHeight: .infinity)
    }

    private var strip: some View {
        HStack(spacing: Gap.sm) {
            Button {
                if let url = URL(string: "https://github.com/henrychea/reMouse") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: Gap.xs) {
                    DotGlyph()
                    Text("GITHUB.COM/HENRYCHEA/REMOUSE")
                        .font(Typo.labelSmall())
                        .tracking(1)
                        .foregroundStyle(Palette.primary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open the re:Mouse GitHub repository")

            Spacer(minLength: 0)

            Text("MIT")
                .font(Typo.labelSmall())
                .tracking(1.4)
                .foregroundStyle(Palette.primary)
                .padding(.horizontal, Gap.xs)
                .padding(.vertical, 2)
                .background(Capsule().fill(Palette.surfaceContainer))
                .overlay(Capsule().strokeBorder(Palette.outlineVariant, lineWidth: 1))
        }
        .padding(.horizontal, Gap.md)
        .padding(.vertical, Gap.xs)
        .background(Palette.surfaceLowest.opacity(0.8))
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.outlineVariant).frame(height: 1)
        }
    }

    private var quitPill: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            Text("QUIT")
                .font(Typo.labelSmall())
                .tracking(1.4)
                .foregroundStyle(Palette.error)
                .padding(.horizontal, Gap.sm)
                .padding(.vertical, 2)
                .background(Capsule().fill(Palette.error.opacity(0.1)))
                .overlay(Capsule().strokeBorder(Palette.error.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func switchRow(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: Gap.xs) {
                Text(label)
                    .font(Typo.caption())
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .fixedSize()
                Capsule()
                    .fill(isOn.wrappedValue ? Palette.primaryContainer : Palette.surfaceHighest)
                    .frame(width: 28, height: 16)
                    .overlay {
                        Circle()
                            .fill(isOn.wrappedValue ? Palette.primary : Palette.onSurfaceVariant)
                            .frame(width: 10, height: 10)
                            .offset(x: isOn.wrappedValue ? 7 : -7)
                    }
                    .overlay {
                        Capsule().strokeBorder(isOn.wrappedValue ? Palette.primary : Palette.outlineVariant, lineWidth: 1)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var dockBinding: Binding<Bool> {
        Binding(
            get: { showInDock },
            set: { showInDock = $0; DockVisibility.apply($0) }
        )
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { launchAtLogin = $0; LoginItem.set($0) }
        )
    }

    private func toggleInvert() {
        let was = invertEnabled
        withAnimation(.easeOut(duration: 0.18)) {
            invertEnabled.toggle()
        }
        InvertState.apply(invertEnabled)
        guard !reduceMotion else { return }
        let start = Date()
        ripple = DotMatrix.Ripple(from: was, at: start)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1000))
            if ripple?.at == start { ripple = nil }
        }
    }

    private func quit(_ conflict: Conflict) {
        withAnimation(.easeOut(duration: 0.18)) {
            _ = dismissed.insert(conflict.name)
        }
        onQuit(conflict)
    }
}

struct ConflictBanner: View {
    let conflicts: [Conflict]
    @Binding var expanded: Bool
    let onQuit: (Conflict) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: Gap.sm) {
                    Circle()
                        .fill(Palette.warning)
                        .frame(width: 6, height: 6)
                    Text(conflicts.count == 1 ? "1 CONFLICT SUGGESTION" : "\(conflicts.count) CONFLICT SUGGESTIONS")
                        .font(Typo.labelMedium())
                        .tracking(1)
                        .foregroundStyle(Palette.onWarningContainer)
                    Spacer(minLength: 0)
                    Chevron(expanded: expanded)
                }
                .padding(.horizontal, Gap.sm)
                .padding(.vertical, Gap.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(conflicts.count == 1 ? "1 conflict suggestion" : "\(conflicts.count) conflict suggestions")
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")

            if expanded {
                VStack(spacing: 0) {
                    ForEach(conflicts) { conflict in
                        row(conflict)
                        if conflict.id != conflicts.last?.id {
                            Rectangle().fill(Palette.outlineVariant).frame(height: 1)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Palette.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(Palette.warning.opacity(0.4), lineWidth: 1)
        }
        .padding(.horizontal, Gap.md)
        .padding(.top, Gap.xs)
    }

    private func row(_ conflict: Conflict) -> some View {
        HStack(spacing: Gap.sm) {
            VStack(alignment: .leading, spacing: 0) {
                Text(conflict.name)
                    .font(Typo.bodySmall())
                    .foregroundStyle(Palette.onSurface)
                    .lineLimit(1)
                Text("Also changing scroll")
                    .font(Typo.caption())
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                onQuit(conflict)
            } label: {
                Text("QUIT IT")
                    .font(Typo.labelMedium())
                    .tracking(1)
                    .foregroundStyle(Palette.onWarningContainer)
                    .padding(.horizontal, Gap.sm)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Palette.warning.opacity(0.15)))
                    .overlay(Capsule().strokeBorder(Palette.warning.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quit \(conflict.name)")
        }
        .padding(.horizontal, Gap.sm)
        .padding(.vertical, Gap.xs)
        .background(Palette.warningContainer.opacity(0.3))
        .transition(.opacity)
    }
}

struct Chevron: View {
    let expanded: Bool

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 12
            context.scaleBy(x: scale, y: scale)
            for point in [(3.0, 4.5), (6.0, 7.5), (9.0, 4.5)] {
                context.fill(
                    Path(ellipseIn: CGRect(x: point.0 - 1, y: point.1 - 1, width: 2, height: 2)),
                    with: .color(Palette.warning)
                )
            }
        }
        .frame(width: 12, height: 12)
        .rotationEffect(.degrees(expanded ? 180 : 0))
        .accessibilityHidden(true)
    }
}

struct MenuDropdownView: View {
    @AppStorage(SettingsKeys.invertEnabled) private var invertEnabled = true

    var body: some View {
        ZStack {
            Palette.surface
            DotGrid(opacity: 0.05)

            VStack(spacing: 0) {
                header
                toggleRow
                actions
                strip
            }
        }
        .frame(width: 240)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .strokeBorder(Palette.outlineVariant, lineWidth: 1)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: Gap.sm) {
            MenuBarGlyph()
            Text("re:Mouse")
                .font(Typo.labelLarge())
                .tracking(1.4)
                .foregroundStyle(Palette.onSurface)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Gap.md)
        .padding(.vertical, Gap.sm)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.outlineVariant).frame(height: 1)
        }
    }

    private var toggleRow: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                invertEnabled.toggle()
            }
            InvertState.apply(invertEnabled)
        } label: {
            HStack(spacing: Gap.sm) {
                Text("INVERT SCROLL")
                    .font(Typo.labelMedium())
                    .tracking(1)
                    .foregroundStyle(invertEnabled ? Palette.primary : Palette.onSurfaceVariant)
                Spacer(minLength: 0)
                Capsule()
                    .fill(invertEnabled ? Palette.primaryContainer : Palette.surfaceHighest)
                    .frame(width: 36, height: 20)
                    .overlay {
                        Circle()
                            .fill(invertEnabled ? Palette.primary : Palette.onSurfaceVariant)
                            .frame(width: 14, height: 14)
                            .offset(x: invertEnabled ? 8 : -8)
                    }
                    .overlay {
                        Capsule().strokeBorder(invertEnabled ? Palette.primary : Palette.outlineVariant, lineWidth: 1)
                    }
            }
            .padding(.horizontal, Gap.sm)
            .padding(.vertical, Gap.sm)
            .background(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).fill(Palette.surfaceContainer))
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Gap.sm)
        .padding(.vertical, Gap.sm)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.outlineVariant).frame(height: 1)
        }
        .accessibilityLabel("Invert scroll")
        .accessibilityValue(invertEnabled ? "On" : "Off")
    }

    private var actions: some View {
        VStack(spacing: 0) {
            actionRow("Settings…") {
                MainWindow.show()
            }
            actionRow("Quit", danger: true) {
                NSApp.terminate(nil)
            }
        }
        .padding(Gap.xs)
    }

    private func actionRow(_ title: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Typo.bodyMedium())
                    .foregroundStyle(danger ? Palette.error : Palette.onSurface)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Gap.sm)
            .padding(.vertical, Gap.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var strip: some View {
        HStack(spacing: Gap.xs) {
            Text("HENRYCHEA/REMOUSE")
                .font(Typo.labelSmall())
                .tracking(1)
                .foregroundStyle(Palette.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("MIT")
                .font(Typo.labelSmall())
                .tracking(1.4)
                .foregroundStyle(Palette.primary)
                .padding(.horizontal, Gap.xs)
                .padding(.vertical, 2)
                .background(Capsule().fill(Palette.surfaceContainer))
                .overlay(Capsule().strokeBorder(Palette.outlineVariant, lineWidth: 1))
        }
        .padding(.horizontal, Gap.sm)
        .padding(.vertical, Gap.xs)
        .background(Palette.surfaceLowest.opacity(0.8))
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.outlineVariant).frame(height: 1)
        }
    }
}

struct MainWindowHost: View {
    @ObservedObject private var conflicts = ConflictStore.shared
    @State private var permission = PermissionState.current
    @AppStorage(SettingsKeys.launchAtLogin) private var launchAtLogin = false

    var body: some View {
        MainWindowView(
            permission: permission,
            conflicts: conflicts.conflicts,
            onQuit: quit
        )
            .ignoresSafeArea()
            .onAppear {
                launchAtLogin = LoginItem.isEnabled
                ConflictStore.shared.refresh()
            }
            .task {
                var ticks = 0
                while permission != .granted && ticks < 3600 {
                    try? await Task.sleep(for: .seconds(1))
                    permission = PermissionState.current
                    ticks += 1
                }
            }
    }

    private func quit(_ conflict: Conflict) {
        conflict.app?.terminate()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            ConflictStore.shared.refresh()
        }
    }
}

@MainActor
enum MainWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.contentView = NSHostingView(rootView: MainWindowHost())
            window.title = "re:Mouse"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = Palette.surface.ink
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentMinSize = NSSize(width: 360, height: 420)
            window.contentMaxSize = NSSize(width: 360, height: 420)
            window.isReleasedWhenClosed = false
            window.center()
            Self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
