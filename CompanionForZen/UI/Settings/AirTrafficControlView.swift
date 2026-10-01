import SwiftUI

/// Air Traffic Control configuration view for routing external URLs to specific Zen Spaces.
public struct AirTrafficControlView: View {
    @ObservedObject var atcService = AirTrafficControlService.shared
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    
    @State private var showingAddRuleSheet = false
    @State private var editingRule: AirTrafficRule? = nil
    
    // Add/Edit sheet states
    @State private var ruleName: String = ""
    @State private var ruleMatchType: AirTrafficMatchType = .contains
    @State private var rulePattern: String = ""
    @State private var ruleTargetSpaceId: UUID = UUID()
    
    public init() {}
    
    public var body: some View {
        Form {
            // Description Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(themeManager.accentColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("air_traffic_control")
                                .font(.headline)
                            Text(String(localized: "routing_rules_desc", bundle: .main))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Fallback General Rule Section
            Section(
                header: Text("default_rule"),
                footer: Text("default_rule_desc")
            ) {
                Picker(String(localized: "default_action", bundle: .main), selection: Binding(
                    get: { atcService.fallbackMode },
                    set: { newMode in
                        atcService.fallbackMode = newMode
                        if newMode == .specificSpace && atcService.fallbackSpaceId == nil {
                            atcService.fallbackSpaceId = tabManager.spaces.first?.id
                        }
                        atcService.saveSettings()
                    }
                )) {
                    Text("last_accessed_space").tag(AirTrafficFallbackMode.mostRecent)
                    Text("predefined_space").tag(AirTrafficFallbackMode.specificSpace)
                }
                
                if atcService.fallbackMode == .specificSpace {
                    Picker(String(localized: "target_space", bundle: .main), selection: Binding(
                        get: { atcService.fallbackSpaceId ?? tabManager.spaces.first?.id ?? UUID() },
                        set: { newId in
                            atcService.fallbackSpaceId = newId
                            atcService.saveSettings()
                        }
                    )) {
                        ForEach(tabManager.spaces) { space in
                            HStack(spacing: 8) {
                                SpaceIconView(icon: space.iconName, color: space.primaryColor, size: 14)
                                Text(space.name)
                            }
                            .tag(space.id)
                        }
                    }
                }
            }
            
            // Routing Rules Section
            Section(
                header: HStack {
                    Text("routing_rules")
                    Spacer()
                    Button {
                        ruleName = ""
                        ruleMatchType = .contains
                        rulePattern = ""
                        ruleTargetSpaceId = tabManager.activeSpaceId
                        editingRule = nil
                        showingAddRuleSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("add")
                        }
                        .font(.caption.bold())
                        .foregroundColor(themeManager.accentColor)
                    }
                },
                footer: Text("rules_priority_desc")
            ) {
                if atcService.rules.isEmpty {
                    Text("no_rules_configured")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(atcService.rules) { rule in
                        let targetSpace = tabManager.spaces.first(where: { $0.id == rule.targetSpaceId })
                        
                        HStack(spacing: 12) {
                            Toggle(isOn: Binding(
                                get: { rule.isEnabled },
                                set: { newValue in
                                    var updated = rule
                                    updated.isEnabled = newValue
                                    atcService.updateRule(updated)
                                }
                            )) {
                                EmptyView()
                            }
                            .labelsHidden()
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(rule.name.isEmpty ? rule.pattern : rule.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(rule.isEnabled ? .primary : .secondary)
                                
                                HStack(spacing: 6) {
                                    Text(rule.matchType.localizedLabel)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Capsule())
                                    
                                    Text(rule.pattern)
                                        .font(.caption2.monospaced())
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            if let space = targetSpace {
                                HStack(spacing: 5) {
                                    SpaceIconView(icon: space.iconName, color: space.primaryColor, size: 12)
                                    Text(space.name)
                                        .font(.caption.bold())
                                        .foregroundColor(space.primaryColor)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(space.primaryColor.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingRule = rule
                            ruleName = rule.name
                            ruleMatchType = rule.matchType
                            rulePattern = rule.pattern
                            ruleTargetSpaceId = rule.targetSpaceId
                            showingAddRuleSheet = true
                        }
                    }
                    .onDelete(perform: atcService.deleteRule)
                    .onMove(perform: atcService.moveRule)
                }
            }
        }
        .navigationTitle("Air Traffic Control")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            NavigationStack {
                Form {
                    Section(header: Text("rule_info_section")) {
                        TextField(String(localized: "rule_name_placeholder", bundle: .main), text: $ruleName)
                    }
                    
                    Section(header: Text("matching_condition")) {
                        Picker("Type", selection: $ruleMatchType) {
                            ForEach(AirTrafficMatchType.allCases) { type in
                                Text(type.localizedLabel).tag(type)
                            }
                        }
                        
                        TextField(String(localized: "rule_pattern_placeholder", bundle: .main), text: $rulePattern)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Section(header: Text("section_destination_space")) {
                        Picker(String(localized: "target_space", bundle: .main), selection: $ruleTargetSpaceId) {
                            ForEach(tabManager.spaces) { space in
                                HStack(spacing: 8) {
                                    SpaceIconView(icon: space.iconName, color: space.primaryColor, size: 14)
                                    Text(space.name)
                                }
                                .tag(space.id)
                            }
                        }
                    }
                }
                .navigationTitle(editingRule != nil ? String(localized: "edit_rule", bundle: .main) : String(localized: "new_rule", bundle: .main))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "cancel", bundle: .main)) { showingAddRuleSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "save", bundle: .main)) {
                            let cleanPattern = rulePattern.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !cleanPattern.isEmpty else { return }
                            
                            if let existing = editingRule {
                                var updated = existing
                                updated.name = ruleName.trimmingCharacters(in: .whitespaces)
                                updated.matchType = ruleMatchType
                                updated.pattern = cleanPattern
                                updated.targetSpaceId = ruleTargetSpaceId
                                atcService.updateRule(updated)
                            } else {
                                let newRule = AirTrafficRule(
                                    name: ruleName.trimmingCharacters(in: .whitespaces),
                                    matchType: ruleMatchType,
                                    pattern: cleanPattern,
                                    targetSpaceId: ruleTargetSpaceId
                                )
                                atcService.addRule(newRule)
                            }
                            showingAddRuleSheet = false
                        }
                        .disabled(rulePattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
