import SwiftUI

struct PantryOverviewScreen: View {
    // This grabs the data we injected in the App file
    @EnvironmentObject var data: PantryData
    @State private var showAddItem = false
    @State private var showLoginAlert = false
    @State private var showDeleteConfirm = false
    @State private var selectedItemToDelete: PantryItem?
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?
    
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
                                // CREATE FAMILY BUTTON
                                Button(action: {
                                    showLoginAlert = true
                                }) {
                                    Text("Create Family")
                                        .font(.footnote)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color(.systemBackground)) // Inverse text
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.primary) // Adapts to White in Dark Mode
                                        .cornerRadius(8)
                                }

                                // JOIN FAMILY BUTTON
                                Button(action: {
                                    showLoginAlert = true
                                }) {
                                    Text("Join Family")
                                        .font(.footnote)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.primary, lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
                ForEach(data.items) { item in
                    NavigationLink {
                        ItemDetailScreen(itemId: item.id)
                    } label: {
                        PantryRow(item: item)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if canDelete(item) {
                            Button(role: .destructive) {
                                selectedItemToDelete = item
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
            }
            .refreshable {
                if data.hasUser && data.hasFamily {
                    try? await data.fetchItems()
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle(data.hasUser && data.hasFamily ? "Shared Pantry" : "Pantry Preview")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddItem = true }) {
                        Image(systemName: "plus")
                            // Plus icon now turns white in dark mode
                            .foregroundColor(data.hasUser && data.hasFamily ? .primary : .gray)
                    }
                    .disabled(!data.hasUser || !data.hasFamily)
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddItemScreen()
            }
            .alert("Login required", isPresented: $showLoginAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please log in from the Profile tab before creating or joining a family.")
            }
            .alert("Delete item?", isPresented: $showDeleteConfirm, presenting: selectedItemToDelete) { item in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteItem(item)
                    }
                }
            } message: { item in
                Text("Are you sure you want to delete \(item.name)?")
            }
            .alert("Delete failed", isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage ?? "")
            }
        }
        .task {
            if data.hasUser && data.hasFamily {
                try? await data.fetchItems()
            }
        }
    }
    
    private func canDelete(_ item: PantryItem) -> Bool {
        guard let userId = data.currentUser?.id else { return false }
        return item.owners.contains(where: { $0.id == userId })
    }

    @MainActor
    private func deleteItem(_ item: PantryItem) async {
        guard let userId = data.currentUser?.id else { return }
        isDeleting = true
        deleteErrorMessage = nil
        do {
            try await APIClient.shared.deleteItem(id: item.id, userId: userId)
            data.removeItem(id: item.id)
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}

// MARK: - Row View
struct PantryRow: View {
    @EnvironmentObject var data: PantryData
    let item: PantryItem
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .strikethrough(isExpired)
                
                Text("Owners: \(item.ownerNames)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let date = item.expirationDate {
                    Text("Expires: \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        // Background becomes white in dark mode, text becomes black
                        .background(isExpired ? Color.primary : Color.clear)
                        .foregroundColor(isExpired ? Color(.systemBackground) : .primary)
                        .border(Color.primary, width: 1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("x\(item.quantity)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if hasPendingRequestsToReview {
                    // Owner has requests to review
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                        Text("REVIEW")
                            .font(.system(size: 8))
                            .fontWeight(.black)
                    }
                    .padding(4)
                    .foregroundColor(.primary)
                    .border(Color.primary, width: 1)
                } else if hasPendingOwnershipRequest {
                    // User has requested ownership
                    Text("PENDING")
                        .font(.system(size: 8))
                        .fontWeight(.black)
                        .padding(4)
                        .foregroundColor(.primary)
                        .border(Color.primary, width: 1)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var isExpired: Bool {
        guard let date = item.expirationDate else { return false }
        return date < Date()
    }
    
    // Check if current user is an owner and there are pending requests
    private var hasPendingRequestsToReview: Bool {
        guard let userId = data.currentUser?.id else { return false }
        let isOwner = item.owners.contains(where: { $0.id == userId })
        return isOwner && item.hasPendingRequests
    }
    
    // Check if current user has a pending ownership request
    private var hasPendingOwnershipRequest: Bool {
        guard let userId = data.currentUser?.id else { return false }
        return item.pendingOwners.contains(where: { $0.id == userId })
    }
}
