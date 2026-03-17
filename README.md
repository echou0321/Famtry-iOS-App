# Famtry

A shared pantry app for families and housemates. Keep one list of pantry and fridge items, track quantities and expiration dates, and coordinate who owns what—all in one place.

## Features

- **Account & family**
  - Sign up and log in with email/password
  - Create a family or join an existing one (by family ID or search)
  - View and manage family members; leave a family when needed

- **Pantry**
  - View a shared list of items (name, quantity, expiration)
  - Add items with optional expiration dates
  - Edit or delete items (owners only)
  - Pull-to-refresh to sync with the server

- **Ownership**
  - Each item has one or more owners
  - Non-owners can request ownership; owners can approve or reject requests
  - Pending requests are visible on the item detail screen

- **Expiration & notifications**
  - Items are sorted by expiration date (soonest first)
  - In-app alert when items expire tomorrow (once per day)
  - Local notifications for items expiring in one day (scheduled the day before at 9:00 AM)

- **Profile**
  - Edit profile (name, avatar, gender, region, phone, signature)
  - Log out

## Tech Stack

- **Platform:** iOS (SwiftUI)
- **Language:** Swift 5
- **Architecture:** SwiftUI views + `ObservableObject` app state (`PantryData`)
- **Networking:** `URLSession`-based `APIClient` (async/await)
- **Notifications:** `UserNotifications` for expiration reminders

## Project Structure

```
famtry/
├── famtryApp.swift          # App entry, RootFlowView, tab navigation, expiration alert
├── PantryData.swift         # App state: user, family, items; API-backed helpers
├── APIClient.swift          # REST API client (auth, family, items, profile)
├── NotificationManager.swift # Local expiration notifications
├── WelcomeScreen.swift      # Onboarding / welcome content
├── LoginCreateUserScreen.swift # Login & sign up
├── CreateOrJoinFamilyScreen.swift # Create or join a family
├── PantryOverviewScreen.swift   # Pantry list, add item, delete
├── AddItemScreen.swift      # Add new pantry item
├── ItemDetailScreen.swift   # View/edit item, ownership, pending requests
├── FamilyMembersScreen.swift   # Family members list
├── ProfileScreen.swift      # Profile entry, login/logout
├── EditProfileScreen.swift  # Edit profile fields
├── ContentView.swift        # (placeholder / unused)
└── Assets.xcassets/        # App icon, accent color
```

## Prerequisites

- Xcode (Swift 5, iOS project)
- Apple Developer account (for running on a device; simulator works without)
- Backend server running or use the hosted API (see below)

## Getting Started

1. **Clone the repo**
   ```bash
   git clone https://github.com/echou0321/Famtry-iOS-App.git
   cd Famtry-iOS-App
   ```

2. **Open in Xcode**
   ```bash
   open famtry.xcodeproj
   ```

3. **Select a target**
   - Choose the `famtry` scheme and an iPhone simulator or device.

4. **Build and run**
   - ⌘R to build and run. The app will use the default API base URL (see below).

## Backend / API

The app talks to a REST API for auth, families, and pantry items. The base URL is set in `APIClient.swift`:

```swift
var baseURL = URL(string: "https://famtry-backend-server-rkq1.onrender.com/api")!
```

- **Hosted API:** [https://famtry-backend-server-rkq1.onrender.com/api](https://famtry-backend-server-rkq1.onrender.com/api)  
- **Backend source:** [Famtry-Backend-Server](https://github.com/echou0321/Famtry-Backend-Server)

To use a local or different backend, change `baseURL` in `APIClient.swift` and ensure the server implements the same endpoints (e.g. `/users/login`, `/users/register`, `/families`, `/items/...`).

## Notifications

- The app requests notification permission on launch.
- Expiration notifications are scheduled for the day before an item’s expiration date at 9:00 AM local time.
- Notifications are managed in `NotificationManager`; scheduling/removal is tied to add/edit/delete of items where applicable.

## Related

- **Project presentation:** [Google Slides](https://docs.google.com/presentation/d/1BeH9YsgMqBj2vOyWp7phTxydBPv_V9VeBCb1VVgm0Fw/edit?usp=sharing)
- **Backend repository:** [Famtry-Backend-Server](https://github.com/echou0321/Famtry-Backend-Server)

## License

See repository for license information.
