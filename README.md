# 📘 Detect Care — Caregiver Mobile App

AI-Assisted Patient Monitoring & Alert Management System

Detect Care (caregiver app) is a Flutter mobile application designed for caregivers to monitor patients through AI-powered activity detection, live camera feeds, emergency alerts, medical information, and assignment workflows. The system integrates Supabase Realtime with a REST API fallback to deliver reliable and low-latency monitoring.

🚀 Key Highlights

- AI-powered fall detection & abnormal behavior monitoring
- Realtime alerts (in-app popup, sound alert, push notification)
- 30-second delayed customer alert pipeline to reduce false positives
- Caregiver-first workflow (acknowledge, escalate, resolve)
- Patient medical information & habits tracking
- Assignments & task management
- Multi-channel notification settings (Push/SMS/Email/Call)
- Image settings (retention days, quality, capture frequency)

🏗 Architecture Overview

UI (Flutter Screen Widgets)
↓
Repository Layer
↓
Services (Business Logic)
↓
Remote Data Source
↓
API Client ───► REST API (custom server)
│
└────► Supabase (Realtime + PostgREST)

🧠 Why This Architecture?

- Separation of concerns → scalable for large enterprise apps
- Service layer handles business logic (delays, escalation, SLA checks)
- Repository abstracts API switching (Supabase ↔ REST fallback)
- RemoteDataSource handles real HTTP / Supabase calls
- UI stays clean & reactive

📱 Core Features

1. Realtime Event Monitoring

   - Listen to Supabase Realtime for events
   - Delay popup on customer app (+30 seconds)
   - Auto-suppress false alerts if caregiver cancels within delay
   - In-app critical popup with sound alert

2. Medical Information

   - Patient profile
   - Allergies, chronic diseases, sleep habits
   - Daily check-in & vitals

3. Assignments Management

   - Daily tasks
   - Shift workflows
   - Caregiver-specific responsibilities

4. Notifications

   - Push notification
   - SMS (future)
   - Email
   - Call alert (emergency line)
   - Full user-configurable channel options

5. Image Settings

   - Capture quality
   - Retention days
   - Alert-specific retention policy
   - Monitoring frequency

🛠 Development Setup

Prerequisites

- Flutter SDK (stable)
- Android Studio or VSCode
- Device/emulator
- Supabase project key (anon/public)
- API base URL + JWT (server config)

Install dependencies

```bash
flutter pub get
```

Running the app

```bash
flutter run -d <device>
```

Build release

Android APK

```bash
flutter build apk --release
```

Android App Bundle

```bash
flutter build appbundle --release
```

iOS

```bash
flutter build ios --release
```

— Then archive & sign using Xcode.

---

Generated on: 2025-11-13
