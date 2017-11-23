# BLE Rect

This is a Flutter application that displays a square which can be
remotely manipulated using Bluetooth Low Energy.

The application publishes a GATT (Generic Attribute Profile) service
that provides three control points to modify different aspects of the
square.


## Service Definition

This application publishes a custom GATT service which is identified by the
128-bit UUID `548c2932-f58c-4c0b-9a4d-92110695a591`. The application advertises
this service UUID along with a name ("BLE Rect") while listening for a client to
connect.

A simple WebBluetooth client to interact with this service can be found
[here](https://armansito.github.io/ble_square_client/).

This service contains the following characteristics:

### Color

Field | Definition
--- | :---:
*UUID* | `2bf96f76-f872-422e-8dbd-d2b425850d91`
*properties* | `write`
*format* | `uint8[3]`
*description* | RGB components of the color

### Scale

Field | Definition
--- | :---:
UUID | `4939518b-b222-404d-90b5-7f675f13f27f`
properties | `write`
*format* | `uint8` (0-255)
*description* | The current scale as percentage

### Rotation

Field | Definition
--- | :---:
*UUID* | `f1121828-32b3-4675-a46e-db826531c348`
*properties* | `write`
*format* | `uint16` (0-360)
*description* | The current rotation in degrees
