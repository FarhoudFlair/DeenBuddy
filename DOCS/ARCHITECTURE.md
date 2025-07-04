# High-Level Architecture

```mermaid
graph TD
  subgraph iOS App
    A[SwiftUI Views] -->|binds| VM(ViewModels)
    VM --> Domain
    Domain -->|uses| DataLayer
    DataLayer --> LocalDB[(CoreData)]
    DataLayer --> RemoteAPI[(AlAdhan API)]
    DataLayer --> Sensors[(CoreLocation/CoreMotion)]
  end

  RemoteAPI -->|HTTPS JSON| AlAdhan[(aladhan.com)]
  CMS[(Supabase CMS)] --> RemoteAPI

Data Flow
On launch, Settings determines calc method.
Location service emits lat/lon → PrayerCalc generates times offline.
If online, remote API used to cross-check & sync Hijri calendar.