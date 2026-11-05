import SwiftData
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        MainActor.assumeIsolated {
            NotificationManager.shared.configure()
            let context = Persistence.container.mainContext
            InitialData.seedIfNeeded(context)
            NotificationManager.shared.rescheduleAll(context)
        }
        return true
    }
}

@main
struct TimeToEatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Theme.zh)
        }
        .modelContainer(Persistence.container)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = LaunchOptions.initialTab

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("今天", systemImage: "checklist") }
                .tag(0)
            MedicationListView()
                .tabItem { Label("我的药", systemImage: "pills.fill") }
                .tag(1)
            HistoryView()
                .tabItem { Label("记录", systemImage: "chart.bar.fill") }
                .tag(2)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await NotificationManager.shared.refreshStatus() } }
        }
    }
}
