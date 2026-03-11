//
//  PantryOverviewScreen.swift
//  famtry
//
//  Created by Frecesca Wang.
//

import SwiftUI

struct WelcomeScreen: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Welcome to Famtry")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    Text("One shared pantry for your family or housemates.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("What you can do:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• See a shared list of pantry / fridge items.")
                        Text("• Track quantities and expiration dates together.")
                        Text("• Share ownership and approve requests.")
                    }
                    .font(.footnote)
                    .foregroundColor(.black)
                }
                .padding(.horizontal, 32)

                Spacer()

                Text("To get started, go to the Profile tab (bottom right) to sign up or log in.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

#Preview {
    WelcomeScreen()
}

