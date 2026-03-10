//
//  famtryApp.swift
//  famtry
//
//  Created by Aaron Li on 3/4/26.
//

import SwiftUI

@main
struct famtryApp: App {
    // We create one instance of the data here
    @StateObject var pantryData = PantryData()

    var body: some Scene {
        WindowGroup {
            RootFlowView()
                .environmentObject(pantryData) // This shares it with all screens
        }
    }
}

struct RootFlowView: View {
    @EnvironmentObject var data: PantryData

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
