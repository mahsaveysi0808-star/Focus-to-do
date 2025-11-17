//
//  ContentView.swift
//  FOCUS
//
//  Created by mahsa veysi on 11/11/25.
//

import SwiftUI
import Combine

// MARK: - Phases & Presets

enum Phase {
    case idle, focus, breakt
}

enum TimerPreset: String, CaseIterable, Identifiable {
    case p25 = "25 / 5"
    case p45 = "45 / 10"
    case p50 = "50 / 10"
    case custom = "Custom"

    var id: String { rawValue }

    var work: Int {
        switch self {
        case .p25: return 25
        case .p45: return 45
        case .p50: return 50
        case .custom: return -1
        }
    }

    var brk: Int {
        switch self {
        case .p25: return 5
        case .p45: return 10
        case .p50: return 10
        case .custom: return -1
        }
    }
}

// MARK: - App entry

@main
struct FocusCloneApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

// MARK: - Root

struct ContentView: View {
    var body: some View { TodayView() }
}

// MARK: - Home / Today

struct TodayView: View {
    // Persistent settings
    @AppStorage("workMin") private var workMin = 25
    @AppStorage("breakMin") private var breakMin = 5
    @AppStorage("lastPreset") private var lastPresetRaw = TimerPreset.p25.rawValue
    @AppStorage("selectedBackground") private var selectedBackground = "bg1"

    // State
    @State private var phase: Phase = .idle
    @State private var remainingSec: Int = 25 * 60
    @State private var running = false
    @State private var startedAt = Date()

    // Sheets
    @State private var showMenu = false
    @State private var showTimerSheet = false
    @State private var showFullscreen = false
    @State private var showBackgroundPicker = false

    // Custom sliders (for .custom preset)
    @State private var customWork = 25
    @State private var customBreak = 5

    // Timer tick
    let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Computed
    var currentPreset: TimerPreset { TimerPreset(rawValue: lastPresetRaw) ?? .p25 }
    var duration: Int { (phase == .focus ? workMin : breakMin) * 60 }
    var progress: CGFloat {
        guard duration > 0 else { return 0 }
        let done = max(0, duration - remainingSec)
        return CGFloat(Double(done) / Double(duration))
    }

    var body: some View {
        ZStack {
            // Background
            Image(selectedBackground)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 22) {

                // Top bar
                HStack {
                    Button { showMenu = true } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3).opacity(0.9)
                    }
                    Spacer()
                    Button { showBackgroundPicker = true } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3).opacity(0.9)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal)
                .padding(.top, 12)

                // Hint bubble
                Text("Please select a task…")
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18),
                                in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)

                Spacer()

                // Timer ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.25), lineWidth: 4)
                        .frame(width: 290, height: 290)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white.opacity(0.95),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 290, height: 290)
                        .animation(.easeInOut(duration: 0.2), value: remainingSec)

                    Text(timeString(remainingSec))
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .kerning(2)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                // Controls (Start / Pause / Continue / Stop)
                controlButtons

                Spacer()

                // Bottom toolbar
                HStack(spacing: 28) {
                    ToolbarItemView(icon: "figure.mind.and.body", title: "Strict Mode") {}
                    ToolbarItemView(icon: "timer", title: "Timer Mode") { showTimerSheet = true }
                    ToolbarItemView(icon: "rectangle.expand.vertical", title: "Fullscreen") { showFullscreen = true }
                    ToolbarItemView(icon: "music.note", title: "White Noise") {}
                }
                .foregroundStyle(.white.opacity(0.95))
                .padding(.bottom, 26)
            }
            .padding(.horizontal)
        }
        .onAppear {
            applyPreset(currentPreset)
            configureFor(.focus)
        }
        .onReceive(ticker) { _ in tick() }

        // Sheets
        .sheet(isPresented: $showMenu) {
            MenuView { _ in showMenu = false }
        }
        .sheet(isPresented: $showTimerSheet) { timerSheet }
        .sheet(isPresented: $showBackgroundPicker) {
            BackgroundPicker(selectedBackground: $selectedBackground)
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            FullscreenTimer(seconds: $remainingSec, running: $running) {
                showFullscreen = false
            }
        }
    }

    // MARK: - Timer Controls UI

    private var controlButtons: some View {
        Group {
            // Not started yet
            if phase == .idle || (!running && remainingSec == duration) {
                MainControlButton(title: "Start to Focus", filled: true) {
                    startTimer()
                }
                .frame(maxWidth: 260)

            // Running → Pause + Stop
            } else if running {
                HStack(spacing: 16) {
                    MainControlButton(title: "Pause", filled: true) {
                        running = false
                    }
                    MainControlButton(title: "Stop", filled: false) {
                        stopTimer()
                    }
                }
                .frame(maxWidth: 260)

            // Paused → Continue + Stop
            } else {
                HStack(spacing: 16) {
                    MainControlButton(title: "Continue", filled: true) {
                        running = true
                    }
                    MainControlButton(title: "Stop", filled: false) {
                        stopTimer()
                    }
                }
                .frame(maxWidth: 260)
            }
        }
    }

    // MARK: - Timer logic

    func configureFor(_ p: Phase) {
        phase = p
        running = false
        remainingSec = duration
    }

    func startTimer() {
        phase = .focus
        configureFor(.focus)
        running = true
        startedAt = Date()
    }

    func stopTimer() {
        running = false
        phase = .idle
        remainingSec = workMin * 60
    }

    func tick() {
        guard running else { return }
        if remainingSec > 0 {
            remainingSec -= 1
            return
        }
        running = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if phase == .focus {
            configureFor(.breakt)
        } else {
            configureFor(.focus)
        }
    }

    func timeString(_ s: Int) -> String {
        let m = s / 60
        let ss = s % 60
        return String(format: "%02d:%02d", m, ss)
    }

    // MARK: - Preset logic

    func selectPreset(_ p: TimerPreset) {
        lastPresetRaw = p.rawValue
        if p == .custom {
            workMin = customWork
            breakMin = customBreak
        } else {
            workMin = p.work
            breakMin = p.brk
        }
        configureFor(.focus)
    }

    func applyPreset(_ p: TimerPreset) {
        selectPreset(p)
    }

    // MARK: - Timer Mode Sheet

    var timerSheet: some View {
        NavigationStack {
            Form {
                Section("Presets") {
                    ForEach(TimerPreset.allCases) { p in
                        Button {
                            selectPreset(p)
                        } label: {
                            HStack {
                                Text(p.rawValue)
                                Spacer()
                                if p == currentPreset { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                if currentPreset == .custom {
                    Section("Custom") {
                        VStack(alignment: .leading) {
                            Text("Focus: \(customWork) min")
                            Slider(
                                value: Binding(
                                    get: { Double(customWork) },
                                    set: { customWork = Int($0) }
                                ),
                                in: 0...25,
                                step: 1
                            )
                        }
                        VStack(alignment: .leading) {
                            Text("Break: \(customBreak) min")
                            Slider(
                                value: Binding(
                                    get: { Double(customBreak) },
                                    set: { customBreak = Int($0) }
                                ),
                                in: 1...15,
                                step: 1
                            )
                        }
                    }
                }
            }
            .navigationTitle("Timer Mode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTimerSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        applyPreset(currentPreset)
                        showTimerSheet = false
                    }
                }
            }
        }
    }
}

// MARK: - Fullscreen Timer

struct FullscreenTimer: View {
    @Binding var seconds: Int
    @Binding var running: Bool
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill").font(.title2)
                    }
                    .tint(.white)
                    Spacer()
                }
                .padding()

                Spacer()

                Text(timeString(seconds))
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Spacer()

                Button {
                    running.toggle()
                } label: {
                    Image(systemName: running ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .padding()
                        .background(Color.white, in: Circle())
                }
                .padding(.bottom, 28)
            }
        }
    }

    private func timeString(_ s: Int) -> String {
        let m = s / 60
        let ss = s % 60
        return String(format: "%02d:%02d", m, ss)
    }
}

// MARK: - Menu (simple mock)

struct MenuView: View {
    let onSelect: (String) -> Void

    private let items: [(String, String)] = [
        ("sun.max", "Today"),
        ("sunset.fill", "Tomorrow"),
        ("calendar", "This Week"),
        ("calendar.badge.clock", "Planned"),
        ("calendar.badge.exclamationmark", "Events"),
        ("checkmark.seal", "Completed"),
        ("square.and.pencil", "Tasks"),
        ("questionmark.circle", "Usage Guidance"),
        ("plus", "Add Project")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill").font(.title2)
                        VStack(alignment: .leading) {
                            Text("mahsa").font(.headline)
                            Text("Focus To-Do (Lite)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    ForEach(items, id: \.1) { icon, title in
                        Button { onSelect(title) } label: {
                            HStack {
                                Image(systemName: icon)
                                Text(title)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Menu")
        }
    }
}

// MARK: - Background Picker

struct BackgroundPicker: View {
    @Binding var selectedBackground: String

    let items = [
        ("bg1", "Night Sky"),
        ("bg2", "Mountains"),
        ("bg3", "Sunset"),
        ("bg4", "Ocean")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150))],
                    spacing: 16
                ) {
                    ForEach(items, id: \.0) { name, title in
                        Button {
                            selectedBackground = name
                        } label: {
                            ZStack(alignment: .bottom) {
                                Image(name)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 100)
                                    .clipped()
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                selectedBackground == name ? Color.white : Color.clear,
                                                lineWidth: 3
                                            )
                                    )
                                Text(title)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.35))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Background")
        }
    }
}

// MARK: - Small toolbar item

struct ToolbarItemView: View {
    let icon: String
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                Text(title).font(.footnote)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main control button (Start / Pause / Continue / Stop)

struct MainControlButton: View {
    let title: String
    let filled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(filled ? Color.white : Color.clear)
                .foregroundColor(filled ? .black : .white)
                .overlay(
                    Capsule().stroke(Color.white, lineWidth: filled ? 0 : 1.5)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
