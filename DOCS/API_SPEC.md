# External API Specification – AlAdhan

## Base URL
`https://api.aladhan.com/v1`

### 1. Prayer Times  
`GET /timings?latitude={lat}&longitude={lon}&method={id}`  

```json
{
  "data": {
    "timings": {
      "Fajr": "03:25",
      "Dhuhr": "13:12",
      "Asr": "17:08",
      "Maghrib": "20:41",
      "Isha": "22:11"
    },
    "meta": { "method": "MuslimWorldLeague" }
  }
}

### 2. Qibla
GET /qibla/{lat}/{lon} → { "data": { "direction": 54.34 } }

Throttling
Unauthenticated: ~90 req/min. Cache for 24 h.

Local Fallback
If offline, use AdhanSwift local calculation.