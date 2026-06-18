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
    
    // Update Checker States
    @State private var checkingForUpdates = false
    @State private var updateMessage: String? = nil
    @State private var updateSuccess = false
    @State private var updateAlertPresented = false
    @State private var latestReleaseUrl: String = ""
    @State private var latestReleaseTag: String = ""
    @State private var latestReleaseDmgUrl: String = ""
    
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
                } else if timerManager.isBlockingActive {
                    activeBlockDashboard
                } else {
                    inactiveBlockConfigurator
                }
            }
            .frame(width: 500, height: 680)
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
            .alert("Update Available", isPresented: $updateAlertPresented) {
                if !latestReleaseDmgUrl.isEmpty {
                    Button("Install Update") {
                        startAutoUpdate()
                    }
                }
                Button("Download manually (GitHub)") {
                    if let url = URL(string: latestReleaseUrl) {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("A new version (\(latestReleaseTag)) of Oathkeeper is available. Click 'Install Update' to automatically download and install it.")
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
                            .onSubmit(addDomain)
                        
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
            }
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.02))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Block options bar (Terminal & Activity Monitor)
            HStack(spacing: 30) {
                Spacer()
                
                Toggle("Block Terminal", isOn: $timerManager.state.blockTerminal)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                
                Toggle("Block Activity Monitor", isOn: $timerManager.state.blockActivityMonitor)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.vertical, 10)
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
            
            // Visual Banner for Update Status
            if let msg = updateMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(updateSuccess ? .green : .red)
                    .fontWeight(.semibold)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(updateSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(6)
                    .transition(.opacity)
            }
            
            // Schedules Bypassed Today Banner
            if timerManager.isTodayVoided() {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.yellow)
                    Text("Schedules suspended for today.")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Resume Blocking") {
                        let remaining = timerManager.remainingSecondsForActiveSchedule()
                        if remaining > 0 {
                            let durationStr = timerManager.formatDurationDescription(remaining)
                            pendingActionDescription = "You are about to resume your focus schedule blocking. There is \(durationStr) remaining in the current scheduled block."
                        } else {
                            pendingActionDescription = "You are about to resume your focus schedule blocking."
                        }
                        pendingAction = {
                            timerManager.resumeScheduleBlock()
                        }
                        showingIrreversibleWarning = true
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
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
                
                // Manage Schedules Button (opens schedules configuration panel via NavigationLink)
                NavigationLink(destination: SchedulesListView()) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                        Text("Manage Focus Schedules")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
                
                // Secondary control row
                HStack(spacing: 12) {
                    // Emergency Hosts Reset Button (unblocks /etc/hosts manually when app is inactive)
                    Button(action: resetHosts) {
                        HStack {
                            Image(systemName: "exclamationmark.shield")
                            Text("Emergency Restore")
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Check for Updates Button (only accessible when not in block mode)
                    Button(action: checkForUpdates) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(checkingForUpdates ? "Checking..." : "Check for Updates")
                        }
                        .font(.caption)
                        .foregroundColor(.blue.opacity(0.8))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(checkingForUpdates)
                }
                
            }
            .padding(.horizontal)
            .padding(.bottom, 15)
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
            
            if timerManager.remainingGraceSeconds() > 0 {
                Button(action: {
                    timerManager.instantUnblock()
                }) {
                    Text("Instant Unblock (\(timerManager.remainingGraceSeconds())s)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.red)
                        .cornerRadius(8)
                        .shadow(color: Color.red.opacity(0.5), radius: 8)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.scale)
            }
            
            // Circular Countdown Progress View
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 16)
                    .frame(width: 170, height: 170)
                
                // Glowing/Colored active ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(
                        timerManager.state.isActive ?
                        (timerManager.state.remainingSeconds / (timerManager.state.totalDuration > 0 ? timerManager.state.totalDuration : 1500.0)) :
                        (timerManager.remainingSecondsForActiveSchedule() / (timerManager.totalDurationForActiveSchedule() > 0 ? timerManager.totalDurationForActiveSchedule() : 3600.0))
                    ))
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
                    .animation(.linear(duration: 1.0), value: timerManager.state.isActive ? timerManager.state.remainingSeconds : timerManager.remainingSecondsForActiveSchedule())
                
                // Text inside Circle
                VStack(spacing: 4) {
                    Text(timeString(from: timerManager.state.isActive ? timerManager.state.remainingSeconds : timerManager.remainingSecondsForActiveSchedule()))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(timerManager.state.isActive ? "remaining" : "schedule ends in")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 5)
            
            // Status and Block counts
            HStack(spacing: 16) {
                VStack(spacing: 3) {
                    Text("\(timerManager.state.blockedDomains.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Websites Blocked")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 3) {
                    Text("\(timerManager.state.blockedApps.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Apps Blocked")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 3) {
                    Button(action: {
                        if !timerManager.state.blockTerminal {
                            pendingActionDescription = "You are about to block Terminal."
                            pendingAction = {
                                timerManager.toggleTerminalBlocking()
                            }
                            showingIrreversibleWarning = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: timerManager.state.blockTerminal ? "checkmark.square.fill" : "square")
                                .font(.system(size: 14, weight: .bold))
                            Text(timerManager.state.blockTerminal ? "Blocked" : "Allowed")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(timerManager.state.blockTerminal ? Color.red.opacity(0.8) : .green)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(timerManager.state.blockTerminal)
                    
                    Text("Terminal")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 3) {
                    Button(action: {
                        if !timerManager.state.blockActivityMonitor {
                            pendingActionDescription = "You are about to block Activity Monitor."
                            pendingAction = {
                                timerManager.toggleActivityMonitorBlocking()
                            }
                            showingIrreversibleWarning = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: timerManager.state.blockActivityMonitor ? "checkmark.square.fill" : "square")
                                .font(.system(size: 14, weight: .bold))
                            Text(timerManager.state.blockActivityMonitor ? "Blocked" : "Allowed")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(timerManager.state.blockActivityMonitor ? Color.red.opacity(0.8) : .green)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(timerManager.state.blockActivityMonitor)
                    
                    Text("Activity Monitor")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
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
                            .onSubmit(addActiveDomain)
                        
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
                HStack(spacing: 12) {
                    // Sync Network Time
                    Button(action: {
                        timerManager.syncWithNetworkTime()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
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
                        .padding(.horizontal, 10)
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
        let durationStr = timerManager.formatDurationDescription(finalExtension)
        
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
    
    private func checkForUpdates() {
        guard !checkingForUpdates else { return }
        checkingForUpdates = true
        updateMessage = "Checking for updates..."
        updateSuccess = true
        
        let urlString = "https://api.github.com/repos/NoChar4Char/oathkeeper/releases/latest"
        guard let url = URL(string: urlString) else {
            checkingForUpdates = false
            updateMessage = "Invalid update URL."
            updateSuccess = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        request.setValue("Oathkeeper-App-Updater", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.checkingForUpdates = false
                
                if let error = error {
                    self.updateMessage = "Error: \(error.localizedDescription)"
                    self.updateSuccess = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        self.updateMessage = nil
                    }
                    return
                }
                
                guard let data = data else {
                    self.updateMessage = "No response data."
                    self.updateSuccess = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        self.updateMessage = nil
                    }
                    return
                }
                
                do {
                    struct GitHubAsset: Codable {
                        let name: String
                        let browser_download_url: String
                    }
                    struct GitHubRelease: Codable {
                        let tag_name: String
                        let html_url: String
                        let assets: [GitHubAsset]?
                    }
                    
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    let remoteTag = release.tag_name
                    let remoteUrl = release.html_url
                    
                    let localVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.4.0"
                    
                    let cleanLocal = localVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                    let cleanRemote = remoteTag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                    
                    if cleanRemote.compare(cleanLocal, options: .numeric) == .orderedDescending {
                        self.latestReleaseTag = remoteTag
                        self.latestReleaseUrl = remoteUrl
                        self.latestReleaseDmgUrl = ""
                        
                        if let assets = release.assets {
                            if let dmgAsset = assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) {
                                self.latestReleaseDmgUrl = dmgAsset.browser_download_url
                            }
                        }
                        
                        self.updateMessage = "New version \(remoteTag) is available!"
                        self.updateSuccess = true
                        self.updateAlertPresented = true
                    } else {
                        self.updateMessage = "Oathkeeper is up to date (Version \(localVersion))."
                        self.updateSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            if self.updateMessage == "Oathkeeper is up to date (Version \(localVersion))." {
                                self.updateMessage = nil
                            }
                        }
                    }
                } catch {
                    self.updateMessage = "Failed to parse update info."
                    self.updateSuccess = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        self.updateMessage = nil
                    }
                }
            }
        }
        task.resume()
    }
    
    private func startAutoUpdate() {
        guard !latestReleaseDmgUrl.isEmpty else { return }
        
        checkingForUpdates = true
        updateMessage = "Downloading update..."
        updateSuccess = true
        
        guard let url = URL(string: latestReleaseDmgUrl) else {
            checkingForUpdates = false
            updateMessage = "Invalid download URL."
            updateSuccess = false
            return
        }
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.checkingForUpdates = false
                    self.updateMessage = "Download failed: \(error.localizedDescription)"
                    self.updateSuccess = false
                    return
                }
                
                guard let localURL = localURL else {
                    self.checkingForUpdates = false
                    self.updateMessage = "Temp download file not found."
                    self.updateSuccess = false
                    return
                }
                
                let destinationURL = URL(fileURLWithPath: "/tmp/Oathkeeper.dmg")
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: localURL, to: destinationURL)
                    
                    self.updateMessage = "Installing update..."
                    self.runUpdateScript()
                } catch {
                    self.checkingForUpdates = false
                    self.updateMessage = "Failed to copy installer: \(error.localizedDescription)"
                    self.updateSuccess = false
                }
            }
        }
        downloadTask.resume()
    }
    
    private func runUpdateScript() {
        let scriptPath = "/tmp/update_oathkeeper.sh"
        let currentAppPath = Bundle.main.bundlePath
        
        let scriptContent = """
        #!/bin/bash
        sleep 1
        CURRENT_APP_PATH="\(currentAppPath)"
        MOUNT_POINT="/tmp/oathkeeper_mount"
        
        hdiutil detach "$MOUNT_POINT" -force 2>/dev/null || true
        mkdir -p "$MOUNT_POINT"
        
        hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_POINT" /tmp/Oathkeeper.dmg
        
        if [ -d "$MOUNT_POINT/Oathkeeper.app" ]; then
            chflags -R nouchg "$CURRENT_APP_PATH"
            rm -rf "$CURRENT_APP_PATH"
            cp -R "$MOUNT_POINT/Oathkeeper.app" "$CURRENT_APP_PATH"
            chflags -R uchg "$CURRENT_APP_PATH"
        fi
        
        hdiutil detach "$MOUNT_POINT" -force
        rm -f /tmp/Oathkeeper.dmg
        open "$CURRENT_APP_PATH"
        rm -f /tmp/update_oathkeeper.sh
        """
        
        do {
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            let chmodProcess = Process()
            chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodProcess.arguments = ["+x", scriptPath]
            try chmodProcess.run()
            chmodProcess.waitUntilExit()
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath]
            try process.run()
            
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            print("Failed to run update script: \(error.localizedDescription)")
            self.checkingForUpdates = false
            self.updateMessage = "Failed to start installer script."
            self.updateSuccess = false
        }
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
        
        let durationStr = timerManager.formatDurationDescription(finalSeconds)
        pendingActionDescription = "You are about to start a focus block that will last for \(durationStr)."
        if totalSeconds > maxSeconds {
            pendingActionDescription += "\n(Capped to keep block duration under 29 days, 23 hours, 59 minutes)"
        }
        pendingAction = blockExecution
        showingIrreversibleWarning = true
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

struct SchedulesListView: View {
    @ObservedObject var timerManager = TimerManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var confirmationMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    let now = Date()
                    if let activeRule = timerManager.state.schedules.first(where: { $0.isEnabled && $0.isActive(at: now) }) {
                        timerManager.pendingScheduleConfirmation = activeRule
                    } else {
                        dismiss()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Focus Schedules")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Balance spacing
                Text("Back")
                    .font(.subheadline)
                    .opacity(0)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(Color.white.opacity(0.02))
            

            
            // Add schedule and 24-hour mode toggle row
            HStack {
                Button(action: {
                    timerManager.addSchedule()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Focus Schedule")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Toggle("24-Hour Format", isOn: $timerManager.state.use24HourMode)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            
            // Schedules List
            ScrollView {
                VStack(spacing: 12) {
                    if timerManager.state.schedules.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.4))
                                .padding(.top, 40)
                            Text("No focus schedules yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("Create a recurring schedule to automatically block websites and applications.")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else {
                        ForEach($timerManager.state.schedules) { $rule in
                            ScheduleRuleRow(rule: $rule, use24HourMode: timerManager.state.use24HourMode, isLocked: false, onDelete: {
                                timerManager.deleteSchedule(rule.id)
                            })
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .frame(width: 500, height: 680)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.03, green: 0.03, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationBarBackButtonHidden(true)
        .onChange(of: timerManager.state.schedules) { oldValue, newValue in
            timerManager.saveState()
        }
        .onChange(of: timerManager.state.use24HourMode) { oldValue, newValue in
            timerManager.saveState()
        }
        .alert("Schedule Block Activation", isPresented: Binding(
            get: { timerManager.pendingScheduleConfirmation != nil },
            set: { if !$0 { timerManager.pendingScheduleConfirmation = nil } }
        )) {
            Button("Confirm") {
                timerManager.confirmPendingSchedule()
                dismiss()
            }
            Button("Cancel", role: .cancel) {
                timerManager.pendingScheduleConfirmation = nil
            }
        } message: {
            if let pending = timerManager.pendingScheduleConfirmation {
                let duration = timerManager.remainingSecondsForActiveSchedule()
                let durationStr = timerManager.formatDurationDescription(duration)
                Text("You are about to start a block from the schedule '\(pending.name)' for \(durationStr).")
            }
        }
    }
}

struct ScheduleRuleRow: View {
    @Binding var rule: ScheduleRule
    var use24HourMode: Bool
    var isLocked: Bool
    var onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                // Name field
                TextField("Schedule Name", text: $rule.name)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .disabled(isLocked)
                
                Spacer()
                
                // Toggle status
                Toggle("", isOn: $rule.isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .disabled(isLocked)
                    .labelsHidden()
                
                if !isLocked {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                            .font(.subheadline)
                            .padding(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 8)
                }
            }
            
            HStack {
                WeekdaySelector(activeDays: $rule.activeDays, isLocked: isLocked)
                
                Spacer()
                
                HStack(spacing: 4) {
                    TimePickerView(hour: $rule.startHour, minute: $rule.startMinute, use24HourMode: use24HourMode, isLocked: isLocked)
                    Text("to")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    TimePickerView(hour: $rule.endHour, minute: $rule.endMinute, use24HourMode: use24HourMode, isLocked: isLocked)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(rule.isEnabled ? Color.blue.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct WeekdaySelector: View {
    @Binding var activeDays: Set<Int>
    var isLocked: Bool
    
    let days = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { dayIndex in
                let isActive = activeDays.contains(dayIndex)
                Button(action: {
                    guard !isLocked else { return }
                    if isActive {
                        if activeDays.count > 1 {
                            activeDays.remove(dayIndex)
                        }
                    } else {
                        activeDays.insert(dayIndex)
                    }
                }) {
                    Text(days[dayIndex - 1])
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isActive ? .white : .gray)
                        .frame(width: 18, height: 18)
                        .background(
                            Circle()
                                .fill(isActive ? Color.blue : Color.white.opacity(0.05))
                        )
                        .overlay(
                            Circle()
                                .stroke(isActive ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLocked)
            }
        }
    }
}

struct TimePickerView: View {
    @Binding var hour: Int
    @Binding var minute: Int
    var use24HourMode: Bool
    var isLocked: Bool
    
    @State private var hourString: String = ""
    @State private var minuteString: String = ""
    
    // Custom binding for AM/PM status (false = AM, true = PM)
    private var isPMBinding: Binding<Bool> {
        Binding<Bool>(
            get: {
                let (_, isPM) = to12HourFormat(hour24: hour)
                return isPM
            },
            set: { newIsPM in
                let (h12, _) = to12HourFormat(hour24: hour)
                hour = to24HourFormat(hour12: h12, isPM: newIsPM)
            }
        )
    }
    
    private func to12HourFormat(hour24: Int) -> (hour12: Int, isPM: Bool) {
        if hour24 == 0 {
            return (12, false)
        } else if hour24 == 12 {
            return (12, true)
        } else if hour24 > 12 {
            return (hour24 - 12, true)
        } else {
            return (hour24, false)
        }
    }
    
    private func to24HourFormat(hour12: Int, isPM: Bool) -> Int {
        if isPM {
            return hour12 == 12 ? 12 : hour12 + 12
        } else {
            return hour12 == 12 ? 0 : hour12
        }
    }
    
    private func cleanFields() {
        if hourString.isEmpty {
            if use24HourMode {
                hourString = String(hour)
            } else {
                let (h12, _) = to12HourFormat(hour24: hour)
                hourString = String(h12)
            }
        }
        if minuteString.isEmpty {
            minuteString = String(format: "%02d", minute)
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            // Hour Input Field
            TextField("", text: $hourString)
                .textFieldStyle(PlainTextFieldStyle())
                .frame(width: 24)
                .multilineTextAlignment(.center)
                .background(Color.white.opacity(0.05))
                .cornerRadius(4)
                .disabled(isLocked)
                .onSubmit(cleanFields)
                .onChange(of: hourString) { oldValue, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    let maxHour = use24HourMode ? 23 : 12
                    
                    if let val = Int(filtered) {
                        let clamped = min(maxHour, val)
                        
                        if use24HourMode {
                            hour = clamped
                        } else {
                            // Enforce 1-12 range for AM/PM format typing
                            let bounded12 = max(1, clamped)
                            let (_, isPM) = to12HourFormat(hour24: hour)
                            hour = to24HourFormat(hour12: bounded12, isPM: isPM)
                        }
                        hourString = String(clamped)
                    } else {
                        hourString = ""
                    }
                }
            
            Text(":")
                .foregroundColor(.gray)
                .font(.caption2)
            
            // Minute Input Field
            TextField("", text: $minuteString)
                .textFieldStyle(PlainTextFieldStyle())
                .frame(width: 24)
                .multilineTextAlignment(.center)
                .background(Color.white.opacity(0.05))
                .cornerRadius(4)
                .disabled(isLocked)
                .onSubmit(cleanFields)
                .onChange(of: minuteString) { oldValue, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if let val = Int(filtered) {
                        let clamped = min(59, val)
                        minute = clamped
                        minuteString = String(format: "%02d", clamped)
                    } else {
                        minuteString = ""
                    }
                }
            
            if !use24HourMode {
                Picker("", selection: isPMBinding) {
                    Text("AM").tag(false)
                    Text("PM").tag(true)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 50)
                .disabled(isLocked)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.04))
        .cornerRadius(4)
        .onAppear {
            if use24HourMode {
                hourString = String(hour)
            } else {
                let (h12, _) = to12HourFormat(hour24: hour)
                hourString = String(h12)
            }
            minuteString = String(format: "%02d", minute)
        }
        .onChange(of: use24HourMode) { oldValue, newValue in
            if newValue {
                hourString = String(hour)
            } else {
                let (h12, _) = to12HourFormat(hour24: hour)
                hourString = String(h12)
            }
        }
    }
}
