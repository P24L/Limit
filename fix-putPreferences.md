# ATProtoKit putPreferences Bug Report & Fix Guide

## Problem Description

The `putPreferences` method in ATProtoKit fails to properly serialize certain preference objects when sending them back to the API. Specifically, some preference objects lose their `$type` property during serialization, causing the server to reject the request.

### Error Message
```
badRequest(error: ATProtoKit.APIClientService.ATHTTPResponseError(error: "InvalidRequest", message: "Input/preferences/0 must be an object which includes the \"$type\" property"))
```

## Reproduction Steps

1. Call `getPreferences()` to fetch user preferences
2. Modify any preference (e.g., SavedFeedsV2)
3. Send all preferences back using `putPreferences(preferences:)`
4. Server rejects the request because some objects are missing `$type` property

### Example Code That Fails
```swift
// Fetch current preferences
let preferencesOutput = try await atProtoKit.getPreferences()
var preferences = preferencesOutput.preferences

// Modify SavedFeedsV2 (example)
for (index, pref) in preferences.enumerated() {
    if case .savedFeedsVersion2(var savedFeeds) = pref {
        // Modify saved feeds...
        preferences[index] = .savedFeedsVersion2(savedFeeds)
    }
}

// This fails - some preferences lose $type during serialization
try await atProtoKit.putPreferences(preferences: preferences)
```

## Technical Analysis

### Current Behavior
When deserializing preferences from the API response, ATProtoKit correctly parses all preference types. However, when serializing them back for the `putPreferences` call, some preference objects don't include the required `$type` field.

### Debug Output
```
[13:55:58] BlueskyClient.swift - putPreferences - Sending 5 preferences
[13:55:58] BlueskyClient.swift - putPreferences - [0] Other preference type
[13:55:58] BlueskyClient.swift - putPreferences - [1] Other preference type
[13:55:58] BlueskyClient.swift - putPreferences - [2] Other preference type
[13:55:58] BlueskyClient.swift - putPreferences - [3] Other preference type
[13:55:58] BlueskyClient.swift - putPreferences - [4] SavedFeedsV2 with 9 items
```

The first 4 preferences are not properly recognized/serialized.

### Expected JSON Structure
Each preference object must include a `$type` field:
```json
{
  "preferences": [
    {
      "$type": "app.bsky.actor.defs#adultContentPref",
      "enabled": true
    },
    {
      "$type": "app.bsky.actor.defs#savedFeedsV2",
      "items": [...]
    }
  ]
}
```

## What Needs to Be Analyzed

1. **PreferenceUnion Encoding**: Check how the `PreferenceUnion` enum encodes its cases to JSON
2. **Codable Implementation**: Verify that each preference type properly includes `$type` in its `encode(to:)` method
3. **JSON Serialization**: Ensure the JSON encoder preserves the `$type` field for all preference types

### Key Files to Check
- `PreferenceUnion` enum definition and its Codable implementation
- Individual preference type definitions (AdultContentPreferencesDefinition, ContentLabelPreferencesDefinition, etc.)
- The encoding logic in `putPreferences` method

## Proposed Fix

### Option 1: Fix PreferenceUnion Encoding
Ensure that the `PreferenceUnion` enum's `encode(to:)` method properly adds the `$type` field for each case:

```swift
extension PreferenceUnion: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .adultContent(let pref):
            try container.encode("app.bsky.actor.defs#adultContentPref", forKey: .$type)
            try pref.encode(to: encoder)
        case .savedFeedsVersion2(let pref):
            try container.encode("app.bsky.actor.defs#savedFeedsV2", forKey: .$type)
            try pref.encode(to: encoder)
        // ... other cases
        }
    }
}
```

### Option 2: Add $type to Individual Preference Types
Ensure each preference type includes the `$type` property:

```swift
struct AdultContentPreferencesDefinition: Codable {
    let type: String = "app.bsky.actor.defs#adultContentPref"
    let enabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case enabled
    }
}
```

### Option 3: Custom JSON Encoder Configuration
Configure the JSON encoder to handle the union types correctly:

```swift
func putPreferences(preferences: [PreferenceUnion]) async throws {
    let encoder = JSONEncoder()
    // Add custom encoding strategy if needed
    let data = try encoder.encode(["preferences": preferences])
    // Send request...
}
```

## Testing

### Test Cases

1. **Test All Preference Types**: Ensure each preference type can be fetched and sent back without error
2. **Test Mixed Preferences**: Test with multiple preference types in one request
3. **Test Empty Preferences**: Test with an empty preferences array
4. **Test Single Preference**: Test updating only one preference type

### Verification Code
```swift
// Test that all preference types serialize correctly
func testPreferencesSerialization() async throws {
    let prefs = try await atProtoKit.getPreferences()
    
    // Verify we can send them back without modification
    try await atProtoKit.putPreferences(preferences: prefs.preferences)
    
    // Verify each preference type
    for pref in prefs.preferences {
        let json = try JSONEncoder().encode([pref])
        let jsonString = String(data: json, encoding: .utf8)!
        
        // Check that $type is present
        assert(jsonString.contains("$type"), "Missing $type in \(pref)")
    }
}
```

## Workaround (Currently Used)

As a temporary workaround, we only send the SavedFeedsV2 preference:
```swift
// Only send SavedFeedsV2, ignoring other preferences
return await putPreferences(preferences: [.savedFeedsVersion2(newSavedFeeds)])
```

This works but has the side effect of deleting all other user preferences.

## Additional Context

- The bug affects all preference update operations (pin/unpin, reorder, subscribe/unsubscribe)
- SavedFeedsV2 seems to serialize correctly, but other preference types don't
- The issue is specifically with the serialization, not deserialization
- This is a critical bug as it prevents proper preference management

## References

- AT Protocol Lexicon: https://atproto.com/lexicons/app-bsky-actor#appbskyactorputpreferences
- Related issue: Content-Type header bug (already fixed in latest version)