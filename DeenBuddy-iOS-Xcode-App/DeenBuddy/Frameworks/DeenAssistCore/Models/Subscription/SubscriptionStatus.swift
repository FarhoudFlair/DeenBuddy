import Foundation

/// User's current subscription status and entitlements
public struct SubscriptionStatus: Codable, Equatable {
    public let tier: SubscriptionTier
    public let isActive: Bool
    public let productId: String?
    public let expirationDate: Date?
    public let renewalDate: Date?
    public let isInGracePeriod: Bool
    public let isInBillingRetry: Bool
    public let willAutoRenew: Bool
    
    public init(
        tier: SubscriptionTier,
        isActive: Bool,
        productId: String? = nil,
        expirationDate: Date? = nil,
        renewalDate: Date? = nil,
        isInGracePeriod: Bool = false,
        isInBillingRetry: Bool = false,
        willAutoRenew: Bool = false
    ) {
        self.tier = tier
        self.isActive = isActive
        self.productId = productId
        self.expirationDate = expirationDate
        self.renewalDate = renewalDate
        self.isInGracePeriod = isInGracePeriod
        self.isInBillingRetry = isInBillingRetry
        self.willAutoRenew = willAutoRenew
    }
    
    /// Whether user has active premium access
    public var isPremium: Bool {
        tier == .premium && isActive
    }
    
    /// Days until subscription expires (nil if no expiration or already expired)
    public var daysUntilExpiration: Int? {
        guard let expirationDate = expirationDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expirationDate)
        guard let days = components.day, days >= 0 else { return nil }
        return days
    }
    
    /// Whether subscription is expiring soon (within 7 days)
    public var isExpiringSoon: Bool {
        guard let days = daysUntilExpiration else { return false }
        return days <= 7 && days > 0
    }
    
    /// Whether subscription has expired
    public var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date() > expirationDate && !isInGracePeriod
    }
    
    /// Human-readable status description
    public var statusDescription: String {
        if !isActive {
            return "Free"
        }
        
        if isInGracePeriod {
            return "Premium (Grace Period)"
        }
        
        if isInBillingRetry {
            return "Premium (Payment Issue)"
        }
        
        if let days = daysUntilExpiration {
            if days == 0 {
                return "Premium (Expires Today)"
            } else if days <= 7 {
                return "Premium (Expires in \(days) day\(days == 1 ? "" : "s"))"
            }
        }
        
        return "Premium"
    }
}

// MARK: - Static Instances

extension SubscriptionStatus {
    /// Default free tier status
    public static let free = SubscriptionStatus(
        tier: .free,
        isActive: false
    )
    
    /// Mock premium status for testing
    public static let premium = SubscriptionStatus(
        tier: .premium,
        isActive: true,
        productId: "yearly_premium_sub",
        expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60),
        renewalDate: Date().addingTimeInterval(365 * 24 * 60 * 60),
        willAutoRenew: true
    )
}

