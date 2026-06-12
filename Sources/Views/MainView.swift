import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct MainView: View {
    @ObservedObject var timerManager = TimerManager.shared
    
    // UI Local State for Config Input Fields (Inactive State)
    @State private var domainInput: String = ""
    @State private var appInput: String = ""
    
    // UI Local State for Config Input Fields (Active State Additions)
    @State private var activeDomainInput: String = ""
    @State private var activeAppInput: String = ""
    
    // Live block addition confirmation message
    @State private var activeBlockAdditionMessage: String? = nil
    
    // Live timer extension confirmation message
    @State private var activeTimerExtensionMessage: String? = nil
    
    // Duration Inputs
    @State private var durationDaysInput: String = "0"
    @State private var durationHoursInput: String = "0"
    @State private var durationMinutesInput: String = "25"
    
    @State private var showingBypassView = false
    
    // Recovery / Emergency Restore Visual Notifications
    @State private var hostsResetMessage: String? = nil
    @State private var hostsResetSuccess = false
    
    // Onboarding State
    @State private var hasOnboarded = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    // Website Blocking Permission Popup States
    @State private var showingPermissionAlert = false
    @State private var durationSecondsPending: TimeInterval = 0
    
    // Extension Inputs
    @State private var extendDaysInput: String = "0"
    @State private var extendHoursInput: String = "0"
    @State private var extendMinutesInput: String = "0"
    
    // Irreversible Action Warnings
    @State private var showingIrreversibleWarning = false
    @State private var pendingActionDescription: String = ""
    @State private var pendingAction: (() -> Void)? = nil
    
    private var isDurationValid: Bool {
        let days = Double(durationDaysInput) ?? 0
        let hours = Double(durationHoursInput) ?? 0
        let mins = Double(durationMinutesInput) ?? 0
        return (days * 24 * 3600 + hours * 3600 + mins * 60) > 0
    }
    
    private var isExtendDurationValid: Bool {
        let days = Double(extendDaysInput) ?? 0
        let hours = Double(extendHoursInput) ?? 0
        let mins = Double(extendMinutesInput) ?? 0
        return (days * 24 * 3600 + hours * 3600 + mins * 60) > 0
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !hasOnboarded {
                    onboardingView
                } else if timerManager.state.isActive {
                    activeBlockDashboard
                } else {
                    inactiveBlockConfigurator
                }
            }
            .frame(width: 500, height: 620)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.03, green: 0.03, blue: 0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationDestination(isPresented: $showingBypassView) {
                BypassView()
            }
            .alert("Website Blocking Setup", isPresented: $showingPermissionAlert) {
                Button("Grant Privileges") {
                    HostsHelper.grantWritePermission { success in
                        if success {
                            executeBlock(duration: durationSecondsPending)
                        } else {
                            hostsResetMessage = "Failed to obtain write permission. App blocking active."
                            hostsResetSuccess = false
                            executeBlock(duration: durationSecondsPending)
                        }
                    }
                }
                Button("App Blocking Only") {
                    executeBlock(duration: durationSecondsPending)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Oathkeeper needs administrator privileges to configure website blocking (modifying /etc/hosts). Click 'Grant Privileges' to authorize with your macOS password, or choose 'App Blocking Only' to continue without it.")
            }
            .alert("Irreversible Action Warning", isPresented: $showingIrreversibleWarning) {
                Button("Confirm", role: .destructive) {
                    pendingAction?()
                    pendingAction = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingAction = nil
                }
            } message: {
                Text(pendingActionDescription + "\n\nThis action cannot be undone until the current block expires. Are you sure you want to proceed?")
            }
            .onChange(of: durationDaysInput) { oldValue, newValue in
                durationDaysInput = cleanInput(newValue, max: 29)
            }
            .onChange(of: durationHoursInput) { oldValue, newValue in
                durationHoursInput = cleanInput(newValue, max: 23)
            }
            .onChange(of: durationMinutesInput) { oldValue, newValue in
                durationMinutesInput = cleanInput(newValue, max: 59)
            }
            .onChange(of: extendDaysInput) { oldValue, newValue in
                extendDaysInput = cleanInput(newValue, max: 29)
            }
            .onChange(of: extendHoursInput) { oldValue, newValue in
                extendHoursInput = cleanInput(newValue, max: 23)
            }
            .onChange(of: extendMinutesInput) { oldValue, newValue in
                extendMinutesInput = cleanInput(newValue, max: 59)
            }
        }
    }
    
    // MARK: - Inactive Block Configuration View
    private var inactiveBlockConfigurator: some View {
        VStack(spacing: 12) {
            // Header Title
            VStack(spacing: 8) {
                if let appIcon = NSImage(named: "NSApplicationIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)
                }
                
                Text("OATHKEEPER")
                    .font(.system(size: 26, weight: .black, design: .default))
                    .tracking(6)
                    .foregroundColor(.white)
                
                Text("Lock away distractions, honor your focus.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 15)
            
            // Privilege warning if hosts file not writable
            if !HostsHelper.hasWritePermission() {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Website Blocking Restricted")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Oathkeeper needs permission to modify your system hosts file. Click 'Enable Website Blocking' to authorize, or continue using app blocking only.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(nil)
                        
                        Button(action: {
                            HostsHelper.grantWritePermission { success in
                                if success {
                                    hostsResetMessage = "Website blocking enabled successfully!"
                                    hostsResetSuccess = true
                                } else {
                                    hostsResetMessage = "Failed to obtain permission."
                                    hostsResetSuccess = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                    hostsResetMessage = nil
                                }
                            }
                        }) {
                            Text("Enable Website Blocking")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
            }
            
            // Lists Configuration (Websites & Apps)
            HStack(spacing: 15) {
                // Websites Block List
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Block Websites")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        Text("(Separate with spaces or commas to batch add)")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    
                    HStack {
                        TextField("e.g. reddit.com", text: $domainInput)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(5)
                            .foregroundColor(.white)
                        
                        Button(action: addDomain) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    List {
                        ForEach(timerManager.state.blockedDomains, id: \.self) { domain in
                            HStack {
                                Text(domain)
                                    .foregroundColor(.white)
                                    .font(.caption)
                                Spacer()
                                // Deletion button (using onTapGesture directly to prevent macOS SwiftUI List event swallowing)
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.8))
                                    .font(.caption)
                                    .padding(6)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        removeDomain(domain)
                                    }
                            }
                            .listRowBackground(Color.white.opacity(0.02))
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // Apps Block List
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Block Apps")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        Text("(Enter single app names, spaces allowed)")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    
                    Button(action: selectAppFromFinder) {
                        HStack {
                            Image(systemName: "square.grid.3x3.fill")
                            Text("Choose Application...")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    List {
                        ForEach(timerManager.state.blockedApps, id: \.self) { app in
                            HStack {
                                Text(app)
                                    .foregroundColor(.white)
                                    .font(.caption)
                                Spacer()
                                // Deletion button (using onTapGesture directly to prevent macOS SwiftUI List event swallowing)
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.8))
                                    .font(.caption)
                                    .padding(6)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        removeApp(app)
                                    }
                            }
                            .listRowBackground(Color.white.opacity(0.02))
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .frame(height: 200)
            
            // Duration and Bypass configuration card
            VStack(spacing: 8) {
                // Duration Fields (Days, Hours, Minutes)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Block Duration:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        // Days Box
                        VStack(spacing: 2) {
                            TextField("0", text: $durationDaysInput)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(5)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text("days")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                        
                        // Hours Box
                        VStack(spacing: 2) {
                            TextField("0", text: $durationHoursInput)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(5)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text("hours")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                        
                        // Minutes Box
                        VStack(spacing: 2) {
                            TextField("25", text: $durationMinutesInput)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(5)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text("mins")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
                
                Toggle(isOn: $timerManager.state.blockSystemUtilities) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Block System Utilities (Highly Recommended)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text("Blocks Terminal and Activity Monitor to prevent app deletion")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding(.horizontal)
                .padding(.top, 4)
            }
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.02))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Visual Banner for Recovery Status
            if let msg = hostsResetMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(hostsResetSuccess ? .green : .red)
                    .fontWeight(.semibold)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(hostsResetSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(6)
                    .transition(.opacity)
            }
            
            // Focus and Restore buttons
            VStack(spacing: 8) {
                // Start Block Button
                Button(action: startBlock) {
                    Text("Start Focus Block")
                        .font(.headline)
                        .foregroundColor(isDurationValid ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                if isDurationValid {
                                    LinearGradient(
                                        colors: [Color.blue, Color(red: 0.1, green: 0.4, blue: 0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    Color.white.opacity(0.05)
                                }
                            }
                        )
                        .cornerRadius(10)
                        .shadow(color: isDurationValid ? Color.blue.opacity(0.2) : Color.clear, radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!isDurationValid)
                
                // Emergency Hosts Reset Button (unblocks /etc/hosts manually when app is inactive)
                Button(action: resetHosts) {
                    HStack {
                        Image(systemName: "exclamationmark.shield")
                        Text("Emergency Restore /etc/hosts")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Quit App Button (only visible/accessible when not in block mode)
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit Oathkeeper")
                    }
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
    
    // MARK: - Active Block Dashboard View
    private var activeBlockDashboard: some View {
        VStack(spacing: 15) {
            Text("OATHKEEPER ACTIVE")
                .font(.system(size: 16, weight: .bold, design: .default))
                .tracking(8)
                .foregroundColor(Color.red.opacity(0.8))
                .padding(.top, 25)
            
            // Circular Countdown Progress View
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 16)
                    .frame(width: 170, height: 170)
                
                // Glowing/Colored active ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(timerManager.state.remainingSeconds / (timerManager.state.totalDuration > 0 ? timerManager.state.totalDuration : 1500.0)))
                    .stroke(
                        AngularGradient(
                            colors: [Color.blue, Color.purple, Color.red, Color.blue],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
                    .frame(width: 170, height: 170)
                    .shadow(color: Color.red.opacity(0.4), radius: 10, x: 0, y: 0)
                    .animation(.linear(duration: 1.0), value: timerManager.state.remainingSeconds)
                
                // Text inside Circle
                VStack(spacing: 4) {
                    Text(timeString(from: timerManager.state.remainingSeconds))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("remaining")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 5)
            
            // Status and Block counts
            HStack(spacing: 30) {
                VStack(spacing: 3) {
                    Text("\(timerManager.state.blockedDomains.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Websites Blocked")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 3) {
                    Text("\(timerManager.state.blockedApps.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Apps Blocked")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 3) {
                    Text(timerManager.state.blockSystemUtilities ? "Blocked" : "Allowed")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(timerManager.state.blockSystemUtilities ? Color.red.opacity(0.8) : .green)
                    Text("System Utilities")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
            
            // ADD ITEMS LIVE DURING THE FOCUS BLOCK
            VStack(spacing: 8) {
                Text("Add items (separate websites with spaces or commas):")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    // Live Website addition field
                    HStack {
                        TextField("Add website...", text: $activeDomainInput)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(5)
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        Button(action: addActiveDomain) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Live App selection button
                    Button(action: selectAppFromFinder) {
                        HStack {
                            Image(systemName: "square.grid.3x3.fill")
                            Text("Choose App...")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 15)
                
                if let msg = activeBlockAdditionMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                        .padding(.top, 4)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .padding(.horizontal, 25)
            
            // EXTEND TIME LIVE
            VStack(spacing: 8) {
                Text("Extend block duration:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .fontWeight(.semibold)
                
                HStack(spacing: 15) {
                    HStack(spacing: 4) {
                        TextField("0", text: $extendDaysInput)
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(width: 30)
                            .multilineTextAlignment(.center)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                        Text("d")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    HStack(spacing: 4) {
                        TextField("0", text: $extendHoursInput)
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(width: 30)
                            .multilineTextAlignment(.center)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                        Text("h")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    HStack(spacing: 4) {
                        TextField("0", text: $extendMinutesInput)
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(width: 30)
                            .multilineTextAlignment(.center)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                        Text("m")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: triggerExtendTime) {
                        Text("Extend")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(isExtendDurationValid ? .white : .gray)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)
                            .background(isExtendDurationValid ? Color.blue : Color.white.opacity(0.1))
                            .cornerRadius(5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!isExtendDurationValid)
                }
                
                if let msg = activeTimerExtensionMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                        .padding(.top, 4)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .padding(.horizontal, 25)
            
            // Currently Blocked Lists
            HStack(spacing: 15) {
                // Websites List
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blocked Websites")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    
                    List {
                        ForEach(timerManager.state.blockedDomains, id: \.self) { domain in
                            HStack {
                                Image(systemName: "globe")
                                    .font(.caption)
                                    .foregroundColor(.blue.opacity(0.8))
                                Text(domain)
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                            .listRowBackground(Color.white.opacity(0.02))
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // Apps List
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blocked Apps")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    
                    List {
                        ForEach(timerManager.state.blockedApps, id: \.self) { app in
                            HStack {
                                Image(systemName: "cpu")
                                    .font(.caption)
                                    .foregroundColor(.purple.opacity(0.8))
                                Text(app)
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                            .listRowBackground(Color.white.opacity(0.02))
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 25)
            .frame(height: 120)
            
            // Control Buttons
            VStack(spacing: 8) {
                HStack(spacing: 15) {
                    // Sync Network Time
                    Button(action: {
                        timerManager.syncWithNetworkTime()
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.2.circlepath")
                            Text("Sync Time")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Emergency Unlock navigation
                    Button(action: {
                        showingBypassView = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                            Text("Emergency")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.bottom, 25)
        }
    }
    
    // MARK: - Action Helpers
    
    private func addDomain() {
        let input = domainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        // Split by spaces, tabs, newlines, or commas to support batch entries
        let domains = input.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for domain in domains {
            timerManager.addDomain(domain)
        }
        domainInput = ""
    }
    
    private func removeDomain(_ domain: String) {
        timerManager.removeDomain(domain)
    }
    
    private func addApp() {
        let app = appInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !app.isEmpty else { return }
        timerManager.addApp(app)
        appInput = ""
    }
    
    private func removeApp(_ app: String) {
        timerManager.removeApp(app)
    }
    
    private func selectAppFromFinder() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Application to Block"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        openPanel.allowedContentTypes = [.application, .bundle]
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                let rawName = url.lastPathComponent
                let appName = rawName.replacingOccurrences(of: ".app", with: "")
                
                let lowerName = appName.lowercased()
                if lowerName == "oathkeeper" || lowerName.contains("oathkeeper") {
                    activeBlockAdditionMessage = "Cannot block Oathkeeper itself."
                    hostsResetMessage = "Cannot block Oathkeeper itself."
                    hostsResetSuccess = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        activeBlockAdditionMessage = nil
                        hostsResetMessage = nil
                    }
                    return
                }
                
                if timerManager.state.isActive {
                    pendingActionDescription = "You are about to add the application '\(appName)' to the current focus block."
                    pendingAction = {
                        timerManager.addApp(appName)
                        activeBlockAdditionMessage = "Added \(appName) to block list!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            activeBlockAdditionMessage = nil
                        }
                    }
                    showingIrreversibleWarning = true
                } else {
                    timerManager.addApp(appName)
                }
            }
        }
    }
    
    private func formatDurationDescription(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        var parts: [String] = []
        if days > 0 {
            parts.append("\(days) day\(days == 1 ? "" : "s")")
        }
        if hours > 0 {
            parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        if minutes > 0 || parts.isEmpty {
            parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        }
        
        return parts.joined(separator: ", ")
    }
    
    private func cleanInput(_ input: String, max maxValue: Int) -> String {
        let filtered = input.filter { $0.isNumber }
        guard let value = Int(filtered) else {
            return ""
        }
        if value > maxValue {
            return String(maxValue)
        }
        // Normalize leading zeros
        if filtered.hasPrefix("0") && filtered.count > 1 {
            return String(value)
        }
        return filtered
    }
    
    // Live configuration addition during active block
    private func addActiveDomain() {
        let input = activeDomainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        let domains = input.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            
        guard !domains.isEmpty else { return }
        
        pendingActionDescription = "You are about to add \(domains.count) website(s) to the current focus block."
        pendingAction = {
            for domain in domains {
                timerManager.addDomain(domain)
            }
            activeDomainInput = ""
            activeBlockAdditionMessage = "Added websites to block list!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                activeBlockAdditionMessage = nil
            }
        }
        showingIrreversibleWarning = true
    }
    
    private func triggerExtendTime() {
        let days = Double(extendDaysInput) ?? 0
        let hours = Double(extendHoursInput) ?? 0
        let mins = Double(extendMinutesInput) ?? 0
        let totalSeconds = (days * 24 * 3600) + (hours * 3600) + (mins * 60)
        
        guard totalSeconds > 0 else { return }
        
        let currentRemaining = timerManager.state.remainingSeconds
        let maxSeconds = (29.0 * 24.0 * 3600.0) + (23.0 * 3600.0) + (59.0 * 60.0)
        let allowedExtension = max(0, maxSeconds - currentRemaining)
        
        if allowedExtension <= 0 {
            activeTimerExtensionMessage = "Cannot exceed 29 days, 23 hours, 59 minutes total block time!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                activeTimerExtensionMessage = nil
            }
            return
        }
        
        let finalExtension = min(totalSeconds, allowedExtension)
        let durationStr = formatDurationDescription(finalExtension)
        
        pendingActionDescription = "You are about to extend the current focus block by \(durationStr)."
        if finalExtension < totalSeconds {
            pendingActionDescription += "\n(Capped to keep total block duration under 29 days, 23 hours, 59 minutes)"
        }
        
        pendingAction = {
            timerManager.extendBlock(by: finalExtension)
            extendDaysInput = "0"
            extendHoursInput = "0"
            extendMinutesInput = "0"
            activeTimerExtensionMessage = "Timer extended!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                activeTimerExtensionMessage = nil
            }
        }
        showingIrreversibleWarning = true
    }
    
    private func addActiveApp() {
        let app = activeAppInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !app.isEmpty else { return }
        timerManager.addApp(app)
        activeAppInput = ""
    }
    
    private func startBlock() {
        let days = Double(durationDaysInput) ?? 0
        let hours = Double(durationHoursInput) ?? 0
        let mins = Double(durationMinutesInput) ?? 0
        let totalSeconds = (days * 24 * 3600) + (hours * 3600) + (mins * 60)
        
        guard totalSeconds > 0 else { return }
        
        // Cap the total seconds at 29 days, 23 hours, 59 minutes
        let maxSeconds = (29.0 * 24.0 * 3600.0) + (23.0 * 3600.0) + (59.0 * 60.0)
        let finalSeconds = min(maxSeconds, max(10, totalSeconds))
        
        let blockExecution = {
            if HostsHelper.hasWritePermission() {
                self.executeBlock(duration: finalSeconds)
            } else {
                self.durationSecondsPending = finalSeconds
                self.showingPermissionAlert = true
            }
        }
        
        if finalSeconds > 24 * 3600 {
            let durationStr = formatDurationDescription(finalSeconds)
            pendingActionDescription = "You are about to start a focus block that will last for \(durationStr)."
            if totalSeconds > maxSeconds {
                pendingActionDescription += "\n(Capped to keep block duration under 29 days, 23 hours, 59 minutes)"
            }
            pendingAction = blockExecution
            showingIrreversibleWarning = true
        } else {
            blockExecution()
        }
    }
    
    private func executeBlock(duration: TimeInterval) {
        timerManager.startBlock(
            duration: duration,
            bypassMethod: "typing",
            bypassDuration: 1200 // unused but kept for compatibility
        )
    }
    
    private func resetHosts() {
        if HostsHelper.hasWritePermission() {
            executeResetHosts()
        } else {
            HostsHelper.grantWritePermission { success in
                if success {
                    executeResetHosts()
                } else {
                    hostsResetMessage = "Failed to obtain write permission."
                    hostsResetSuccess = false
                }
            }
        }
    }
    
    private func executeResetHosts() {
        do {
            try HostsHelper.removeBlock()
            hostsResetMessage = "Hosts file manually unblocked successfully!"
            hostsResetSuccess = true
        } catch {
            hostsResetMessage = "Error: \(error.localizedDescription)"
            hostsResetSuccess = false
        }
        
        // Clear recovery notification after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.hostsResetMessage = nil
        }
    }
    
    // MARK: - Onboarding Setup View
    private var onboardingView: some View {
        VStack(spacing: 25) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 70))
                .foregroundColor(.blue)
                .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text("Welcome to Oathkeeper")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your distraction-free focus space.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Website Blocking")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Oathkeeper locks chosen websites system-wide. To enable this, we need write permissions to your local hosts file.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(nil)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Blocking")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Prevent distracting apps from opening during active focus blocks.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(nil)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: {
                    HostsHelper.grantWritePermission { success in
                        hasOnboarded = true
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    }
                }) {
                    Text("Enable Website Blocking")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    hasOnboarded = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }) {
                    Text("App Blocking Only")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 30)
        }
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
