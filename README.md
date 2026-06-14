# op1.fun app

Native macOS menu-bar companion app for [op1.fun](https://op1.fun).

This is a Swift/AppKit/SwiftUI rewrite of the old Electron app. It keeps the same core behavior:

- Finds a mounted OP-1 in disk mode.
- Scans `synth` and `drum` patch folders, excluding OP-1 `user` preset folders.
- Reads OP-1 AIFF/AIFC `APPL` metadata to categorize synth, drum, and sampler patches.
- Logs into `api.op1.fun` and enables the app feature flag.
- Registers the `op1fun://` URL scheme.
- Handles website "Save to OP-1" links for patches and packs.
- Downloads patch files into the mounted OP-1 under `synth`, `drum`, or pack subfolders.

## Development

Open `op1fun.xcodeproj` in Xcode, select the `op1fun` scheme, and run.

The project uses ad-hoc signing by default so it can build locally without a configured Apple team. For publishing, set your Team and signing identity in Xcode, then use Product > Archive.

## Sandboxing

The app includes App Sandbox entitlements for outbound network access, user-selected read/write access, and app-scoped security bookmarks. The user-selected disk permission is required for writing to an OP-1 mounted as an external volume.
