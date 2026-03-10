import SwiftUI

struct LoginCreateUserScreen: View {
    @EnvironmentObject var data: PantryData
    @Environment(\.dismiss) var dismiss

    enum Mode: String, CaseIterable, Identifiable {
        case login = "Login"
        case register = "Register"

        var id: String { rawValue }
    }

    let mode: Mode

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(mode == .login ? "Log In" : "Sign Up")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    Text("Famtry · Shared Family Pantry")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 12) {
                    if mode == .register {
                        Text("Name")
                            .font(.subheadline)
                            .foregroundColor(.black)

                        TextField("e.g. Frecesca", text: $name)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(true)
                            .foregroundColor(.black)
                    }

                    Text("Email")
                        .font(.subheadline)
                        .foregroundColor(.black)

                    TextField("e.g. alice@example.com", text: $email)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .foregroundColor(.black)

                    Text("Password")
                        .font(.subheadline)
                        .foregroundColor(.black)

                    SecureField("At least 6 characters", text: $password)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .textInputAutocapitalization(.never)
                        .foregroundColor(.black)

                    if mode == .register {
                        Text("Confirm Password")
                            .font(.subheadline)
                            .foregroundColor(.black)

                        SecureField("Repeat password", text: $confirmPassword)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                            .textInputAutocapitalization(.never)
                            .foregroundColor(.black)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.black)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                Button(action: {
                    submit()
                }) {
                    Text(isSubmitting ? "Please wait..." : (mode == .login ? "Login" : "Register"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isFormValid ? Color.black : Color.gray)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 24)
                .disabled(!isFormValid || isSubmitting)

                Spacer()

                Text("This screen uses the backend HTTP/JSON API. If the server is sleeping (Render free tier), try again in a moment.")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var isFormValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode == .login {
            return !trimmedEmail.isEmpty && !trimmedPassword.isEmpty
        } else {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedName.isEmpty
                && !trimmedEmail.isEmpty
                && !trimmedPassword.isEmpty
                && trimmedPassword == trimmedConfirm
        }
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { @MainActor in
            do {
                if mode == .login {
                    try await data.login(email: trimmedEmail, password: trimmedPassword)
                } else {
                    try await data.register(name: trimmedName, email: trimmedEmail, password: trimmedPassword)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationView {
        LoginCreateUserScreen(mode: .login)
            .environmentObject(PantryData())
    }
}

#Preview {
    NavigationView {
        LoginCreateUserScreen(mode: .register)
        .environmentObject(PantryData())
    }
}

