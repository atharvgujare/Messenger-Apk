# Messenger API & Real-Time SignalR Hub Specification

## 1. RESTful Standards & Global Conventions

- **Base URL**: `https://<host>/api`
- **Content-Type**: `application/json` (or `multipart/form-data` for file uploads)
- **Authentication**: `Authorization: Bearer <jwt_access_token>`
- **HTTP Status Codes**:
  - `200 OK`: Request succeeded.
  - `201 Created`: Resource successfully created.
  - `204 No Content`: Action completed without return body.
  - `400 Bad Request`: Validation failure or semantic error.
  - `401 Unauthorized`: Token missing, expired, or invalid.
  - `403 Forbidden`: Authenticated user lacks permission to access this resource.
  - `404 Not Found`: Resource does not exist.
  - `409 Conflict`: Unique constraint violation (e.g. username already taken).
  - `429 Too Many Requests`: Rate limit exceeded.
  - `500 Internal Server Error`: Unhandled system failure.

### Consistent Error Response (RFC 7807)
```json
{
  "type": "https://messenger.app/errors/validation-failed",
  "title": "Validation Failed",
  "status": 400,
  "detail": "Username is already taken.",
  "errors": {
    "username": ["The username 'atharv' is unavailable."]
  },
  "instance": "/api/auth/register"
}
```

---

## 2. Authentication API (`/api/auth`)

### 2.1 Register
- **Endpoint**: `POST /api/auth/register`
- **Request Body**:
```json
{
  "username": "atharv",
  "email": "atharv@example.com",
  "password": "SecurePassword123!",
  "displayName": "Atharv Gujare"
}
```
- **Response** (`201 Created`):
```json
{
  "userId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "username": "atharv",
  "displayName": "Atharv Gujare",
  "email": "atharv@example.com",
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "d7a4f91...",
  "expiresAt": "2026-09-27T14:30:00Z"
}
```

### 2.2 Login
- **Endpoint**: `POST /api/auth/login`
- **Request Body**:
```json
{
  "loginIdentifier": "atharv", // Supports username or email
  "password": "SecurePassword123!",
  "deviceInfo": "Samsung Galaxy A14 (Android 15)"
}
```
- **Response** (`200 OK`): Same structure as Register response.

### 2.3 Refresh Token
- **Endpoint**: `POST /api/auth/refresh`
- **Request Body**:
```json
{
  "refreshToken": "d7a4f91..."
}
```
- **Response** (`200 OK`): Returns fresh `accessToken`, rotated `refreshToken`, and updated expiration.

### 2.4 Logout
- **Endpoint**: `POST /api/auth/logout`
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**: `{ "refreshToken": "d7a4f91..." }`
- **Response** (`204 No Content`)

### 2.5 Logout All Devices
- **Endpoint**: `POST /api/auth/logout-all`
- **Headers**: `Authorization: Bearer <token>`
- **Response** (`204 No Content`)

---

## 3. User Discovery & Profiles (`/api/users`)

### 3.1 Search Users
- **Endpoint**: `GET /api/users/search?q={query}`
- **Response** (`200 OK`):
```json
[
  {
    "userId": "b2c3d4e5-...",
    "username": "rahul",
    "displayName": "Rahul Sharma",
    "avatarUrl": "/uploads/avatars/rahul.jpg",
    "bio": "Building scalable software",
    "isOnline": true,
    "lastSeenAt": "2026-09-27T13:20:00Z"
  }
]
```

### 3.2 Get Current Profile
- **Endpoint**: `GET /api/users/me`
- **Response** (`200 OK`): Current user profile, bio, privacy settings, and active sessions count.

### 3.3 Update Profile
- **Endpoint**: `PUT /api/users/me`
- **Request Body**:
```json
{
  "displayName": "Atharv G.",
  "bio": "Flutter & .NET Developer",
  "avatarUrl": "/uploads/avatars/new_avatar.jpg"
}
```

---

## 4. Conversations API (`/api/conversations`)

### 4.1 List Conversations
- **Endpoint**: `GET /api/conversations?filter=all|unread|groups|archived`
- **Response** (`200 OK`):
```json
[
  {
    "conversationId": "4a7b...",
    "type": 1, // 1: Direct, 2: Group
    "title": "Rahul Sharma",
    "avatarUrl": "/uploads/avatars/rahul.jpg",
    "isPinned": true,
    "isMuted": false,
    "isArchived": false,
    "unreadCount": 2,
    "lastMessage": {
      "messageId": "9f8e...",
      "senderId": "b2c3...",
      "type": 1,
      "content": "Hi Atharv!",
      "createdAt": "2026-09-27T13:25:00Z",
      "status": 2
    },
    "otherParticipant": {
      "userId": "b2c3...",
      "username": "rahul",
      "isOnline": true,
      "lastSeenAt": "2026-09-27T13:25:00Z"
    }
  }
]
```

### 4.2 Start or Retrieve Direct Conversation
- **Endpoint**: `POST /api/conversations/direct`
- **Request Body**: `{ "recipientUserId": "b2c3d4e5-..." }`
- **Response** (`200 OK` or `201 Created`): Idempotent; returns existing thread if one exists between the pair.

### 4.3 Create Group Conversation
- **Endpoint**: `POST /api/conversations/group`
- **Request Body**:
```json
{
  "title": "Engineering Team",
  "description": "Core architecture discussions",
  "avatarUrl": null,
  "memberUserIds": ["b2c3...", "d4e5..."]
}
```

---

## 5. Messages API (`/api/conversations/{id}/messages`)

### 5.1 Get Conversation Messages
- **Endpoint**: `GET /api/conversations/{id}/messages?beforeCursor={guid}&limit=30`
- **Response** (`200 OK`):
```json
{
  "messages": [
    {
      "id": "9f8e...",
      "conversationId": "4a7b...",
      "senderId": "3fa8...",
      "type": 1,
      "content": "Hello Rahul!",
      "createdAt": "2026-09-27T13:24:00Z",
      "isEdited": false,
      "replyTo": null,
      "status": 3, // Read
      "reactions": [{ "emoji": "👍", "count": 1, "hasReacted": true }]
    }
  ],
  "nextCursor": "8e7d...",
  "hasMore": true
}
```

### 5.2 Send Message (HTTP Fallback)
- **Endpoint**: `POST /api/conversations/{id}/messages`
- **Request Body**:
```json
{
  "type": 1,
  "content": "Hello Rahul!",
  "replyToMessageId": null,
  "clientGeneratedId": "0e9b4d1a-..."
}
```

### 5.3 Edit Message
- **Endpoint**: `PATCH /api/messages/{id}`
- **Request Body**: `{ "content": "Updated message content" }`

### 5.4 Delete Message
- **Endpoint**: `DELETE /api/messages/{id}?forEveryone=true`

### 5.5 React to Message
- **Endpoint**: `POST /api/messages/{id}/reactions`
- **Request Body**: `{ "emoji": "❤️" }`

---

## 6. Real-Time SignalR Hub (`/hubs/chat`)

### Connection Handshake
Clients connect to `wss://<host>/hubs/chat` using standard JWT authorization:
```dart
HubConnectionBuilder()
  .withUrl('https://<host>/hubs/chat', HttpConnectionOptions(
    accessTokenFactory: () async => await tokenStorage.getAccessToken(),
  ))
  .withAutomaticReconnect()
  .build();
```

### Client-to-Server Methods
- `SendMessage(SendMessageRequest request)`
- `SendTyping(Guid conversationId, bool isTyping)`
- `MarkMessagesAsRead(Guid conversationId, Guid lastMessageId)`
- `AddReaction(Guid messageId, string emoji)`
- `RemoveReaction(Guid messageId)`

### Server-to-Client Broadcast Events
- `MessageReceived(MessageDto message)`
- `MessageDelivered(Guid messageId, Guid conversationId, Guid recipientId, DateTime timestamp)`
- `MessageRead(Guid messageId, Guid conversationId, Guid readerId, DateTime timestamp)`
- `UserTyping(Guid conversationId, Guid userId, string username)`
- `UserStoppedTyping(Guid conversationId, Guid userId)`
- `PresenceChanged(Guid userId, bool isOnline, DateTime? lastSeenAt)`
- `ReactionUpdated(Guid messageId, string emoji, Guid userId, bool isAdded)`
- `MessageUpdated(MessageDto message)`
- `MessageDeleted(Guid messageId, Guid conversationId, bool forEveryone)`
