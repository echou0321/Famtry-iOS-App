//
//  PantryOverviewScreen.swift
//  famtry
//
//  Created by Frecesca Wang.
//

import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject var data: PantryData

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

                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Text(user.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Settings-style grouped list
            List {
                // Family section
                Section("Family") {
                    if let family = data.currentFamily {
                        HStack {
                            Label(family.name, systemImage: "house.fill")
                            Spacer()
                        }

                        NavigationLink {
                            FamilyMembersScreen()
                        } label: {
                            Label("Family Members", systemImage: "person.3.fill")
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
