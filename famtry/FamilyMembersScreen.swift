//
//  PantryOverviewScreen.swift
//  famtry
//
//  Created by Frecesca Wang.
//

import SwiftUI

struct FamilyMembersScreen: View {
    @EnvironmentObject var data: PantryData

    @State private var members: [APIClient.FamilyMember] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCopied = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading members...")
            } else if let errorMessage {
                errorView(message: errorMessage)
            } else {
                membersList
            }
        }
        .navigationTitle("Family Members")
        .task {
            await fetchMembers()
        }
    }

    // MARK: - Members List

    private var membersList: some View {
        List {
            // Copy family code section
            Section {
                Button {
                    copyFamilyCode()
                } label: {
                    HStack {
                        Label("Family Code", systemImage: "doc.on.doc")
                            .foregroundColor(.primary)

                        Spacer()

                        if showCopied {
                            Text("Copied!")
                                .font(.caption)
                                .foregroundColor(.green)
                                .transition(.opacity)
                        } else {
                            Text(truncatedFamilyId)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Image(systemName: "doc.on.clipboard")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Share this code with family members so they can join.")
            }

            // Members section
            Section("Members (\(members.count))") {
                ForEach(sortedMembers) { member in
                    memberRow(member: member)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Member Row

    private func memberRow(member: APIClient.FamilyMember) -> some View {
        let isCurrentUser = member.id == data.currentUser?.id

        return HStack(spacing: 12) {
            // Initial circle
            ZStack {
                Circle()
                    .fill(isCurrentUser ? Color.black : Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)

                Text(String(member.name.prefix(1)).uppercased())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isCurrentUser ? .white : .primary)
            }

            // Name and email
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(.body)
                        .fontWeight(isCurrentUser ? .semibold : .regular)

                    if isCurrentUser {
                        Text("You")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black)
                            .cornerRadius(4)
                    }
                }

                Text(member.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "wifi.exclamationmark")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                Task { await fetchMembers() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)

            Spacer()
        }
    }

    // MARK: - Helpers

    private var sortedMembers: [APIClient.FamilyMember] {
        members.sorted { a, _ in
            a.id == data.currentUser?.id
        }
    }

    private var truncatedFamilyId: String {
        guard let id = data.currentFamily?.id else { return "" }
        if id.count > 8 {
            return String(id.prefix(8)) + "..."
        }
        return id
    }

    private func copyFamilyCode() {
        guard let familyId = data.currentFamily?.id else { return }
        UIPasteboard.general.string = familyId

        withAnimation {
            showCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopied = false
            }
        }
    }

    private func fetchMembers() async {
        guard let familyId = data.currentFamily?.id else {
            errorMessage = "No family found."
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            members = try await APIClient.shared.getFamilyMembers(familyId: familyId)
            isLoading = false
        } catch {
            errorMessage = "Could not load family members. Please try again."
            isLoading = false
        }
    }
}

#Preview {
    NavigationView {
        FamilyMembersScreen()
            .environmentObject(PantryData())
    }
}
