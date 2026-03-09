//
//  AddItemScreen.swift
//  famtry
//
//  Created by Katie Hsu on 3/9/26.
//

import SwiftUI

struct AddItemScreen: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var data: PantryData // Access the shared data
    
    @State private var itemName: String = ""
    @State private var quantity: Int = 1
    @State private var includeExpiration: Bool = false
    @State private var expirationDate: Date = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details").foregroundColor(.black)) {
                    TextField("Item Name", text: $itemName)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                }
                
                Section(header: Text("Freshness").foregroundColor(.black)) {
                    Toggle("Set Expiration Date", isOn: $includeExpiration)
                    if includeExpiration {
                        DatePicker("Date", selection: $expirationDate, displayedComponents: .date)
                    }
                }
                
                Section {
                    Button(action: {
                        // Call the function in our Data Manager
                        data.addItem(name: itemName, qty: quantity, expiry: expirationDate, includeExpiry: includeExpiration)
                        dismiss() // Close the popup
                    }) {
                        Text("Add to Pantry")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(itemName.isEmpty ? Color.gray : Color.black)
                    .disabled(itemName.isEmpty) // Prevent adding empty items
                }
            }
            .navigationTitle("New Item")
        }
    }
    func saveItem() {
        // Here you would trigger your POST request to the Node.js/Render backend
        print("Saving \(itemName) to database...")
        dismiss()
    }
}
    
    

