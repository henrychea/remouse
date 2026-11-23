# Sandbox spike — why there is no App Store build

re:Mouse is MIT and ships outside the Mac App Store. A sandboxed build cannot do the one thing the app exists for.

## Result

Under the App Sandbox every filtering event tap fails, at every location, with Input Monitoring granted. Only a listen-only tap can be created, and a listen-only tap receives wheel events but cannot swallow or rewrite them, so it cannot invert anything. The sandbox also refuses the Accessibility grant for an ad-hoc sandboxed binary, and it refuses `NSRunningApplication.terminate()`, so the conflict list's Quit button could not work either.

## Evidence

Two runs of a sandboxed `AppStore` build on 2026-11-23, macOS 27.2 / Xcode 27.2, with a real wheel mouse. The second run, with Input Monitoring granted, is decisive; its log, in full:

```
--- spike start bundle=com.henrychea.reMouse app=.../AppStore/reMouse.app
sandbox=true home=~/Library/Containers/com.henrychea.reMouse/Data
preflight listen=true post=false ax=false
install after listen mode=listening@session report=defaultTap@session=fail defaultTap@annotated=fail defaultTap@hid=fail listenOnly@session=ok counters=discrete=0 continuous=0 inverted=0
requesting post-access
post-access not granted within 120s
install after post mode=listening@session report=defaultTap@session=fail defaultTap@annotated=fail defaultTap@hid=fail listenOnly@session=ok counters=discrete=123 continuous=0 inverted=0
matrix defaultTap@session=fail defaultTap@annotated=fail defaultTap@hid=fail listenOnly@session=ok listenOnly@annotated=ok listenOnly@hid=ok
result filtering-tap-unavailable
quit probe terminate accepted=false terminated=false
quit probe forceTerminate accepted=false terminated=false leftoverPid=67149
--- spike end
```

123 discrete wheel events reached the listen-only callback and none could be inverted: the owner scrolled a real wheel during the run and the direction on screen did not change.

| Option | Session | Annotated | HID |
| --- | --- | --- | --- |
| `kCGEventTapOptionDefault` | **fail** | **fail** | **fail** |
| `kCGEventTapOptionListenOnly` | ok | ok | ok |

Denials from the same run:

```
launchd[1] denied lookup: name = com.apple.universalaccessAuthWarn, requestor = reMouse, error = 159: Sandbox restriction
Failed to match existing code requirement for subject com.henrychea.reMouse and service kTCCServiceAccessibility
service kTCCServiceAppleEvents requires entitlement com.apple.security.automation.apple-events but it is missing
```

So the sandbox allows an input-observing tap and refuses an input-modifying one.

## What is left

Nothing that could carry an inverted wheel. Re-posting inverted duplicates cannot suppress the original event, so the page scrolls twice in opposite directions. A DriverKit virtual HID device cannot ship inside a Mac App Store app. Flipping the global natural-scrolling preference also flips trackpads, which is the one thing this app exists to avoid. An HID-level tap needs root outside the container. That is why re:Mouse is a free MIT release, ad-hoc signed, outside the sandbox.
