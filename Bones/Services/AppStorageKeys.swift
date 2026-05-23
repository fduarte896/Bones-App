import Foundation

/// Centralized AppStorage key constants to avoid scattered string literals.
enum AppStorageKey {
    static let didCompleteOnboarding = "didCompleteOnboarding"
    static let eventsDeepLinkPetID   = "eventsDeepLinkPetID"
    static let eventsDeepLinkPetName = "eventsDeepLinkPetName"
    static let eventsDeepLinkAction  = "eventsDeepLinkAction"
    static let didChooseDemoPet      = "didChooseDemoPet"
    static let demoGuideStep         = "demoGuideStep"
    static let didCompleteDemoGuide  = "didCompleteDemoGuide"
    static let didSeedDewormingDemo  = "didSeedDewormingDemo"
    static let themeMode             = "themeMode"
    static let defaultLeadTime       = "defaultLeadTime"
    static let appCurrencyCode       = "appCurrencyCode"
}
