import Foundation
import StoreKit

/// Represents a subscription product with StoreKit 2 integration
public struct SubscriptionProduct: Identifiable, Hashable, Codable {
    public let id: String
    public let displayName: String
    public let description: String
    public let price: Decimal
    public let priceFormatted: String
    public let period: SubscriptionPeriod
    public let savings: String?
    public let isPopular: Bool
    
    /// StoreKit Product reference (not stored in cache)
    private var productReference: Product?
    
    public init(
        id: String,
        displayName: String,
        description: String,
        price: Decimal,
        priceFormatted: String,
        period: SubscriptionPeriod,
        product: Product? = nil,
        savings: String? = nil,
        isPopular: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.price = price
        self.priceFormatted = priceFormatted
        self.period = period
        self.productReference = product
        self.savings = savings
        self.isPopular = isPopular
    }
    
    /// Access the StoreKit Product for purchase operations
    public var product: Product? {
        get { productReference }
        set { productReference = newValue }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, displayName, description, price, priceFormatted, period, savings, isPopular
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(description, forKey: .description)
        try container.encode(price, forKey: .price)
        try container.encode(priceFormatted, forKey: .priceFormatted)
        try container.encode(period, forKey: .period)
        try container.encodeIfPresent(savings, forKey: .savings)
        try container.encode(isPopular, forKey: .isPopular)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        description = try container.decode(String.self, forKey: .description)
        price = try container.decode(Decimal.self, forKey: .price)
        priceFormatted = try container.decode(String.self, forKey: .priceFormatted)
        period = try container.decode(SubscriptionPeriod.self, forKey: .period)
        savings = try container.decodeIfPresent(String.self, forKey: .savings)
        isPopular = try container.decode(Bool.self, forKey: .isPopular)
        productReference = nil
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: SubscriptionProduct, rhs: SubscriptionProduct) -> Bool {
        lhs.id == rhs.id
    }
}

/// Subscription billing period
public enum SubscriptionPeriod: String, Codable, CaseIterable {
    case weekly
    case monthly
    case yearly
    
    public var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
    
    public var shortDisplayName: String {
        switch self {
        case .weekly: return "Week"
        case .monthly: return "Month"
        case .yearly: return "Year"
        }
    }
    
    /// Sort order for display (weekly first, yearly last)
    public var sortOrder: Int {
        switch self {
        case .weekly: return 0
        case .monthly: return 1
        case .yearly: return 2
        }
    }
}

