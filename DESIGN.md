# Famtry — iOS App Design Document

**Project:** Famtry (Family Pantry)  
**Platform:** iOS (SwiftUI)  
**Created:** March 2026  
**Authors:** Aaron Li, Katie Hsu  

---

## 1. Overview

Famtry is a shared household pantry management app. A family group tracks grocery items together — who owns what, how much is left, and when things expire. The app sends local notifications before items expire and shows an in-app alert once per day when items are expiring tomorrow.

**Core problem it solves:** In a shared household, people don't know what's in the fridge, items expire silently, and there's no single source of truth for who is responsible for what.

---

## 2. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| UI | SwiftUI | Declarative, first-party, modern iOS |
| State management | `ObservableObject` + `@EnvironmentObject` | Built-in reactive state, no third-party needed |
| Networking | `URLSession` + `async/await` | Native concurrency, no Combine chains needed |
| Notifications | `UserNotifications` framework | Local scheduling, no push server required |
| Persistence | None (server is source of truth) | Keeps the client simple; no CoreData/local DB |
| Dependencies | None (no CocoaPods/SPM) | Reduces complexity for a small-team project |
| Backend | Node.js REST API on Render | Separate repo; app talks to it over HTTPS |

---

## 3. Architecture

### Pattern: Centralized ViewModel (MVVM-lite)

The app uses a single shared `PantryData` class that acts as the app-level ViewModel. Every screen reads from and writes to it via `@EnvironmentObject`. There is no per-screen ViewModel.

```
famtryApp
  └── PantryData (@StateObject)          ← created once at root
        ↓ injected via .environmentObject(...)
  RootFlowView
    ├── PantryRootScreen
    │     └── PantryOverviewScreen        ← reads data.items
    │           ├── ItemDetailScreen
    │           └── AddItemScreen
    └── ProfileRootScreen
          └── ProfileScreen
                ├── EditProfileScreen
                ├── FamilyMembersScreen
                └── CreateOrJoinFamilyScreen
```

**Why one shared ViewModel instead of per-screen ViewModels?**
- The app has a single data domain (one user, one family, one item list). Splitting into many ViewModels would require cross-ViewModel communication.
- `@EnvironmentObject` makes the state available anywhere in the tree with zero boilerplate.
- Tradeoff: `PantryData` grows larger as features are added. For a bigger app, per-feature ViewModels would be better.

### Key Architectural Decisions

**Decision 1 — No local persistence**  
Items are fetched from the server on every login and family join. There is no CoreData, UserDefaults cache, or local DB. This was intentional: keeping the client stateless avoids cache invalidation bugs in a multi-user, shared-data app. The tradeoff is no offline support.

**Decision 2 — `@MainActor` on all state mutations**  
Every method in `PantryData` that writes to `@Published` properties is marked `@MainActor`. This ensures UI updates always happen on the main thread without manual `DispatchQueue.main.async` calls.

**Decision 3 — `async/await` throughout, no Combine in networking**  
All API calls use Swift Concurrency (`async throws`). Combine is imported but not used in the networking layer. This makes the call sites straightforward to read and avoids managing `AnyCancellable` lifetimes.

---

## 4. Data Models

```swift
struct User {
    var id: String
    var name: String
    var email: String
    var familyId: String?          // nil if not in a family
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
    var expirationDate: Date?      // optional — not all items expire
    var familyId: String?
    var owners: [ItemOwner]        // users who own this item
    var pendingOwners: [ItemOwner] // users who requested ownership

    // Computed
    var ownerNames: String         // "Alice, Bob"
    var hasPendingRequests: Bool
}
```

**Key design choice:** Items have multiple owners (`[ItemOwner]`), not a single owner. This supports shared-ownership semantics (e.g., a box of cereal two people contributed to). The `pendingOwners` array holds ownership requests that current owners must approve or reject.

**MongoDB `_id` mapping:** The backend uses MongoDB, which returns `_id` instead of `id`. `APIClient` uses custom `CodingKeys` to map `_id → id` in every response struct.

---

## 5. Networking Layer (`APIClient`)

A singleton class `APIClient.shared` wraps all HTTP calls. It holds the base URL and a shared `URLSession`. All methods are `async throws`.

**Base URL:** `https://famtry-backend-server-rkq1.onrender.com/api`

### Endpoint Map

| Feature | Method | Path |
|---|---|---|
| Register | POST | `/users/register` |
| Login | POST | `/users/login` |
| Update profile | PUT | `/users/{id}` |
| Create family | POST | `/families` |
| Get family | GET | `/families/{id}` |
| Join family | POST | `/families/{id}/join` |
| Leave family | POST | `/families/{id}/leave` |
| Verify family | GET | `/families/{id}/verify` |
| Search families | GET | `/families/search?q=` |
| Get members | GET | `/families/{id}/members` |
| List items | GET | `/items/families/{familyId}/items` |
| Get item | GET | `/items/{id}` |
| Create item | POST | `/items/families/{familyId}/items` |
| Update item | PUT | `/items/{id}` |
| Delete item | DELETE | `/items/{id}` |
| Request ownership | POST | `/items/{id}/request-ownership` |
| Approve ownership | POST | `/items/{id}/approve-ownership/{userId}` |
| Reject ownership | POST | `/items/{id}/reject-ownership/{userId}` |

### Date Handling

The backend returns ISO8601 dates with fractional seconds (e.g., `2026-04-01T00:00:00.000Z`). Swift's default `JSONDecoder.DateDecodingStrategy.iso8601` does not handle fractional seconds. The app configures a custom `ISO8601DateFormatter` with `.withFractionalSeconds` to fix this.

```swift
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
decoder.dateDecodingStrategy = .custom { decoder in ... }
```

---

## 6. State Management Flow

```
User action in View
      ↓
View calls PantryData method (e.g., data.addItem(...))
      ↓
PantryData calls APIClient (async/await)
      ↓
APIClient returns decoded model or throws error
      ↓
PantryData updates @Published property (on @MainActor)
      ↓
SwiftUI re-renders affected views automatically
```

### Item Sorting

After every fetch, create, update, or delete, items are re-sorted by `sortItemsByExpiration()`:
1. Items with an expiration date come before items without one
2. Among dated items: soonest first (urgency ordering)
3. Among undated items: alphabetical by name

This sorting is applied in `fetchItems()`, `refreshItem()`, and `replaceItem()`.

---

## 7. Navigation Structure

The app uses a `TabView` with two tabs: **Pantry** and **Profile**.

Navigation is handled with SwiftUI's `NavigationView` / `NavigationLink` and `.sheet()` modals.

**Conditional routing in `PantryRootScreen`:**
- If user has no family → show `CreateOrJoinFamilyScreen`
- If user has a family → show `PantryOverviewScreen`

This check runs reactively: when `data.hasFamily` changes, the view tree rebuilds automatically.

**Auth routing in `ProfileScreen`:**
- If not logged in → `LoginCreateUserScreen` is accessible via navigation
- Logout clears `currentUser`, `currentFamily`, and `items` in `PantryData`, which triggers the view to re-render showing the logged-out state

---

## 8. Ownership System

This is the most complex feature in the app.

**Concept:**
- Every item has an `owners` list and a `pendingOwners` list
- Any family member can request ownership of an item they don't own
- Any existing owner can approve or reject each pending request
- Only owners can edit or delete an item

**UI flow:**
1. User views `ItemDetailScreen`
2. If they are not an owner, they see a "Request Ownership" button
3. If they are an owner, they see a list of pending requests with Approve / Reject buttons
4. After any approval/rejection action, `refreshItem()` is called to get fresh state from the server

**Why server-side:** Ownership state is not held locally. Every ownership action calls the API and then re-fetches the item. This avoids stale state in a multi-user scenario.

---

## 9. Notification System

Two parallel notification mechanisms:

### 9a. Local Push Notifications (`NotificationManager`)

Scheduled via `UNUserNotificationCenter` at item creation/update:
- Fires at **9:00 AM the day before expiration**
- Notification ID is the item's server ID — scheduling again for the same item replaces the previous notification automatically
- Items without an expiration date get no notification

### 9b. In-App Expiration Alert (`RootFlowView`)

A daily in-app `Alert` for items expiring tomorrow:
- Shown at most **once per day** — the last-shown date is persisted in `@AppStorage("lastExpirationAlertDate")`
- Triggered on app foreground (`scenePhase == .active`) and when the item count changes
- Lists item names in a human-readable sentence

**Why both?** Local notifications work when the app is closed. The in-app alert ensures the user sees a summary even if they dismissed the notification.

---

## 10. Key Screens

### `PantryOverviewScreen`
- Lists all items sorted by expiration (soonest first)
- Expired items displayed with strikethrough text
- Pull-to-refresh calls `data.fetchItems()`
- Floating "+" button opens `AddItemScreen` as a sheet
- Each row shows name, quantity (with +/- buttons), expiration date, and owner names
- Tapping a row navigates to `ItemDetailScreen`

### `ItemDetailScreen`
- Shows full item details
- Owner-only actions: Edit fields, Delete item
- Non-owner action: Request Ownership button
- Owner action: Approve / Reject each pending request
- Always calls `refreshItem()` on appear to get latest ownership state

### `AddItemScreen`
- Form with name (required), quantity (stepper), optional expiration date (DatePicker)
- On submit: calls API to create item, then schedules a local notification if expiration is set

### `CreateOrJoinFamilyScreen`
- Two paths: type a new family name to create, or enter an existing family ID to join
- Uses `verifyFamily()` to confirm the ID exists before joining
- On success, `PantryData` updates `currentFamily` and fetches items

### `FamilyMembersScreen`
- Shows member count and list of member names
- **Auto-refresh:** Uses a `Timer` to call `data.refreshFamilyAndItems()` every 2 seconds so the member count stays live without pull-to-refresh

### `ProfileScreen`
- Shows user info, family info, and action buttons (Edit, Leave Family, Logout)
- Also auto-refreshes family data every 2 seconds (same timer pattern as FamilyMembersScreen)

### `EditProfileScreen`
- Sheet form for updating: name, avatar, gender, region, phone, signature
- Calls `data.updateProfile(...)` on save

---

## 11. Design Decisions Summary (Interview-Ready)

| Decision | What | Why |
|---|---|---|
| Single `PantryData` ViewModel | One `ObservableObject` for all app state | Simple for a small, single-domain app; avoids cross-VM coordination |
| No local cache | Server is always source of truth | Multi-user app; stale local cache would cause conflicts |
| `@MainActor` on all mutations | All `@Published` writes on main thread | Prevents UI threading bugs without manual dispatch |
| `async/await` (no Combine) | Swift Concurrency end-to-end | Cleaner call sites, easier error propagation with `throws` |
| Custom ISO8601 decoder | Handles fractional seconds from MongoDB | Default Swift decoder doesn't support `.withFractionalSeconds` |
| Dual notification strategy | Local push + in-app alert | Different scenarios: app closed vs. app open |
| `@AppStorage` for alert throttle | One alert per day using a persisted date key | Prevents spamming the user on every app open |
| Sorted list after every mutation | Re-sort on fetch, insert, update | Ensures expiring items always appear at the top |
| Ownership request/approve flow | API-driven, always re-fetch after action | No optimistic updates — correctness over speed |
| Timer polling on Profile/Members | `Timer` every 2 seconds | No WebSocket on the backend; polling is the simplest live-update solution |

---

## 12. Known Limitations & Tradeoffs

- **No offline mode:** All data requires network; no local caching layer
- **No real-time push:** Ownership changes and new items require manual pull-to-refresh (or 2-second timer polling)
- **Single family per user:** `User.familyId` is a single optional string; a user cannot belong to multiple families
- **No image upload:** Avatar fields are strings (likely URLs or emoji), not actual image uploads
- **Polling instead of WebSockets:** The 2-second timer is simple but inefficient for large families
- **`ContentView.swift` is unused:** Legacy placeholder file not cleaned up

---

## 13. File Reference

| File | Role |
|---|---|
| [famtry/famtryApp.swift](famtry/famtryApp.swift) | App entry, `RootFlowView`, expiration alert logic, notification delegate |
| [famtry/PantryData.swift](famtry/PantryData.swift) | All models, global state, business logic |
| [famtry/APIClient.swift](famtry/APIClient.swift) | REST networking layer, response structs |
| [famtry/NotificationManager.swift](famtry/NotificationManager.swift) | Local notification scheduling |
| [famtry/Screens/PantryOverviewScreen.swift](famtry/Screens/PantryOverviewScreen.swift) | Main item list |
| [famtry/Screens/ItemDetailScreen.swift](famtry/Screens/ItemDetailScreen.swift) | Item detail, edit, ownership actions |
| [famtry/Screens/AddItemScreen.swift](famtry/Screens/AddItemScreen.swift) | Add item form |
| [famtry/Screens/LoginCreateUserScreen.swift](famtry/Screens/LoginCreateUserScreen.swift) | Auth screen |
| [famtry/Screens/CreateOrJoinFamilyScreen.swift](famtry/Screens/CreateOrJoinFamilyScreen.swift) | Family onboarding |
| [famtry/Screens/ProfileScreen.swift](famtry/Screens/ProfileScreen.swift) | Profile + family management |
| [famtry/Screens/EditProfileScreen.swift](famtry/Screens/EditProfileScreen.swift) | Profile editing sheet |
| [famtry/Screens/FamilyMembersScreen.swift](famtry/Screens/FamilyMembersScreen.swift) | Family member list |
| [famtry/Screens/WelcomeScreen.swift](famtry/Screens/WelcomeScreen.swift) | Onboarding welcome screen |
