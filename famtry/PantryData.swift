//
//  PantryData.swift
//  famtry
//
//  Created by Katie Hsu on 3/9/26.
//

import SwiftUI
import Combine

// model
struct PantryItem: Identifiable {
    let id = UUID()
    var name: String
    var quantity: Int
    var expirationDate: Date?
    var owners: [String]
    var isPendingApproval: Bool = false
}

// data
class PantryData: ObservableObject {
    // @Published tells SwiftUI: "Whenever this list changes, refresh the screens!"
    @Published var items: [PantryItem] = [
        PantryItem(name: "Almond Milk", quantity: 2, expirationDate: Date().addingTimeInterval(86400 * 3), owners: ["Alice"]),
        PantryItem(name: "Greek Yogurt", quantity: 5, expirationDate: Date().addingTimeInterval(-86400), owners: ["Bob"])
    ]
    
    func addItem(name: String, qty: Int, expiry: Date?, includeExpiry: Bool) {
        let newItem = PantryItem(
            name: name,
            quantity: qty,
            expirationDate: includeExpiry ? expiry : nil,
            owners: ["Me"]
        )
        items.append(newItem)
    }
    
    // Bonus: Add this so you can test deleting items too!
    func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}
