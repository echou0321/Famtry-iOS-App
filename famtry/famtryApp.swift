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
            PantryOverviewScreen()
                .environmentObject(pantryData) // This shares it with all screens
        }
    }
}
