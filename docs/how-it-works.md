# How MT Control works

This page explains, without jargon, what MT Control actually does with your mouse and your Mac.

## Two kinds of settings

MT Control handles two different kinds of settings, and they work in different ways.

**1. Settings stored in the mouse.** The MT760 has a small amount of memory inside it, which holds:
- the speed (DPI) of each of its 7 stages and which stage it's on,
- how many stages the top button cycles through,
- how often it reports its position to the computer (the polling rate),
- what each button does.

When you change one of these, MT Control writes the new value into that memory. The mouse then behaves that way on any computer, even with MT Control closed.

**2. Settings on your Mac.** Things like "the back button opens Mission Control in Safari" or "reverse the scroll wheel" are handled by MT Control on your Mac. When you press a button, macOS tells MT Control, and MT Control swaps the click for the action you picked. These only work while MT Control is running.

## How the app talks to the mouse

The mouse talks to the 2.4 GHz USB receiver over radio, and the receiver talks to your Mac over USB.

To the Mac, the receiver looks like a mouse and a keyboard, because the mouse can be set up to send key presses. Hidden inside the keyboard part is a private channel Rapoo uses for settings. MT Control sends short messages down that channel, such as "what's your battery level?" or "put this number at this spot in your memory", and reads the replies.

Because the channel sits inside the keyboard part, macOS asks for **Input Monitoring** permission before any app can use it. MT Control only uses the settings channel. It doesn't look at what you type.

Each message is tiny, about 30 bytes. A typical exchange looks like this:

1. MT Control asks for the stage settings.
2. The mouse replies with the speed of each stage (800, 1000, 1200…) and which stage it's on.
3. You drag a slider and click Save.
4. MT Control sends the new numbers.
5. It asks for the stage settings again and checks they changed. If they didn't, the app tells you.

## How we worked out the messages

Rapoo doesn't publish how its mice are configured. We worked it out in three steps:

1. **Reading Rapoo's app.** A HUB contains the code that builds these messages. Taking that code apart showed the commands for reading and writing settings, and roughly where each setting lives in the mouse's memory.
2. **Watching A HUB work.** We recorded the messages A HUB sent while it ran. That showed which USB channel it really uses, which turned out to be the hidden one inside the keyboard part, not the obvious one.
3. **Testing on a real mouse.** Each command was tried on an MT760L, one at a time, starting with read-only ones. For settings that weren't clear, we saved a copy of the mouse's settings memory, pressed a button on the mouse, saved another copy, and compared the two. That's how we found where the mouse keeps its current speed stage.

Every step and every message is written down in [protocol.md](protocol.md), so anyone can check it or build on it.

## Safety measures

- **Same commands as Rapoo's app.** MT Control doesn't use any command that A HUB doesn't use.
- **Read before writing.** When a setting shares a spot in memory with other values, the app reads that spot first and only changes the part you asked for.
- **Check after writing.** After every change, the app reads the setting back and tells you if the mouse didn't keep it.
- **Left click is protected.** The app only lets you change the top and bottom buttons inside the mouse. The left, right and wheel buttons can't be changed there, so you can't lock yourself out of clicking.
- **No firmware updates.** MT Control never touches the mouse's firmware.
- **Everything is logged.** Every message is saved to `~/Library/Logs/MTControl/hid.log` (in your Library folder, under Logs), so if anything looks wrong you can see exactly what was sent.

## How the Mac features work

**Button actions and gestures.** With **Accessibility** permission, MT Control can watch mouse button presses before other apps see them. When you press a button you've given an action to, MT Control stops the original click and does the action instead. Mission Control, for example, works by pressing the same keyboard shortcut you'd use yourself (Control + Up Arrow by default). If you've changed those shortcuts in System Settings, MT Control uses yours.

**Gesture button.** While you hold the gesture button, MT Control measures how far the mouse moves. Past a set distance up, down, left or right, it does that direction's action. If you let go without moving, it does the "click" action.

**Scrolling.** A mouse wheel and a trackpad send different kinds of scroll signals, so MT Control can change wheel scrolling without touching the trackpad. Reverse flips the direction. Smooth scrolling turns each notch of the wheel into a short glide. Speed scales how far each notch moves.

**App profiles.** MT Control notices which app is in front. If that app has its own profile, its button actions apply, and the mouse can switch to that app's speed stage. When you switch to an app without a profile, the previous stage comes back.

## Privacy

MT Control has no account, no analytics and no internet access, apart from the update and help links, which open in your browser. Your settings stay on your Mac and in your mouse.
