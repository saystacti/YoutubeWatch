# YouTube Watch — Apple Watch Series 3 / watchOS 8.7

This is a watch-only SwiftUI prototype. It does not require an iPhone companion at runtime.

## Important limitations

- YouTube does not provide an official watchOS player.
- This prototype searches through a public Invidious instance and asks that service for a playable stream URL. Public instances can be offline, rate-limited, blocked, or change their API.
- Some videos will not have a compatible stream. This is not an official YouTube app and playback is not guaranteed.
- watchOS video playback is intended for short foreground clips and can be hard on battery life.
- This source has not been compiled or tested on a physical Series 3. A real Xcode build and device test are required.

## Build it

You need a Mac with Xcode 13.4.1 (the SDK Apple documents for watchOS 8.7), an Apple ID for signing, and your Series 3 paired for development.

1. Open Xcode and choose **File → New → Project**.
2. Choose **watchOS → App**. Choose SwiftUI and **Watch-only App** if offered.
3. Set the deployment target to **watchOS 8.0** (or earlier if Xcode allows it).
4. Replace the generated app entry file with `YouTubeWatchApp.swift`.
5. Add `ContentView.swift` to the Watch App target.
6. In the Watch App target's Signing & Capabilities, select your Personal Team.
7. Build and run on your Apple Watch.

If Xcode reports that `VideoPlayer` is unavailable for the selected watchOS SDK, the native video-player view needs to be adapted for that SDK; do not raise the deployment target above watchOS 8.7, because that would exclude your watch.

## Network access

The app makes HTTPS requests to `https://inv.nadeko.net`. If that public instance is unavailable, change `defaultInstance` at the top of `ContentView.swift` to another working Invidious instance. Availability and API behavior are outside this app's control.

## Files

- `YouTubeWatchApp.swift` — app entry point
- `ContentView.swift` — search, stream lookup, and playback UI
