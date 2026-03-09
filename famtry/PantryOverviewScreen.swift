//
//  PantryOverviewScreen.swift
//  famtry
//
//  Created by Katie Hsu on 3/9/26.
//

import SwiftUI

struct PantryOverviewScreen: View {
    // This grabs the data we injected in the App file
    @EnvironmentObject var data: PantryData
    @State private var showAddItem = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(data.items) { item in
                    PantryRow(item: item)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Shared Pantry")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddItem = true }) {
                        Image(systemName: "plus").foregroundColor(.black)
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                // The popup "Add" screen
                AddItemScreen()
            }
        }
    }
}

struct PantryRow: View {
    let item: PantryItem
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .strikethrough(isExpired)
                
                Text("Owners: \(item.owners.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let date = item.expirationDate {
                    Text("Expires: \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isExpired ? Color.black : Color.clear)
                        .foregroundColor(isExpired ? .white : .black)
                        .border(Color.black, width: 1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("x\(item.quantity)")
                    .font(.title3)
                    .fontWeight(.bold)
                
                if item.isPendingApproval {
                    Text("PENDING")
                        .font(.system(size: 8))
                        .fontWeight(.black)
                        .padding(4)
                        .border(Color.black)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var isExpired: Bool {
        guard let date = item.expirationDate else { return false }
        return date < Date()
    }
}
