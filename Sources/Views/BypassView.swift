import SwiftUI

struct BypassView: View {
    @ObservedObject var timerManager = TimerManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    // Typing Marathon State Variables
    @State private var isMarathonStarted = false
    @State private var completedRounds = 0
    @State private var totalRounds = 120
    @State private var currentRandomString = ""
    @State private var roundTimeRemaining = 10.0
    @State private var flashRed = false
    @State private var marathonTimer: Timer? = nil
    @State private var userInput = ""
    
    // Typing Challenge Success/Fail State
    @State private var isRoundSuccessful = false
    @State private var failedAttemptsCount = 0
    @State private var showResetBanner = false
    @State private var resetBannerMessage = ""
    
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 25) {
            // Header
            HStack {
                Button(action: {
                    cleanupAndDismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Emergency Unlock")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .opacity(0)
            }
            .padding(.horizontal)
            
            typingChallengeBypassBody
            
            Spacer()
        }
        .padding(.vertical, 20)
        .frame(width: 500, height: 480)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.03, green: 0.03, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onDisappear {
            stopAllTimers()
        }
    }
    
    // MARK: - Typing Challenge Bypass View (Marathon)
    private var typingChallengeBypassBody: some View {
        VStack(spacing: 15) {
            if !isMarathonStarted {
                // Setup Screen
                VStack(spacing: 25) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                        .padding(.top, 10)
                    
                    Text("The Typing Marathon")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Type 10 random characters under a 10-second limit. Complete 120 rounds to unlock. You have exactly 5 strikes before progress resets back to Round 1.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 45)
                    
                    Button(action: {
                        isMarathonStarted = true
                        nextRound()
                    }) {
                        Text("Start Challenge")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 40)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            } else {
                // Running Challenge Screen
                VStack(spacing: 12) {
                    HStack {
                        Text("Round \(completedRounds + 1) of \(totalRounds)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.1fs left", roundTimeRemaining))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(roundTimeRemaining < 3.0 ? .red : .yellow)
                    }
                    .padding(.horizontal, 30)
                    
                    // Round Progress Indicators
                    HStack(spacing: 4) {
                        let maxVisibleDots = min(totalRounds, 20)
                        ForEach(0..<maxVisibleDots, id: \.self) { index in
                            Circle()
                                .fill(index < completedRounds ? Color.green : (index == completedRounds ? Color.yellow : Color.white.opacity(0.1)))
                                .frame(width: 8, height: 8)
                        }
                        if totalRounds > maxVisibleDots {
                            Text("...")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    
                    // Strikes indicator (Numeric layout, no emojis)
                    HStack {
                        Text("Strikes: \(failedAttemptsCount) / 5")
                            .font(.caption)
                            .foregroundColor(failedAttemptsCount > 0 ? .red : .gray)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if showResetBanner {
                            Text(resetBannerMessage)
                                .font(.caption2)
                                .foregroundColor(.red)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.horizontal, 30)
                    .frame(height: 20)
                    
                    // Target Word Display Card
                    VStack {
                        Text(currentRandomString)
                            .font(.system(size: 38, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 15)
                            .padding(.horizontal, 15)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isRoundSuccessful ? Color.green.opacity(0.15) : (flashRed ? Color.red.opacity(0.15) : Color.black.opacity(0.3)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isRoundSuccessful ? Color.green : (flashRed ? Color.red : Color.white.opacity(0.1)), lineWidth: 2)
                                    )
                            )
                            .scaleEffect(flashRed ? 1.05 : 1.0)
                            .animation(.spring(), value: flashRed)
                    }
                    .padding(.horizontal, 30)
                    
                    // Shrinking Visual Countdown Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)
                                .cornerRadius(3)
                            
                            Rectangle()
                                .fill(isRoundSuccessful ? Color.green : (roundTimeRemaining < 3.0 ? Color.red : Color.blue))
                                .frame(width: geo.size.width * CGFloat(roundTimeRemaining / 10.0), height: 6)
                                .cornerRadius(3)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 30)
                    
                    // Input Textfield
                    TextField(isRoundSuccessful ? "Success! Wait out the timer..." : "Type phrase here...", text: $userInput)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .textFieldStyle(PlainTextFieldStyle())
                        .multilineTextAlignment(.center)
                        .autocorrectionDisabled(true)
                        .focused($isInputFocused)
                        .disabled(isRoundSuccessful) // Lock edits once correctly matched
                        .padding(.vertical, 10)
                        .background(isRoundSuccessful ? Color.green.opacity(0.1) : Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isRoundSuccessful ? Color.green.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .padding(.horizontal, 30)
                        .onChange(of: userInput) { oldValue, newValue in
                            // Successful word sequence match check
                            if newValue.trimmingCharacters(in: .whitespaces) == currentRandomString {
                                isRoundSuccessful = true
                                NSSound(named: "Glass")?.play() // Play success chime
                            }
                        }
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    // MARK: - Typing Marathon Logic
    private func nextRound() {
        userInput = ""
        currentRandomString = generateRandomString()
        roundTimeRemaining = 10.0
        isRoundSuccessful = false
        
        stopMarathonTimer()
        
        // Auto-request focus for the input field
        DispatchQueue.main.async {
            self.isInputFocused = true
        }
        
        let t = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.roundTimeRemaining -= 0.1
                
                if self.roundTimeRemaining <= 0 {
                    self.roundTimeRemaining = 0
                    self.stopMarathonTimer()
                    
                    if self.isRoundSuccessful {
                        // Advanced to next round only after waiting out 10 seconds successfully
                        self.completedRounds += 1
                        if self.completedRounds >= self.totalRounds {
                            self.timerManager.completeBypass()
                            self.cleanupAndDismiss()
                        } else {
                            self.nextRound()
                        }
                    } else {
                        // Failed to complete within 10 seconds
                        self.failRound()
                    }
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        marathonTimer = t
    }
    
    private func failRound() {
        stopMarathonTimer()
        flashRed = true
        userInput = ""
        isRoundSuccessful = false
        
        NSSound.beep() // Audible alert for failure
        
        failedAttemptsCount += 1
        
        let maxAllowed = 5
        
        if failedAttemptsCount > maxAllowed {
            completedRounds = 0
            failedAttemptsCount = 0
            resetBannerMessage = "5 strikes exceeded! Reset back to Round 1."
            showResetBanner = true
        } else {
            resetBannerMessage = ""
            showResetBanner = false
        }
        
        // Dismiss warning banner after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.showResetBanner = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.flashRed = false
            self.nextRound()
        }
    }
    
    private func generateRandomString() -> String {
        let keyboardChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:',.<>/?~`"
        return String((0..<10).map { _ in keyboardChars.randomElement()! })
    }
    
    // MARK: - Timer Utilities
    private func stopMarathonTimer() {
        marathonTimer?.invalidate()
        marathonTimer = nil
    }
    
    private func stopAllTimers() {
        stopMarathonTimer()
    }
    
    private func cleanupAndDismiss() {
        stopAllTimers()
        presentationMode.wrappedValue.dismiss()
    }
}
