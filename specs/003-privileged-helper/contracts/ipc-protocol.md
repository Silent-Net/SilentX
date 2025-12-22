# IPC Protocol Contract

## Overview

The SilentX Privileged Helper Service uses a JSON-over-Unix-Socket protocol for inter-process communication between the main app and the root-running launchd daemon.

## Transport

- **Socket Path**: `/tmp/silentx/silentx-service.sock`
- **Socket Type**: Unix Domain Socket (SOCK_STREAM)
- **Permission**: `0666` (world read/write)
- **Message Format**: Newline-delimited JSON (NDJSON)

## Message Format

### Request

```json
{
  "command": "<command_name>",
  "payload": { <command-specific data> }
}
```

### Response

```json
{
  "success": true|false,
  "data": { <response data> },
  "error": "<error code>",
  "message": "<human-readable message>"
}
```

---

## Commands

### 1. `start` - Start sing-box proxy

**Request:**
```json
{
  "command": "start",
  "payload": {
    "configPath": "/path/to/config.json",
    "corePath": "/path/to/sing-box",
    "workingDir": "/path/to/config/dir",
    "systemProxy": {
      "enabled": true,
      "host": "127.0.0.1",
      "port": 2089,
      "bypassDomains": [],
      "matchDomains": []
    }
  }
}
```

**Success Response:**
```json
{
  "success": true,
  "data": {
    "pid": 12345
  },
  "message": "sing-box started"
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "ALREADY_RUNNING",
  "message": "sing-box is already running (pid: 12345)"
}
```

---

### 2. `stop` - Stop sing-box proxy

**Request:**
```json
{
  "command": "stop",
  "payload": {}
}
```

**Success Response:**
```json
{
  "success": true,
  "data": {},
  "message": "sing-box stopped"
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "NOT_RUNNING",
  "message": "sing-box is not running"
}
```

---

### 3. `status` - Query current status

**Request:**
```json
{
  "command": "status",
  "payload": {}
}
```

**Response (running):**
```json
{
  "success": true,
  "data": {
    "running": true,
    "pid": 12345,
    "uptime": 3600,
    "configPath": "/path/to/config.json"
  },
  "message": "sing-box is running"
}
```

**Response (not running):**
```json
{
  "success": true,
  "data": {
    "running": false,
    "pid": null,
    "uptime": null,
    "configPath": null
  },
  "message": "sing-box is not running"
}
```

---

### 4. `version` - Query service version

**Request:**
```json
{
  "command": "version",
  "payload": {}
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "serviceVersion": "1.0.0",
    "protocolVersion": "1"
  },
  "message": "silentx-service v1.0.0"
}
```

---

## Error Codes

| Code | Description |
|------|-------------|
| `OK` | Operation successful |
| `ALREADY_RUNNING` | sing-box is already running |
| `NOT_RUNNING` | sing-box is not running |
| `CONFIG_NOT_FOUND` | Configuration file does not exist |
| `CORE_NOT_FOUND` | sing-box binary does not exist |
| `CORE_NOT_EXECUTABLE` | sing-box binary is not executable |
| `PERMISSION_DENIED` | Insufficient permissions |
| `INVALID_CONFIG` | Configuration validation failed |
| `START_FAILED` | Failed to start sing-box process |
| `STOP_FAILED` | Failed to stop sing-box process |
| `SOCKET_ERROR` | Socket communication error |
| `INVALID_COMMAND` | Unknown command |
| `INVALID_PAYLOAD` | Malformed request payload |

---

## Connection Lifecycle

### Client Connection Flow

```
1. Client connects to /tmp/silentx/silentx-service.sock
2. Client sends JSON request + newline
3. Server processes request
4. Server sends JSON response + newline
5. Client may send another request or close connection
```

### Server Behavior

- Accepts multiple concurrent connections
- Each connection is handled in a separate thread/task
- Connections may be kept alive for multiple requests
- Server never initiates messages (request-response only)
- Connection timeout: 30 seconds of inactivity

---

## Swift Type Definitions

### Request Types

```swift
enum IPCCommand: String, Codable {
    case start
    case stop
    case status
    case version
}

struct IPCRequest: Codable {
    let command: IPCCommand
    let payload: [String: String]
}

struct StartPayload: Codable {
    let configPath: String
    let corePath: String
}
```

### Response Types

```swift
struct IPCResponse: Codable {
    let success: Bool
    let data: [String: AnyCodable]?
    let error: String?
    let message: String?
}

struct StatusData: Codable {
    let running: Bool
    let pid: Int?
    let uptime: Int?
    let configPath: String?
}

struct VersionData: Codable {
    let serviceVersion: String
    let protocolVersion: String
}
```

---

## Security Considerations

1. **Socket Permissions**: Socket is world-readable/writable, but only controls local proxy
2. **Path Validation**: Service validates all file paths exist and are accessible
3. **Process Isolation**: Service runs as root but only manages sing-box process
4. **No Sensitive Data**: No passwords or credentials pass through IPC

## Routing Semantics (macOS)

- If a configuration uses `tun.auto_route=false`, the TUN interface alone will not become the system default route.
- For configs that include `tun.platform.http_proxy.enabled=true`, the **client/service must apply macOS system proxy** to ensure system apps route traffic through sing-box.
- Therefore, `systemProxy` is a first-class optional input to `start` (and must be reverted on `stop`).
