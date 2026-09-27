# FT2232H identification for automatic detection

[`ft2232h_config/sakura-x-shell.xml`](../ft2232h_config/sakura-x-shell.xml) is an FT_PROG EEPROM
template for the SAKURA-X shell. It sets the USB product description to
`SAKURA-X Shell`, so software can distinguish the shell from other devices
using the same FTDI VID/PID.

[`ft2232h_config/original.xml`](../ft2232h_config/original.xml) preserves the
original base configuration for reference or restoring the original settings.
Use `sakura-x-shell.xml` when configuring a board for automatic detection.
The base template does not replace a backup of an individual board's settings
and serial number.

The identification contract is:

| Field | Value / purpose |
| --- | --- |
| Vendor ID | `0403` |
| Product ID | `6010` |
| USB product string | `SAKURA-X Shell` (exact match) |
| USB serial number | Unique per board; pairs the two channels and selects a board when several are connected |
| USB interface number `00` | Channel A: existing FIFO communication |
| USB interface number `01` | Channel B: UART, reserved for reset control |

Do not identify a channel by its `/dev/ttyUSB*` number: these numbers depend
on enumeration order. Both channels belong to the same USB device and share
its product string and USB serial number. The product string alone does not
distinguish A from B. Devices with the old `USB <-> Serial Converter` product
string should require explicit port selection instead of automatic matching.

## Apply the template

1. In FT_PROG, scan the connected devices and save the current board settings
   as a backup. Record its serial number (for example, `FT97XO0A`).
2. Apply `ft2232h_config/sakura-x-shell.xml` to the intended FT2232H device using
   **Apply Template → From File**.
3. To preserve the existing board identity, disable serial-number
   auto-generation and enter the recorded serial number before programming.
   The shared template enables auto-generation for provisioning new boards;
   it does not contain a serial number to reuse across boards.
4. Program that device and reconnect USB so the host reads the new descriptors.

See the [FT_PROG user guide](https://www.ftdichip.com/Support/Documents/AppNotes/AN_124_User_Guide_For_FT_PROG.pdf)
for template application and programming instructions.

The template retains the supplied Channel A FIFO mode, Channel B UART mode,
driver selections, and electrical settings. In particular, both driver
selections remain D2XX; this change does not configure Windows VCP support.

## Verify on Linux

After reconnecting, `dmesg` should report `Product: SAKURA-X Shell`, with
VID/PID still `0403:6010`. Confirm the serial number separately; it may change
if auto-generation was used.

For each enumerated port, inspect the USB properties:

```sh
udevadm info --query=property --name=/dev/ttyUSB0
udevadm info --query=property --name=/dev/ttyUSB1
```

Use the actual port names reported by `dmesg`. Check that
`ID_USB_INTERFACE_NUM` is `00` for A and `01` for B, and that
`ID_SERIAL_SHORT` identifies the same board. `udevadm info --attribute-walk
--name=/dev/ttyUSB0` can also show the parent USB `product`, `serial`, and
interface `bInterfaceNumber` attributes.

Changing the EEPROM descriptors supplies identification metadata; host-side
automatic selection and reset control require corresponding driver support.
