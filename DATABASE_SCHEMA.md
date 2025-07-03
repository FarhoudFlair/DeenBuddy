Local Database Schema (CoreData) - REVISION 1
Change Summary

DEPRECATED the generic Setting entity in favor of a strongly-typed UserSettings entity. Storing settings in a JSON-encoded string is brittle and inefficient. This new structure is type-safe, easier to query, and eliminates serialization/deserialization overhead.

Entity: UserSettings
This entity holds all user-configurable settings in a structured, type-safe manner.
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key, only one instance of this entity should exist. |
| calculationMethod | String | Raw value from AdhanSwift.CalculationMethod. e.g., "muslimWorldLeague" |
| madhab | String | Raw value for Asr calculation. e.g., "shafi" or "hanafi" |
| notificationsEnabled | Bool | Global toggle for all prayer notifications. |
| theme | String | "light", "dark", or "system". |

Entity: PrayerCache
No changes to this entity. It remains an effective cache for daily prayer times.
| Field | Type | Notes |
|-------|------|-------|
| date | Date | Primary key (YYYY-MM-DD). |
| fajr | Date | Full timestamp. |
| dhuhr | Date | Full timestamp. |
| asr | Date | Full timestamp. |
| maghrib | Date | Full timestamp. |
| isha | Date | Full timestamp. |
| sourceMethod | String | The calculation method used to generate this cache entry. |

Entity: GuideContent
Renamed from GuideDownload for clarity and updated to reflect a native content strategy instead of raw file paths.
| Field | Type | Notes |
|-------|------|-------|
| contentId | String | Unique ID, e.g., "fajr_sunni_guide". Primary key. |
| title | String | e.g., "Fajr Prayer (Sunni)" |
| rakahCount | Int16 | e.g., 2 |
| isAvailableOffline | Bool | Flag indicating if content is stored locally. |
| localData | Data? | Optional binary data holding the native guide content (e.g., encoded JSON or text). |
| videoURL | String? | URL for the HLS video stream. |
| lastUpdatedAt | Date | Timestamp for content versioning. |

