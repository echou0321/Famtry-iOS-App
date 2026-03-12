//
//  famtryApp.swift
//  famtry
//
//  Created by Aaron Li on 3/4/26.
//

import SwiftUI
import UserNotifications

@main
struct famtryApp: App {
    @StateObject private var pantryData = PantryData()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootFlowView()
                .environmentObject(pantryData)
                .task {
                    do {
                        try await NotificationManager.shared.requestPermission()
                    } catch {
                        print("Failed to request notification permission: \(error.localizedDescription)")
                    }
                }
        }
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

struct RootFlowView: View {
    @EnvironmentObject var data: PantryData
    @Environment(\.scenePhase) private var scenePhase

    @State private var showExpirationAlert = false
    @State private var expirationAlertMessage = ""

    @AppStorage("lastExpirationAlertDate") private var lastExpirationAlertDate: String = ""

    var body: some View {
        TabView {
            PantryRootScreen()
                .tabItem {
                    Image(systemName: "house")
                    Text("Pantry")
                }

            ProfileRootScreen()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
        }
        .task(id: data.items.count) {
            await checkAndShowExpirationAlertIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await checkAndShowExpirationAlertIfNeeded()
                }
            }
        }
        .alert("Expiring Soon", isPresented: $showExpirationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(expirationAlertMessage)
        }
    }

    private func checkAndShowExpirationAlertIfNeeded() async {
        guard data.hasUser, data.hasFamily else { return }
        guard !alreadyShownToday() else { return }

        // If items have not loaded yet, fetch them once here
        if data.items.isEmpty {
            do {
                try await data.fetchItems()
            } catch {
                print("Failed to fetch items for expiration alert: \(error.localizedDescription)")
                return
            }
        }

        let expiringItems = data.itemsExpiringTomorrow()
        guard !expiringItems.isEmpty else { return }

        let names = expiringItems.map(\.name)

        if names.count == 1 {
            expirationAlertMessage = "\(names[0]) expires tomorrow."
        } else {
            expirationAlertMessage = "These items expire tomorrow: \(names.joined(separator: ", "))."
        }

        markShownToday()
        showExpirationAlert = true
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func alreadyShownToday() -> Bool {
        lastExpirationAlertDate == todayKey()
    }

    private func markShownToday() {
        lastExpirationAlertDate = todayKey()
    }
}

struct PantryRootScreen: View {
    @EnvironmentObject var data: PantryData

    var body: some View {
        Group {
            if data.hasUser && !data.hasFamily {
                NavigationView {
                    CreateOrJoinFamilyScreen()
                        .navigationTitle("Family")
                }
            } else {
                PantryOverviewScreen()
            }
        }
    }
}

struct ProfileRootScreen: View {
    var body: some View {
        NavigationView {
            ProfileScreen()
        }
    }
}
