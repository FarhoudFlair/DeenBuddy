import Foundation
import CoreData

/// CoreData manager responsible for all data persistence operations
public final class CoreDataManager: DataManagerProtocol {
    
    // MARK: - Properties
    
    public static let shared = CoreDataManager()
    
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DeenAssist", managedObjectModel: createManagedObjectModel())
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("CoreData failed to load store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    private var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - CoreData Model Creation
    
    private func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // UserSettings Entity
        let userSettingsEntity = NSEntityDescription()
        userSettingsEntity.name = "UserSettingsEntity"
        userSettingsEntity.managedObjectClassName = "UserSettingsEntity"
        
        let userSettingsAttributes = [
            createAttribute(name: "id", type: .UUIDAttributeType, isOptional: false),
            createAttribute(name: "calculationMethod", type: .stringAttributeType, isOptional: false),
            createAttribute(name: "madhab", type: .stringAttributeType, isOptional: false),
            createAttribute(name: "notificationsEnabled", type: .booleanAttributeType, isOptional: false),
            createAttribute(name: "theme", type: .stringAttributeType, isOptional: false)
        ]
        userSettingsEntity.properties = userSettingsAttributes
        
        // PrayerCache Entity
        let prayerCacheEntity = NSEntityDescription()
        prayerCacheEntity.name = "PrayerCacheEntity"
        prayerCacheEntity.managedObjectClassName = "PrayerCacheEntity"
        
        let prayerCacheAttributes = [
            createAttribute(name: "date", type: .dateAttributeType, isOptional: false),
            createAttribute(name: "fajr", type: .dateAttributeType, isOptional: false),
            createAttribute(name: "dhuhr", type: .dateAttributeType, isOptional: false),
            createAttribute(name: "asr", type: .dateAttributeType, isOptional: false),
            createAttribute(name: "maghrib", type: .dateAttributeType, isOptional: false),
            createAttribute(name: "isha", type: .dateAttributeType, isOptional: false),
            createAttribute(name: "sourceMethod", type: .stringAttributeType, isOptional: false)
        ]
        prayerCacheEntity.properties = prayerCacheAttributes
        
        // GuideContent Entity
        let guideContentEntity = NSEntityDescription()
        guideContentEntity.name = "GuideContentEntity"
        guideContentEntity.managedObjectClassName = "GuideContentEntity"
        
        let guideContentAttributes = [
            createAttribute(name: "contentId", type: .stringAttributeType, isOptional: false),
            createAttribute(name: "title", type: .stringAttributeType, isOptional: false),
            createAttribute(name: "rakahCount", type: .integer16AttributeType, isOptional: false),
            createAttribute(name: "isAvailableOffline", type: .booleanAttributeType, isOptional: false),
            createAttribute(name: "localData", type: .binaryDataAttributeType, isOptional: true),
            createAttribute(name: "videoURL", type: .stringAttributeType, isOptional: true),
            createAttribute(name: "lastUpdatedAt", type: .dateAttributeType, isOptional: false)
        ]
        guideContentEntity.properties = guideContentAttributes
        
        model.entities = [userSettingsEntity, prayerCacheEntity, guideContentEntity]
        return model
    }
    
    private func createAttribute(name: String, type: NSAttributeType, isOptional: Bool) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        return attribute
    }
    
    // MARK: - User Settings Operations
    
    public func getUserSettings() -> UserSettings? {
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "UserSettingsEntity")
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            guard let entity = results.first else { return nil }
            
            return UserSettings(
                id: entity.value(forKey: "id") as? UUID ?? UUID(),
                calculationMethod: entity.value(forKey: "calculationMethod") as? String ?? CalculationMethod.muslimWorldLeague.rawValue,
                madhab: entity.value(forKey: "madhab") as? String ?? Madhab.shafi.rawValue,
                notificationsEnabled: entity.value(forKey: "notificationsEnabled") as? Bool ?? true,
                theme: entity.value(forKey: "theme") as? String ?? "system"
            )
        } catch {
            print("Failed to fetch user settings: \(error)")
            return nil
        }
    }
    
    public func saveUserSettings(_ settings: UserSettings) throws {
        // Delete existing settings first (there should only be one)
        let deleteRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "UserSettingsEntity")
        let deleteRequest2 = NSBatchDeleteRequest(fetchRequest: deleteRequest)
        try context.execute(deleteRequest2)
        
        // Create new settings entity
        guard let entity = NSEntityDescription.entity(forEntityName: "UserSettingsEntity", in: context) else {
            throw DataManagerError.invalidData("Could not create UserSettingsEntity")
        }
        
        let settingsEntity = NSManagedObject(entity: entity, insertInto: context)
        settingsEntity.setValue(settings.id, forKey: "id")
        settingsEntity.setValue(settings.calculationMethod, forKey: "calculationMethod")
        settingsEntity.setValue(settings.madhab, forKey: "madhab")
        settingsEntity.setValue(settings.notificationsEnabled, forKey: "notificationsEnabled")
        settingsEntity.setValue(settings.theme, forKey: "theme")
        
        try saveContext()
    }
    
    public func resetUserSettings() throws {
        let defaultSettings = UserSettings(
            calculationMethod: CalculationMethod.muslimWorldLeague.rawValue,
            madhab: Madhab.shafi.rawValue,
            notificationsEnabled: true,
            theme: "system"
        )
        try saveUserSettings(defaultSettings)
    }

    // MARK: - Prayer Cache Operations

    public func getPrayerCache(for date: Date) -> PrayerCacheEntry? {
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "PrayerCacheEntity")
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.fetchLimit = 1

        do {
            let results = try context.fetch(request)
            guard let entity = results.first else { return nil }

            return PrayerCacheEntry(
                date: entity.value(forKey: "date") as? Date ?? Date(),
                fajr: entity.value(forKey: "fajr") as? Date ?? Date(),
                dhuhr: entity.value(forKey: "dhuhr") as? Date ?? Date(),
                asr: entity.value(forKey: "asr") as? Date ?? Date(),
                maghrib: entity.value(forKey: "maghrib") as? Date ?? Date(),
                isha: entity.value(forKey: "isha") as? Date ?? Date(),
                sourceMethod: entity.value(forKey: "sourceMethod") as? String ?? ""
            )
        } catch {
            print("Failed to fetch prayer cache: \(error)")
            return nil
        }
    }

    public func savePrayerCache(_ entry: PrayerCacheEntry) throws {
        // Delete existing cache for the same date
        let deleteRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "PrayerCacheEntity")
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: entry.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        deleteRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)

        let existingEntries = try context.fetch(deleteRequest)
        for existingEntry in existingEntries {
            context.delete(existingEntry)
        }

        // Create new cache entity
        guard let entity = NSEntityDescription.entity(forEntityName: "PrayerCacheEntity", in: context) else {
            throw DataManagerError.invalidData("Could not create PrayerCacheEntity")
        }

        let cacheEntity = NSManagedObject(entity: entity, insertInto: context)
        cacheEntity.setValue(entry.date, forKey: "date")
        cacheEntity.setValue(entry.fajr, forKey: "fajr")
        cacheEntity.setValue(entry.dhuhr, forKey: "dhuhr")
        cacheEntity.setValue(entry.asr, forKey: "asr")
        cacheEntity.setValue(entry.maghrib, forKey: "maghrib")
        cacheEntity.setValue(entry.isha, forKey: "isha")
        cacheEntity.setValue(entry.sourceMethod, forKey: "sourceMethod")

        try saveContext()
    }

    public func deleteOldPrayerCache(before date: Date) throws {
        let deleteRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "PrayerCacheEntity")
        deleteRequest.predicate = NSPredicate(format: "date < %@", date as NSDate)

        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
        try context.execute(batchDeleteRequest)
        try saveContext()
    }

    public func getPrayerCacheRange(from startDate: Date, to endDate: Date) -> [PrayerCacheEntry] {
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "PrayerCacheEntity")
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        do {
            let results = try context.fetch(request)
            return results.map { entity in
                PrayerCacheEntry(
                    date: entity.value(forKey: "date") as? Date ?? Date(),
                    fajr: entity.value(forKey: "fajr") as? Date ?? Date(),
                    dhuhr: entity.value(forKey: "dhuhr") as? Date ?? Date(),
                    asr: entity.value(forKey: "asr") as? Date ?? Date(),
                    maghrib: entity.value(forKey: "maghrib") as? Date ?? Date(),
                    isha: entity.value(forKey: "isha") as? Date ?? Date(),
                    sourceMethod: entity.value(forKey: "sourceMethod") as? String ?? ""
                )
            }
        } catch {
            print("Failed to fetch prayer cache range: \(error)")
            return []
        }
    }

    // MARK: - Guide Content Operations

    public func getGuideContent(by contentId: String) -> GuideContent? {
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "GuideContentEntity")
        request.predicate = NSPredicate(format: "contentId == %@", contentId)
        request.fetchLimit = 1

        do {
            let results = try context.fetch(request)
            guard let entity = results.first else { return nil }

            return GuideContent(
                contentId: entity.value(forKey: "contentId") as? String ?? "",
                title: entity.value(forKey: "title") as? String ?? "",
                rakahCount: entity.value(forKey: "rakahCount") as? Int16 ?? 0,
                isAvailableOffline: entity.value(forKey: "isAvailableOffline") as? Bool ?? false,
                localData: entity.value(forKey: "localData") as? Data,
                videoURL: entity.value(forKey: "videoURL") as? String,
                lastUpdatedAt: entity.value(forKey: "lastUpdatedAt") as? Date ?? Date()
            )
        } catch {
            print("Failed to fetch guide content: \(error)")
            return nil
        }
    }

    public func getAllGuideContent() -> [GuideContent] {
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "GuideContentEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]

        do {
            let results = try context.fetch(request)
            return results.map { entity in
                GuideContent(
                    contentId: entity.value(forKey: "contentId") as? String ?? "",
                    title: entity.value(forKey: "title") as? String ?? "",
                    rakahCount: entity.value(forKey: "rakahCount") as? Int16 ?? 0,
                    isAvailableOffline: entity.value(forKey: "isAvailableOffline") as? Bool ?? false,
                    localData: entity.value(forKey: "localData") as? Data,
                    videoURL: entity.value(forKey: "videoURL") as? String,
                    lastUpdatedAt: entity.value(forKey: "lastUpdatedAt") as? Date ?? Date()
                )
            }
        } catch {
            print("Failed to fetch all guide content: \(error)")
            return []
        }
    }

    public func saveGuideContent(_ content: GuideContent) throws {
        // Delete existing content with the same ID
        let deleteRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "GuideContentEntity")
        deleteRequest.predicate = NSPredicate(format: "contentId == %@", content.contentId)

        let existingEntries = try context.fetch(deleteRequest)
        for existingEntry in existingEntries {
            context.delete(existingEntry)
        }

        // Create new guide content entity
        guard let entity = NSEntityDescription.entity(forEntityName: "GuideContentEntity", in: context) else {
            throw DataManagerError.invalidData("Could not create GuideContentEntity")
        }

        let contentEntity = NSManagedObject(entity: entity, insertInto: context)
        contentEntity.setValue(content.contentId, forKey: "contentId")
        contentEntity.setValue(content.title, forKey: "title")
        contentEntity.setValue(content.rakahCount, forKey: "rakahCount")
        contentEntity.setValue(content.isAvailableOffline, forKey: "isAvailableOffline")
        contentEntity.setValue(content.localData, forKey: "localData")
        contentEntity.setValue(content.videoURL, forKey: "videoURL")
        contentEntity.setValue(content.lastUpdatedAt, forKey: "lastUpdatedAt")

        try saveContext()
    }

    public func deleteGuideContent(by contentId: String) throws {
        let deleteRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "GuideContentEntity")
        deleteRequest.predicate = NSPredicate(format: "contentId == %@", contentId)

        let existingEntries = try context.fetch(deleteRequest)
        for existingEntry in existingEntries {
            context.delete(existingEntry)
        }

        try saveContext()
    }

    public func getOfflineGuideContent() -> [GuideContent] {
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "GuideContentEntity")
        request.predicate = NSPredicate(format: "isAvailableOffline == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]

        do {
            let results = try context.fetch(request)
            return results.map { entity in
                GuideContent(
                    contentId: entity.value(forKey: "contentId") as? String ?? "",
                    title: entity.value(forKey: "title") as? String ?? "",
                    rakahCount: entity.value(forKey: "rakahCount") as? Int16 ?? 0,
                    isAvailableOffline: entity.value(forKey: "isAvailableOffline") as? Bool ?? false,
                    localData: entity.value(forKey: "localData") as? Data,
                    videoURL: entity.value(forKey: "videoURL") as? String,
                    lastUpdatedAt: entity.value(forKey: "lastUpdatedAt") as? Date ?? Date()
                )
            }
        } catch {
            print("Failed to fetch offline guide content: \(error)")
            return []
        }
    }

    // MARK: - General Operations

    public func saveContext() throws {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            throw DataManagerError.saveContextFailed(error.localizedDescription)
        }
    }

    public func clearAllData() throws {
        let entityNames = ["UserSettingsEntity", "PrayerCacheEntity", "GuideContentEntity"]

        for entityName in entityNames {
            let deleteRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            try context.execute(batchDeleteRequest)
        }

        try saveContext()
    }
}
