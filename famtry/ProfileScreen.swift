import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject var data: PantryData
    @State private var isEditingProfile = false
    @State private var isLeavingFamily = false
    @State private var leaveError: String?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if let user = data.currentUser {
                loggedInView(user: user)
            } else {
                loggedOutView
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $isEditingProfile) {
            EditProfileScreen()
        }
        .alert("Leave Family", isPresented: $isLeavingFamily) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task {
                    do {
                        try await data.leaveFamily()
                    } catch {
                        leaveError = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("Are you sure you want to leave this family?")
        }
        .alert("Error", isPresented: .init(
            get: { leaveError != nil },
            set: { if !$0 { leaveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(leaveError ?? "Unknown error")
        }
    }

    // MARK: - Logged In

    private func loggedInView(user: User) -> some View {
        VStack(spacing: 0) {
            // Profile header
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 72, height: 72)

                    if let avatar = user.avatar, !avatar.isEmpty {
                        AsyncImage(url: URL(string: avatar)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                    } else {
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }

                Text(user.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let signature = user.signature, !signature.isEmpty {
                    Text(signature)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.top, 4)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Settings-style grouped list
            List {
                Section {

                    if let gender = user.gender, !gender.isEmpty {
                        HStack {
                            Label("Gender", systemImage: "person.fill")
                            Spacer()
                            Text(gender.capitalized)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let region = user.region, !region.isEmpty {
                        HStack {
                            Label("Region", systemImage: "location.fill")
                            Spacer()
                            Text(region)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let phone = user.phone, !phone.isEmpty {
                        HStack {
                            Label("Phone", systemImage: "phone.fill")
                            Spacer()
                            Text(phone)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Family section
                Section("Family") {
                    if let family = data.currentFamily {
                        HStack {
                            Label(family.name, systemImage: "house.fill")
                            Spacer()
                            Text("\(family.memberIds.count) members")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }

                        NavigationLink {
                            FamilyMembersScreen()
                        } label: {
                            Label("Family Members", systemImage: "person.3.fill")
                        }

                        Button(role: .destructive) {
                            isLeavingFamily = true
                        } label: {
                            Label("Leave Family", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        NavigationLink {
                            CreateOrJoinFamilyScreen()
                                .navigationTitle("Family")
                        } label: {
                            Label("Create or Join Family", systemImage: "person.badge.plus")
                        }
                    }
                }

                // Logout section
                Section {
                    Button(role: .destructive) {
                        data.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Logged Out

    private var loggedOutView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundColor(.secondary)

            Text("You are not logged in.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                NavigationLink {
                    LoginCreateUserScreen(mode: .login)
                } label: {
                    Text("Log In")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .cornerRadius(10)
                }

                NavigationLink {
                    LoginCreateUserScreen(mode: .register)
                } label: {
                    Text("Sign Up")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        ProfileScreen()
            .environmentObject(PantryData())
    }
}
