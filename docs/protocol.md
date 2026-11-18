# Rapoo MT760(L) configuration protocol (A HUB, static analysis)

Status: first pass, written from static analysis of `libRapooDevice.dylib`
(A HUB 1.1.0, x86_64, sha256 `04778a3c…fadc`). Nothing was sent to the mouse.
Addresses below are in that dylib. Tags: **[C]** = confirmed from code,
**[I]** = inferred, **[L]** = observed live (from the coordinator's descriptor dump).

## 0. One open conflict (check this first)

**[C]** `BaseProtocol::BaseProtocol` (0x271a0) picks the first packet byte (the HID
report ID) and the read length from `ChipType`:

| ChipType | first byte (report ID) | read length (`this+0x61`) |
|---|---|---|
| 3, 6, 11, 15, 17, 0xBB | `0x06` | `0x21` (33) |
| 8 | `0x06` | `0x40` |
| 0x12 | `0x04` | `0x40` |
| 0x0C | `0x55` | `0x40` |
| anything else, **including 7** | `0xBA` | `0x20` (32) |
| BLE + "AIKeyboard" | `0x08` | |

**[L]** The 2.4G dongle (24AE:1870) has one vendor collection (usage page 0xFF01,
usage 0x00) with **report ID 6, 28 data bytes (29 with the ID)** for Input, Output
and Feature. No report 0xBA exists.

So at runtime the protocol object for this mouse must run with a ChipType in the
report-6 group (3/6/11/15/17), not the `chipType: 7` in `Factory Config.json`.
That 7 is probably the GUI's own enum. I could not yet trace which tuple field
becomes `ChipType` (see section 2). **Use report ID 6.** Every packet below writes
the report-ID byte as `RID`. Use `RID = 0x06` on the dongle.

## 1. Device class

**[C]** `DeviceFactory::getDevice(name, …)` (0xc5f40) compares the name string.
`"MT760"`, `"MT760 Mini"`, `"MT560"`, `"MT550"`, `"MT750"`, `"MT760ai"`,
`"MT760 PRO"`, `"MT660"`, `"MV30"` and `"MT770L"` all go to 0xc80fc, which runs
`new MouseForTelink(name, …)`. `"MT760 NL"` and `"MT760AI"` go to other classes.
The GUI maps the reported `"MT760L"` to `"MT760"` (NameMapping in the main app,
around 0x1001dd6c5).

`MouseForTelink` uses a plain `BaseProtocol` (0xb0 bytes, allocated in
`BaseDevice::openDevice`, 0x93740). It overrides the DPI, report-rate, key, macro
and config methods. It inherits battery, factory reset and low-power from `Mouse`.

## 2. Discovery

**[C]** `DeviceInfoManager::getDevices` puts a 16 x u16 tuple under the key
`"MT760"` (constant at 0x29b360):

```
24AE 4500 1870 0001 0001 000E 0002 0007 0001 000E 0002 0007 4500 0000 0001 000C
```

`UHid::getDeviceList(vid, map)` (0x198a0, hidapi `hid_enumerate`) matches it like this:
- `pid == t[1] (0x4500)` and `interface_number == t[4] (1)`: **wired** (USB cable)
- `pid == t[2] (0x1870)` and `interface_number == t[8] (1)`: **wireless** (2.4G dongle)
- `pid == t[12] (0x4500)` and iface == t[4]: "ble". This branch can never run for
  MT760, because t[1] == t[12] and the wired test comes first.
- t[3] = 1 is stored as `"type"` (DeviceType 1 = mouse).
- **[I]** The other fields probably follow BaseDevice's keys (Usage, UsageReport,
  ChipType, then the Wireless* versions), but the order is not proven. 7 sits in
  t[7] and t[11], which is why the GUI says "chipType 7".

In practice: open VID 0x24AE, PID 0x1870 (dongle) or 0x4500 (cable). Take the HID
interface whose usage page is 0xFF01 (interface 1). On the dongle that is
**[L]** report ID 6, 28-byte payload.

Bluetooth ("Rapoo BT Mouse") **[C]**: the code has a CoreBluetooth path
(`BleDevice`, `BleDeviceDelegate`, 0x22b80). It discovers characteristics and
matches them by UUID substring:
- a characteristic containing `BA02`: notifications on (responses)
- a characteristic containing `BA03`: writes (`writeValue:forCharacteristic:type:0`,
  with response)
- the PnP ID (0x2A50 in service 0x180A) gives VID/PID

A Qt `BleCommunicator` also carries the Telink OTA UUIDs `00010203-0405-0607-0809-0a0b0c0dff01/02/03`
(ff03 = write, ff02 = notify). That path is likely only for pairing or OTA.
Over BLE, MT760 command templates are 1 byte with no RID/route header (section 4).
The user's logs show getReturnRate, getKeyInfoList and getMacroInfo failing, which
**[I]** suggests BLE configuration is only partly supported.

## 3. Framing (HID: cable and dongle)

**[C]** I/O paths:
- **Write**: `UHid::writeDevice` (0x1ebd0) calls `hid_write(dev, buf, len)`. That
  is a HID **Output** report: buf[0] = report ID, `len` = only the meaningful bytes
  (3 to 25). On macOS use `IOHIDDeviceSetReport(kIOHIDReportTypeOutput, 6, buf, …)`.
  **[I]** Pad to the full 29 bytes (ID + 28) to be safe. hidapi sends it short.
- **Read**: `UHid::readDevice` (0x1ed30) sets buf[0] = RID and calls
  `hid_get_input_report(dev, buf, 0x21)`, a GET_REPORT(**Input**, id) control
  request, not an interrupt read. While `buf[0] == 0x02` it waits 2 ms and retries,
  up to 250 times.
- Feature reports (`setFeatureDevice`/`getFeatureDevice`) exist but this path does
  not use them.

**[C]** Command flow (`BaseProtocol::sendMessage(resp, req, len, keepId)`, 0x281a0):
1. `delayMicroseconds(T*1000)`, then write `req`.
2. `delayMicroseconds(T*1000)`, then set `resp[0] = req[0]` and GET_REPORT(Input).
3. Success means `resp[0] == 0x01`. MouseForTelink treats `0x02` as "TIMEOUT"/busy
   and anything else as an error.

T (`this+0xa8`): wired = 1 ms, wireless = 5 ms (110 ms if ChipType is 7), ble = 5 ms.

**[I]** The code reads a status byte from resp[0], but on macOS
`IOHIDDeviceGetReport` normally returns the report ID there. Expect either
`[06, status, …]` (shift every response offset below by +1) or firmware that puts
status in byte 0. Check with the first read-only command.

**No checksum** on these packets **[C]** (`calculateAndFillChecksum` is not used on this path).
**No handshake or auth** before configuration **[C]**. `readAuthCodeToMouse` only
runs in the factory pairing tool (`DevicePairingForTelinkMouse`).

Packet layout **[C]** (templates from `MessageManager::getMessageList`, 0x3d880):

```
RID  ROUTE  CMD  [payload...]
ROUTE = 0xA5 wireless (dongle relays to mouse), 0xFF wired, (0xA6 on "ble" HID)
```

Dongle-local commands have no ROUTE byte: `RID CMD …`.

## 4. Command table (MT760 path)

| id | name | HID bytes | BLE |
|---|---|---|---|
| 2001 | inWorkMode | `RID R A1` | |
| 2003 | getFWVersion (mouse) | `RID R A3` | `05` |
| 2004 | **read memory** | `RID R A4 len a0 a1 a2 a3` | `02 …` |
| 2005 | **write memory** | `RID R A5 len a0 a1 a2 a3 data…` | `01 …` |
| 2007 | resetDevice (reboot) | `RID R A7` | |
| 2010 | getElectricity (battery) | `RID R AA` | `04` |
| 2011 | resDefaultSet (factory reset) | `RID R AD 52 3D` | `03` |
| 2015 | deleteConfig | `RID R D0` | |
| 2016 | addConfig | `RID R D5` | |
| 1011 | dongle FW version | `RID B0` | |
| 1004/1005 | dongle memory r/w | `RID A3 A4` / `RID A3 A5` | |

Addresses are 32-bit little-endian. `len` is the number of data bytes.

**[C]** Read memory (`BaseProtocol::getDeviceMemory`, 0x36850): request
`RID R A4 len addr32`. Response data starts at **resp[4]** (resp[0] = status).
Write memory: request `RID R A5 len addr32 data[len]`, so data starts at req[7]
counting RID.

### 4.1 Read-only commands

- **Firmware version** **[C]** (`MouseForTelink::getFWVersion`, 0x221fc0):
  `RID R A3`. If resp[0]==1: `"V" + resp[4] . resp[3] . resp[2] . resp[1]` (decimal).
- **Battery** **[C]** (`Mouse::getElectricity`, 0x12d660): `RID R AA`.
  resp[1] = BatStatus (charging flag), resp[2] = percent (capped at 100).
- **Connection state**: no explicit command. Wired vs wireless comes from the PID.
  **[I]** If ROUTE A5 commands fail on the dongle, the mouse is asleep or out of range.
- **DPI table** **[C]** (`getDPIListInfo`, 0x226fa0): read 24 bytes @ **0x638**
  (BLE: two 12-byte reads @ 0x64C and 0x658).
  data[0..13] = 7 x u16 LE, **DPI = value x 50**. data[14] = number of levels - 1.
  data[16] = current level - 1.
- **Current DPI level** **[C]** (`getCurDPIGear`, 0x2286e0): read 8 @ **0x65C**
  (BLE 0x648). data[0] = level index (0-based).
- **Report rate** **[C]** (`getReturnRate`, 0x224330): read 8 @ **0x630**.
  data[0] = wired rate code, data[1] = wireless rate code.
  Codes (BaseDevice hash at +0x150): `08`=0 (125 Hz), `04`=1 (250), `02`=2 (500),
  `01`=3 (1000), `84`=4, `82`=5, `81`=6 (**[I]** 2k/4k/8k). The user's
  `returnRate: 3` means 1000 Hz.
- **Button map**: one 4-byte slot per key @ **0x600 + 4*KeyID** (see 4.2 for the
  format). The per-key read goes through `bufTOFunc` (0x231890), which still needs
  decoding. A 16-byte read is visible at 0x22c78a.

### 4.2 Write commands

- **Set DPI table** **[C]** (`setDPIListInfo`, 0x225fe0): first read 8 @ 0x65C and
  keep data[1..3]. Then write 20 @ 0x638:
  `7 x u16 (dpi/50)`, `[14]=levels-1`, `[15]=0`, `[16]=curLevel-1`,
  `[17..19]=` the kept bytes. BLE writes 12-byte chunks @ 0x64C.
- **Set current DPI level** **[C]** (`setCurDPIGear`, 0x227cd0): read 8 @ 0x65C,
  then write 4 @ 0x65C: `[level-1, old[1], old[3], old[2]]` (A HUB swaps bytes 2
  and 3. Write `old[1], old[2], old[3]` if that turns out to be a bug).
- **Set report rate** **[C]** (`setReturnRate`, 0x223b50): read 8 @ 0x630, then
  write 4 @ 0x630: `[code, code, old[2], old[3]]`, using the code table above.
- **Button remap** **[C]** (`MouseForTelink::setKey`, 0x22a3e0): write 4 @
  `0x600 + 4*KeyID`, bytes `[t, b1, b2, b3]`. Switch on the GUI KeyType:

  | GUI KeyType | t | b1 b2 b3 |
  |---|---|---|
  | 0 disable | 07 | 0 0 0 |
  | 1 keyboard key | 01 | 00, HID usage, 00 |
  | 2 consumer/media | 04 | ?, u16 LE usage at b2..b3 |
  | 4 mouse buttons | 03 | ?, bitmask from MouseKeyList (F0=bit0 left, F1=bit1 right, F2=bit2 middle, F3=bit3 back, F4=bit4 forward)… |
  | 6 vertical wheel | 0B | 00, 2 (or other per VerticalRoller), 00 |
  | 7 horizontal wheel | 0C | ?, val, FF |
  | 8 macro | 05 | ?, MacroID, ? |
  | 15 shortcut | 02 | 00, modifier bitmask (E0..E7 → bit0..7), key usage |
  | 50 DPI func | 08 | ?, KeyCode, ? |
  | 51 fire/sniper/macro | 09 | ?, KeyCode, ? |
  | 52 DIY/config cycle | 0A | ?, KeyCode, ? |

  Types 3, 5, 9-14 and 16-49 write nothing. The user's config sets key 4 to
  `MouseKeyList [242]`, so t=03 with bit 2.
  Key IDs (rcc/000e61ca56.json): 0 left, 1 middle, 2 right, 3 or 11 DIY,
  4 DPI cycle, 5 side "right", 6 side "left", 7/8 wheel tilt left/right,
  9/10 wheel up/down.
- **Sleep time**: `MouseForTelink::setSleepTime` logs "not supported".
  `getSleepTime` returns 0 **[C]**.
- **Low-power switch**: `Mouse::getLowPowerSwitch` reads 4 bytes at the address in
  `this+0x344`. It fails on this mouse (log) **[C]**.
- **Sensor mode / LOD**: "setSensorMode function is not supported" **[C]**.
- **Factory reset**: `RID R AD 52 3D` **[C]**.

## 5. Not done yet (next pass)

`bufTOFunc` (key read decoding), `getMacroInfo`/`getMacro`/`setMacro` (macro
storage, which fails in the user's log), `getConfig*`/profiles (addresses 0x34,
0x23, 0x1000, 0x11000 in the MouseForTelink address table), and the exact index
of ChipType in the device tuple.

MouseForTelink address table (ctor 0x221000) **[C]**:
`600 604 608 60C 610 614 618 61C 620 624 628 630 634 638 646 648 64C 65A 65C 34 23 1000 11000`.
