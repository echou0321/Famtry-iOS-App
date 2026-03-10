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
    @State private var showLoginAlert = false
    
    var body: some View {
        NavigationView {
            List {
                if !data.hasUser || !data.hasFamily {
                    Section {
                        Text("You are viewing a local demo pantry. Log in from the Profile tab and join a family to sync real shared items.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)

                        if !data.hasUser {
                            VStack(spacing: 8) {
                                Button(action: {
                                    showLoginAlert = true
                                }) {
                                    Text("Create Family")
                                        .font(.footnote)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.black)
                                        .cornerRadius(8)
                                }

                                Button(action: {
                                    showLoginAlert = true
                                }) {
                                    Text("Join Family")
                                        .font(.footnote)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }

                ForEach(data.items) { item in
                    PantryRow(item: item)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle(data.hasUser && data.hasFamily ? "Shared Pantry" : "Pantry Preview")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddItem = true }) {
                        Image(systemName: "plus").foregroundColor(data.hasUser && data.hasFamily ? .black : .gray)
                    }
                    .disabled(!data.hasUser || !data.hasFamily)
                }
            }
            .sheet(isPresented: $showAddItem) {
                // The popup "Add" screen
                AddItemScreen()
            }
            .alert("Login required", isPresented: $showLoginAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please log in from the Profile tab before creating or joining a family.")
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
