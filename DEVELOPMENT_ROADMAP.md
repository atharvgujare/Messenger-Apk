# Messenger Development Roadmap

This document outlines the phased engineering milestones for Messenger. Each phase is delivered incrementally, verified with compilation and automated tests, and committed with clean git history.

---

## Progress Overview

| Phase | Milestone | Status | Key Deliverables |
|---|---|---|---|
| **Phase 0** | **Environment & Solution Foundation** | Completed | Environment audit, solution skeleton, clean architecture, compilation & tests passing, foundational documentation |
| **Phase 1** | **Authentication & Identity** | Completed | Registration, login, JWT + refresh tokens, password hashing, user entity, username validation, SQL Server migrations |
| **Phase 2** | **User Discovery & Profiles** | Next | Case-insensitive @username & display name search, profile screen, user details |
| **Phase 3** | **Basic Real-Time Chat** | Pending | Conversation creation, EF Core message store, SignalR ChatHub, Send/Receive messages, Chat UI |
| **Phase 4** | **Message States & Presence** | Pending | Sent (✓), Delivered (✓✓), Read (✓✓), Real-time typing indicators, Online/Offline presence & last seen |
| **Phase 5** | **Message Operations** | Pending | Quoted replies, message editing ("Edited"), delete for me / everyone, emoji reactions, pinned & saved messages |
| **Phase 6** | **Media & File Sharing** | Pending | Storage abstraction, image picker & full-screen viewer, documents, voice audio recorder & player |
| **Phase 7** | **Group Chats & Permissions** | Pending | Group creation, Member/Admin/Owner hierarchy, group info screen, participant management |
| **Phase 8** | **Push Notifications Architecture** | Pending | Notification abstraction, Android background service & push notification payload integration |
| **Phase 9** | **Privacy & Safety Controls** | Pending | Backend block enforcement, user/message reporting, privacy toggles (last seen, read receipts) |
| **Phase 10** | **Advanced Communication** | Pending | Location sharing with map preview, contact cards, group polls, chat search, WebRTC call signaling |
| **Phase 11** | **AI-Ready Modular Extensions** | Pending | Pluggable translation, optional local/cloud voice transcription, chat summarization |

---

## Phase Details & Verification Gates

### Phase 0: Foundation (COMPLETED)
- [x] Development environment verification: Flutter 3.47.5, Dart 3.13.4, .NET 10.0/9.0, Android SDK 36.0, SQL Server Express (`localhost\SQLEXPRESS`), Git.
- [x] Solution & project setup: `Messaging.Domain`, `Messaging.Application`, `Messaging.Infrastructure`, `Messaging.Api`, `Messaging.Tests`.
- [x] Mobile setup: `messaging_app` with Clean Architecture directories, packages (`http`, `signalr_netcore`, `provider`, `shared_preferences`, `intl`, `uuid`).
- [x] Initial build verification: Backend builds with 0 errors / 0 warnings; Flutter project analyzes cleanly and tests pass.
- [x] Architecture, Database, API, and Roadmap documentation created.

---

### Phase 1: Authentication & Identity (COMPLETED)
- [x] Implement `User`, `UserProfile`, `UserSession` domain entities.
- [x] Create EF Core `AppDbContext` and initial migration for SQL Server Express.
- [x] Secure password hashing service (`BCrypt`).
- [x] JWT access token + refresh token generation and rotation.
- [x] REST endpoints: `/api/auth/register`, `/api/auth/login`, `/api/auth/refresh`, `/api/auth/logout`, `/api/auth/me`.
- [x] Flutter Auth screens: Modern Onboarding, Register, Login, and persistent session state.
- [x] End-to-end verification: Register user `@atharv`, login, receive JWT, and verify token rotation.

---

### Phase 2: User Discovery & Profiles
- [ ] Users Controller with search API (`GET /api/users/search?q={query}`).
- [ ] Case-insensitive username and display name database queries.
- [ ] Flutter Search UI with debounced text input and user result tiles.
- [ ] User Profile screen showing avatar, display name, bio, and "Start Conversation" CTA.
- [ ] Verification: User A searches for User B by username and opens profile.

---

### Phase 3: Basic Real-Time Chat
- [ ] `Conversation` and `Message` entities & EF Core mappings.
- [ ] SignalR `ChatHub` with JWT authentication and connection handling.
- [ ] `SendMessage` SignalR event & HTTP fallback.
- [ ] Real-time `MessageReceived` broadcast to conversation participants.
- [ ] Flutter Chat List screen and Chat Conversation screen.
- [ ] Verification: User A sends a message; User B receives it in real-time over SignalR.

---

### Phase 4: Message Delivery States & Presence
- [ ] Message status tracking: Sent (✓), Delivered (✓✓ grey), Read (✓✓ blue/colored).
- [ ] SignalR connection tracking for online/offline presence without hammering SQL Server.
- [ ] Transient typing indicator events (`TypingStarted` / `TypingStopped`).
- [ ] Flutter animated status ticks, presence avatars, and typing subtitle ("Atharv is typing...").
- [ ] Verification: Two users test delivery receipts and typing indicators live.

---

### Phase 5: Rich Message Operations
- [ ] Quoted message replies (`ReplyToMessageId`) with preview banner in UI.
- [ ] Message editing with "Edited" badge and audit metadata.
- [ ] Soft deletion: Delete for Me vs Delete for Everyone.
- [ ] Emoji reactions bar (❤️, 👍, 😂, 😮, 😢, 😡) with real-time reaction counts.
- [ ] Pinned messages and Saved Messages personal chat.

---

### Phase 6: Media, Voice & File Sharing
- [ ] Storage service abstraction (`IStorageService`) with local disk implementation.
- [ ] Secure file upload endpoint with MIME validation, magic-number checking, and size limits.
- [ ] Voice message recording, playback, and waveform/duration indicator.
- [ ] Full-screen image and video viewer in Flutter.

---

### Phase 7: Group Chats & Role Administration
- [ ] Group entity with Owner, Admin, and Member permissions.
- [ ] Group creation flow with multi-member selector.
- [ ] Group settings screen (title, description, member management, admin promotion).
- [ ] Real-time group message broadcasting.

---

### Phase 8 to 11: Enterprise, Safety & Next-Gen Features
- [ ] Push notification service architecture.
- [ ] Safety: User blocking and abuse reporting with administrative auditing.
- [ ] Privacy controls: granular visibility for last seen, profile photo, and read receipts.
- [ ] Location sharing with map snapshot.
- [ ] WebRTC voice & video call signaling architecture.
- [ ] Modular pluggable AI endpoints (translation, transcription).
