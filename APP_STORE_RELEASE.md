# App Store Release Checklist

## Current App Settings

- App name: `op1.fun`
- Bundle ID: `com.fiftyfootfoghorn.op1fun`
- Version: `2.0`
- Build: `1`
- Minimum macOS: `13.0`
- Category: Music
- Signing: Automatic signing is enabled. Select the paid Apple Developer team once Apple finishes renewing the account.

## App Store Connect Metadata

- Name: `op1.fun`
- Subtitle: `OP-1 patch companion`
- Description:

```text
op1.fun is a native macOS menu bar companion for op1.fun.

Log in with your op1.fun account, connect your OP-1 in disk mode, and save synth, drum, and sampler patches directly to the correct folders on the OP-1 disk. The app remembers approved OP-1 disks using macOS security-scoped access, so future saves work without repeated file prompts.
```

- Keywords: `OP-1,Teenage Engineering,patches,synth,drum,sampler,op1.fun`
- Support URL: `https://op1.fun`
- Marketing URL: `https://op1.fun`
- Privacy Policy URL: required before submission.
- Copyright: `2026 Fifty Foot Foghorn`

## Privacy Answers

The app does not track users across apps or websites.

Data linked to the user:

- Email address, used for app functionality when logging in to the op1.fun API.

Data not sent to op1.fun:

- OP-1 disk association bookmarks are stored locally by macOS/UserDefaults.
- Downloaded patch files are written locally to the user-selected OP-1 disk.
- API tokens are stored in Keychain.

## Account Items Still Pending

- App Store Connect must stop showing `Developer Program Membership Expired`.
- Complete Digital Services Act trader status before submitting for EU distribution.
- After the paid team appears in Xcode, select it under `op1fun > Signing & Capabilities > Team`.

## Build Steps

1. In Xcode, select `op1fun` as the scheme and `Any Mac` or `My Mac` as the destination.
2. Confirm `Signing & Capabilities` uses the paid Apple Developer team.
3. Select `Product > Archive`.
4. In Organizer, select the archive and choose `Distribute App`.
5. Choose `App Store Connect`, then upload.
6. In App Store Connect, attach the uploaded build to the macOS `2.0` version and submit for review.
