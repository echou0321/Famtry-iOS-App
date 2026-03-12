//
//  PantryData.swift
//  famtry
//
//  Created by Katie Hsu on 3/9/26.
//

import SwiftUI
import Combine

// MARK: - Models

struct User {
    var id: String
    var name: String
    var email: String
    var familyId: String?
    // Profile fields
    var avatar: String?
    var gender: String?
    var region: String?
    var phone: String?
    var signature: String?
}

struct Family {
    var id: String
    var name: String
    var avatar: String?
    var description: String?
    var memberIds: [String]
}

struct ItemOwner: Identifiable, Hashable {
    let id: String
    let name: String
}

struct PantryItem: Identifiable, Hashable {
    let id: String
    var name: String
    var quantity: Int
    var expirationDate: Date?
    var familyId: String?
    // the part I changed
    var owners: [ItemOwner]
    var pendingOwners: [ItemOwner]
    var ownerNames: String {
        owners.map(\.name).joined(separator: ", ")
    }
    var hasPendingRequests: Bool {
        !pendingOwners.isEmpty
    }
}

// MARK: - Global App / Pantry State

class PantryData: ObservableObject {
    // Simple user / family state for now.
    // Later you can replace this with real backend data.
    @Published var currentUser: User?
    @Published var currentFamily: Family?
    @Published var items: [PantryItem] = []

    var hasUser: Bool {
        currentUser != nil
    }

    var hasFamily: Bool {
        currentFamily != nil
    }

//    // @Published tells SwiftUI: "Whenever this list changes, refresh the screens!"
//    @Published var items: [PantryItem] = [
//        PantryItem(name: "Almond Milk", quantity: 2, expirationDate: Date().addingTimeInterval(86400 * 3), owners: ["Alice"]),
//        PantryItem(name: "Greek Yogurt", quantity: 5, expirationDate: Date().addingTimeInterval(-86400), owners: ["Bob"])
//    ]

    // MARK: - User & Family helpers

    @MainActor
    func register(name: String, email: String, password: String) async throws {
        let apiUser = try await APIClient.shared.register(name: name, email: email, password: password)
        let familyId = apiUser.familyIdResolved
        currentUser = User(
            id: apiUser.id,
            name: apiUser.name,
            email: apiUser.email,
            familyId: familyId,
            avatar: apiUser.avatar,
            gender: apiUser.gender,
            region: apiUser.region,
            phone: apiUser.phone,
            signature: apiUser.signature
        )
        if let familyId {
            let family = try await APIClient.shared.getFamily(id: familyId)
            currentFamily = Family(id: family.id, name: family.name, memberIds: family.memberIds)
            try await fetchItems()
        } else {
            items = []
        }
        
    }

    @MainActor
    func login(email: String, password: String) async throws {
        let response = try await APIClient.shared.login(email: email, password: password)
        let familyId = response.user.familyIdResolved
        currentUser = User(
            id: response.user.id,
            name: response.user.name,
            email: response.user.email,
            familyId: familyId,
            avatar: response.user.avatar,
            gender: response.user.gender,
            region: response.user.region,
            phone: response.user.phone,
            signature: response.user.signature
        )
        if let familyId {
            let family = try await APIClient.shared.getFamily(id: familyId)
            currentFamily = Family(id: family.id, name: family.name, memberIds: family.memberIds)
            try await fetchItems()
        } else {
            items = []
        }
    }

    @MainActor
    func createFamily(named name: String) async throws {
        guard let userId = currentUser?.id else { return }
        let family = try await APIClient.shared.createFamily(name: name, userId: userId)
        currentFamily = Family(id: family.id, name: family.name, memberIds: family.memberIds)
        if var user = currentUser {
            user.familyId = family.id
            currentUser = user
        }
        
        try await fetchItems()
    }

    @MainActor
    func joinFamily(familyId: String) async throws {
        guard let userId = currentUser?.id else { return }
        let family = try await APIClient.shared.joinFamily(familyId: familyId, userId: userId)
        currentFamily = Family(id: family.id, name: family.name, memberIds: family.memberIds)
        if var user = currentUser {
            user.familyId = family.id
            currentUser = user
        }
        
        try await fetchItems()
    }

    @MainActor
    func verifyFamily(familyId: String) async throws -> (exists: Bool, name: String?) {
        let response = try await APIClient.shared.verifyFamily(familyId: familyId)
        return (response.exists, response.name)
    }

    @MainActor
    func leaveFamily() async throws {
        guard let userId = currentUser?.id, let familyId = currentFamily?.id else {
            print("DEBUG leaveFamily: missing userId or familyId")
            return
        }
        print("DEBUG leaveFamily: familyId=\(familyId) userId=\(userId)")
        print("DEBUG leaveFamily: URL would be /families/\(familyId)/leave")
        _ = try await APIClient.shared.leaveFamily(familyId: familyId, userId: userId)
        currentFamily = nil
        if var user = currentUser {
            user.familyId = nil
            currentUser = user
        }
        
        items = []
    }

    @MainActor
    func updateProfile(name: String? = nil, avatar: String? = nil, gender: String? = nil, region: String? = nil, phone: String? = nil, signature: String? = nil) async throws {
        guard let userId = currentUser?.id else { return }
        let apiUser = try await APIClient.shared.updateProfile(userId: userId, name: name, avatar: avatar, gender: gender, region: region, phone: phone, signature: signature)
        if var user = currentUser {
            user.name = apiUser.name
            user.avatar = apiUser.avatar
            user.gender = apiUser.gender
            user.region = apiUser.region
            user.phone = apiUser.phone
            user.signature = apiUser.signature
            currentUser = user
        }
    }

    @MainActor
    func searchFamilies(query: String) async throws -> [Family] {
        let families = try await APIClient.shared.searchFamilies(query: query)
        return families.map { Family(id: $0.id, name: $0.name, avatar: $0.avatar, description: $0.description, memberIds: $0.memberIds) }
    }

    // MARK: - Logout

    @MainActor
    func logout() {
        currentUser = nil
        currentFamily = nil
        items = []
    }

    // MARK: - Pantry item helpers

    @MainActor
    func fetchItems() async throws {
        guard let familyId = currentFamily?.id else {
            items = []
            return
        }

        let fetchedItems = try await APIClient.shared.getItems(familyId: familyId)
        items = sortItemsByExpiration(fetchedItems)
    }
    
    @MainActor
    func refreshItem(_ itemId: String) async throws -> PantryItem {
        let freshItem = try await APIClient.shared.getItem(id: itemId)

        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index] = freshItem
        } else {
            items.insert(freshItem, at: 0)
        }

        items = sortItemsByExpiration(items)
        return freshItem
    }
    
    @MainActor
    func replaceItem(_ item: PantryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.insert(item, at: 0)
        }
        
        items = sortItemsByExpiration(items)
    }

    @MainActor
    func removeItem(id: String) {
        items.removeAll { $0.id == id }
    }

    func itemsExpiringInOneDay(from now: Date = Date()) -> [PantryItem] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!

        return items.filter { item in
            guard let expirationDate = item.expirationDate else { return false }
            return calendar.isDate(expirationDate, inSameDayAs: tomorrow)
        }
    }
    
    func itemsExpiringTomorrow(from now: Date = Date()) -> [PantryItem] {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
            return []
        }

        return items.filter { item in
            guard let expirationDate = item.expirationDate else { return false }
            return calendar.isDate(expirationDate, inSameDayAs: tomorrow)
        }
    }
    
    private func sortItemsByExpiration(_ items: [PantryItem]) -> [PantryItem] {
        items.sorted { lhs, rhs in
            switch (lhs.expirationDate, rhs.expirationDate) {
            case let (lDate?, rDate?):
                return lDate < rDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }
    
}
