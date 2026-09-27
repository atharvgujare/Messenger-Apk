# Messenger — Full-Stack Real-Time Messaging Platform

Messenger is a modern, extensible real-time messaging application combining clean architecture, robust security, and an original visual identity.

Initially targeting **Android** with multi-client architecture (Web, Windows, iOS ready), Messenger is built with **Flutter (Material 3)** on the frontend, **ASP.NET Core Web API 9.0 with SignalR** on the backend, and **SQL Server with Entity Framework Core 9.0** for persistence.

---

## 🛠 Technology Stack

### Mobile Frontend
- **Framework**: Flutter 3.47.5 / Dart 3.13.4
- **Design System**: Material 3 with adaptive light/dark theming and custom color tokens
- **Architecture**: Clean Architecture with feature-based encapsulation
- **Real-Time Client**: `signalr_netcore`
- **State Management**: `provider`
- **HTTP & Storage**: `http`, `shared_preferences`, `uuid`, `intl`

### Backend
- **Framework**: ASP.NET Core Web API (.NET 9.0)
- **Real-Time Engine**: ASP.NET Core SignalR
- **Database & ORM**: Microsoft SQL Server Express (`localhost\SQLEXPRESS`) with Entity Framework Core 9.0
- **Security & Auth**: JWT Bearer tokens + Cryptographic Refresh Token rotation, BCrypt password hashing
- **API Documentation**: OpenAPI / Swagger UI
- **Testing**: xUnit with Moq and EF Core In-Memory / TestContainers

---

## 📁 Repository Structure

```
Messenger/
├── src/
│   ├── Messaging.Domain/         # Core domain entities, enums, value objects
│   ├── Messaging.Application/    # Use cases, service interfaces, DTOs, validations
│   ├── Messaging.Infrastructure/ # EF Core, AppDbContext, SQL Server, Auth, Storage
│   └── Messaging.Api/            # REST controllers, SignalR ChatHub, Middleware
├── tests/
│   └── Messaging.Tests/          # Unit & integration tests
├── messaging_app/                # Flutter mobile application
│   ├── android/                  # Android native project & Gradle build
│   ├── lib/
│   │   ├── core/                 # Config, constants, errors, network, storage, theme
│   │   └── features/             # Auth, chats, messages, users, groups, settings
│   └── test/                     # Flutter unit & widget tests
├── Messaging.slnx                # .NET solution file
├── ARCHITECTURE.md               # Detailed system architecture document
├── DATABASE.md                   # Database schema, entities & ERD specification
├── API.md                        # REST endpoints & SignalR Hub contract specification
├── DEVELOPMENT_ROADMAP.md        # Phased development milestones & tracking
├── .gitignore                    # Comprehensive repository gitignore
└── README.md                     # Project documentation & setup instructions
```

---

## 🚀 Getting Started

### 1. Prerequisites
- **OS**: Windows 11
- **.NET SDK**: 9.0+ installed
- **Flutter SDK**: Installed at `D:\flutter\flutter`
- **Android SDK**: Installed at `D:\AndroidSdk` (Java JDK at `D:\Android\jbr\bin\java`)
- **SQL Server**: Microsoft SQL Server Express running on `localhost\SQLEXPRESS`
- **Device**: Physical Android device connected via USB with USB debugging enabled, or an Android emulator / Chrome browser for web testing.

### 2. Backend Setup & Run

1. Open `src/Messaging.Api/appsettings.json` and verify the connection string:
   ```json
   "ConnectionStrings": {
     "DefaultConnection": "Server=localhost\\SQLEXPRESS;Database=MessengerDb;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true;"
   }
   ```
2. Build the solution:
   ```bash
   dotnet build
   ```
3. Run the API:
   ```bash
   dotnet run --project src/Messaging.Api
   ```
4. Access Swagger UI at `https://localhost:7000/swagger` or `http://localhost:5000/swagger`.

### 3. Mobile App Setup & Run

1. Set your Flutter environment PATH if needed:
   ```powershell
   $env:Path = "D:\flutter\flutter\bin;D:\AndroidSdk\platform-tools;$env:Path"
   ```
2. Fetch dependencies:
   ```bash
   cd messaging_app
   flutter pub get
   ```
3. Inspect connected devices:
   ```bash
   flutter devices
   ```
4. Run the app on your connected Android phone:
   ```bash
   flutter run -d RZCX10TSLZV
   ```

---

## 📚 Detailed Documentation

- 📐 [System Architecture](ARCHITECTURE.md)
- 🗄 [Database Schema & ERD](DATABASE.md)
- 🔌 [REST API & SignalR Hub Specification](API.md)
- 🗺 [Development Roadmap & Milestones](DEVELOPMENT_ROADMAP.md)

---

## 🔒 Security Principles

- No plaintext passwords (BCrypt salted hashing).
- Stateless JWT access tokens with rotatable refresh tokens stored in SQL Server.
- Client-provided user identities are never trusted; user ID is extracted from authenticated claims.
- File upload protection with MIME type verification, size quotas, and randomized GUID filenames.
