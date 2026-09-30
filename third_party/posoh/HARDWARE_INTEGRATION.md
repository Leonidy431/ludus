# ESP32-S3 + HackRF One Integration & Mounting

> **⚠️ STALE — pending rewrite.** This document predates the ESP32-S3 →
> nanoESP32-C6 (ESP32-C6-WROOM-1) hardware migration that CLAUDE.md's
> Phase 1 declares complete. Every GPIO number below is for the wrong
> chip — the C6 has a different pin count and different strapping pins.
> For the current platform's pinout, module footprint, and QSPI planning,
> see `NANOESP32C6_QSPI_PINOUT.md`. The mechanical mounting-stack and RF
> path sections here still need a from-scratch rewrite against the C6;
> tracked as an open item, not yet done.

## Electrical Connections

### SPI Interface (Primary Control Path)
ESP32-S3 → HackRF One USB (via FT232H or CH340 Serial-to-SPI converter)

| ESP32-S3 Pin | Signal    | HackRF Signal |
|---|---|---|
| GPIO 8  | SPI_CS    | FX3_CS / OE (chip select) |
| GPIO 9  | SPI_MOSI  | FX3_MOSI → FPGA SPI_DI |
| GPIO 10 | SPI_MISO  | FX3_MISO → FPGA SPI_DO |
| GPIO 11 | SPI_CLK   | FX3_SCK → FPGA SPI_CLK |

**Note**: HackRF One's primary interface is USB 2.0 (480 Mbps), not SPI. The above mapping assumes a USB-to-SPI adapter (FT232H, Digilent JTAG) for direct FPGA access. For production, use **libusb-based API** (see *Software Control* below).

### I2C Interface (Configuration & Telemetry)
ESP32-S3 → HackRF auxillary I2C for sensor fusion (temperature, supply voltage monitoring)

| ESP32-S3 Pin | Signal    | HackRF Aux I2C |
|---|---|---|
| GPIO 5  | SDA (I2C) | TDA8950 / MAX4208 feedback (aux daughter board) |
| GPIO 6  | SCL (I2C) | Config I2C (if populated) |

### UART Control (Fallback / YubiKey Bridge)
ESP32-S3 → External UART module (for activation flow)

| ESP32-S3 Pin | Signal         |
|---|---|
| GPIO 1  | TX (activation payload upstream) |
| GPIO 2  | RX (YubiKey NFC bridge / field config) |

### Power Distribution

```
┌─ 12V Ext Power Supply ──┬─→ [Voltage Regulator] ──→ 5V Rail
│                         └─→ [HackRF PWR IN]
│
├─→ [INA219 Current Shunt] ──→ ESP32-S3 VBUS (3.3V LDO)
│   (I2C: GPIO 5/6)
│
├─→ [PTC Fuse 1A] ──→ HackRF One USB Power
│   (Protects against RF-induced current surge)
│
└─→ [Bypass Capacitors]
    ├─ C1: 100µF (bulk, 12V rail)
    ├─ C2: 10µF (5V HackRF)
    ├─ C3: 1µF (ESP32-S3 3.3V)
    └─ C4: 0.1µF (decoupling, SPI lines)
```

## Physical Mounting Layout

### Module Stack (Z-axis, bottom to top)
```
[4] ┌─────────────────────────────┐
    │  HackRF One mainboard       │ ← U.FL antenna SMA (upward)
    │  (70mm × 85mm)              │   USB port (right edge)
    └──────────┬──────────────────┘
               │ [Nylon standoff M2×8mm, 4×]
[3] ┌─────────────────────────────┐
    │  Bias-T + LNA + Filter      │ ← Daughter board (optional)
    │  (50mm × 30mm)              │   ADS-B/SatDL tuned
    └──────────┬──────────────────┘
               │ [Aluminum spacer 10mm]
[2] ┌─────────────────────────────┐
    │  Power Distribution Board    │ ← INA219, buck/boost regulators
    │  (ESP32-Breakout + connectors)  CAN/I2C headers
    └──────────┬──────────────────┘
               │ [Nylon standoff M2×6mm, 4×]
[1] ┌─────────────────────────────┐
    │  ESP32-S3-DevKitC-1 Board   │ ← USB-C (left), SD card slot
    │  (27.7mm × 57mm)            │   Reset / Boot buttons
    └──────────┬──────────────────┘
               │
         [Velcro grip base]
```

### Mechanical Envelope
- **Total height**: ~40mm (excluding antenna)
- **Footprint**: 90mm × 90mm (accounts for USB cable clearance)
- **Weight**: ~280g (HackRF 115g + ESP32 25g + PSU 140g)
- **Gripping**: Non-slip rubberized 3D-printed enclosure

### RF Path (Critical Layout)
```
┌─ ESP32-S3 (3.3V Digital) ─────────┐
│                                     │
├─ [I2C Pullups R1/R2 4.7kΩ]         │
│                                     │
├─ [SPI Isolation Resistors R3-R6 1kΩ]
│   (Protects ESP32 GPIO from HackRF 5V tolerant pins)
│
└─→ [USB Cable Shielded] ──────→ HackRF One
    │
    ├─ [Ferrite toroid F1] ← 2.5A current sensor (INA219)
    │
    └─→ RF Input [U.FL/SMA adapter]
        │
        ├─ [LNA ≤30dB gain cap] ← TX Bias-T inhibit when Rx
        │
        └─ [SMA Connector] ──→ Antenna (λ/4 or λ/2)
```

**Trace Impedance Control**: SPI_CLK and MISO traces routed as 50Ω stripline (0.5mm spacing) to minimize EMI coupling into RF input.

## Software Control (libusb/HackRF API)

### Python Interface (via libhackrf)
```python
import hackrf
dev = hackrf.open()
dev.sample_rate = 20e6  # 20 MSps
dev.center_freq = 915e6  # 915 MHz ISM band
dev.lna_gain = 32       # Max LNA (do not exceed 40dB in field)
dev.vga_gain = 62       # Rx gain
dev.tx_enable = False   # Rx-only unless authorized active sounding

# Read temperature & supply current (via INA219 on I2C)
supply_voltage = dev.supply_voltage()  # ≈5.0V
bias_current = dev.current()           # ≈280mA idle, ≈500mA Rx
```

### ESP32-S3 Control Loop (Pseudo-code)
```c
// Activation-gated RF control loop
if (AccessManager.is_authorized("active_rf")) {
    HackRF_Init(SPI_BUS, GPIO_CS);
    HackRF_SetFreq(CENTER_FREQ);
    HackRF_SetGain(LNA_GAIN, VGA_GAIN);
    
    // Monitor INA219 current
    current_mA = INA219_Read(I2C_BUS);
    if (current_mA > THERMAL_LIMIT_MA) {
        HackRF_TxEnable(false);  // Immediate TX shutoff
        log_event("THERMAL_THROTTLE", current_mA);
    }
}
```

## Antenna Recommendations

### Receive-Only (RF Audit, Telemetry Decode)
- **700–1200 MHz**: ½λ monopole (13cm) + ground plane (30cm radius)
- **2.4 GHz**: ¼λ helix (Kraus design, 3-turn, 32mm pitch)

### Active TX (SDR Emulation, Subject to 6-point Exception)
- **Sub-GHz TX**: Logarithmic periodic dipole array (LPDA, 400–1200 MHz)
- **ISM Band Tuning**: Trim monopole length via screw adjust (±5% frequency)
- **TX Power Limit**: HackRF One max 0 dBm (1 mW) — suitable for 1–10m lab range

## Thermal Management

### Heat Dissipation Path
```
HackRF FPGA (Xilinx Spartan-6) → PCB Thermal Vias → Aluminum backing plate
│
└─→ External Heat Sink (if Rx > 10 min continuous)
    - Aluminum L-bracket 80×60×10mm
    - Mounted on side, allows convection
    - Reduces junction temp ~15°C
```

### Current Monitoring (INA219)
- **Shunt**: 0.1Ω, 1% tolerance
- **Max measurable**: 3.2A at 320mV drop
- **I2C addr**: 0x40 (default)

**Alert Thresholds**:
- Rx idle: ≤300 mA ⟹ Normal
- Rx + LNA+VGA: 400–500 mA ⟹ Nominal
- TX active: 700–900 mA ⟹ Check antenna impedance match
- >1000 mA ⟹ THERMAL_THROTTLE, reduce VGA gain

## Assembly Checklist

- [ ] Verify USB 2.0 cable is **shielded** and < 2m length
- [ ] Install M2 nylon standoffs on all 4 corners (HackRF ↔ Power board, Power ↔ ESP32)
- [ ] Solder I2C pullup resistors (R1/R2 = 4.7kΩ) on Power Distribution board
- [ ] Install ferrite toroid on HackRF USB power line
- [ ] Connect INA219 I2C to ESP32-S3 GPIO 5 (SDA) / GPIO 6 (SCL)
- [ ] Test SPI continuity with multimeter (GPIO 8–11 to FT232H adapter)
- [ ] Verify antenna SMA connection is hand-tight + lock washer (no overtorque)
- [ ] Measure DC voltage at each rail: 12V ±5%, 5V ±5%, 3.3V ±3%
- [ ] Run thermal test: 20 min continuous Rx at max gain, monitor INA219 current
- [ ] Confirm activation token gates HackRF control (test unauthorized access rejection)

## Revision History

| Date | Version | Change |
|---|---|---|
| 2026-07-06 | 1.0 | Initial ESP32-S3 + HackRF One integration spec |
