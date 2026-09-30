# Bill of Materials: Sensor & Component Integration

> **⚠️ STALE GPIO NUMBERS (blind spot #83) — pending rewrite.** This
> document's I2C sensor-bus pins (`GPIO 5/6`, below and in the GPIO
> Mapping table) predate the ESP32-S3 → nanoESP32-C6 migration and the
> Phase 2 bus decision. The current, actually-implemented I2C bus is
> **GPIO18 (SDA) / GPIO19 (SCL) at 400kHz**, per `NANOESP32C6_QSPI_PINOUT.md`
> and `src/sensor_bus.py` (`I2C_BUS_CLOCK_HZ`, `DEVICE_ADDRESSES`). The
> device list and I2C addresses in this file (INA219 0x40, MS5837 0x76,
> VL53L0X 0x29, BNO055 0x28) remain accurate — only the GPIO pin numbers
> are wrong. Same stale-content situation as `HARDWARE_INTEGRATION.md`.

## Missing Components Identified in ENGINEERING_REVIEW

The following components are referenced in Domain VI (Power/Sensors) but not yet inventoried in the project:

### 1. Current Shunt & Power Monitor (Domain VI, Function #61–62)

#### Primary: INA219 (Adafruit IIC/I2C Current Sensor)
- **Purpose**: Monitor HackRF + ESP32-S3 current draw in real-time
- **Interface**: I2C (GPIO 5/6 on ESP32-S3)
- **Specs**:
  - Voltage range: 0–26V DC
  - Current range: ±3.2A (0.1Ω shunt, ≤320mV drop)
  - Resolution: 10 µV / 400 µA (programmable)
  - I2C address: 0x40 (default), 0x41–0x44 (alt)
  - Supply current: 500 µA typical
  - Package: SOT-23 (IC), or breakout board (27mm × 12mm)
- **Alert Thresholds**:
  - Idle (standby): ≤20 mA
  - RX baseline: 250–300 mA
  - RX max (LNA+VGA): 450–500 mA
  - TX active: 700–900 mA
  - THERMAL_THROTTLE: >1000 mA
- **Application in Code**:
  ```python
  from src.power.ina219_monitor import PowerMonitor
  pmon = PowerMonitor(i2c_bus=1)
  current_mA = pmon.current_ma()
  voltage_V = pmon.voltage_v()
  power_mW = pmon.power_mw()
  ```
- **Cost**: $6–10 USD (breakout board)
- **PCB Footprint**: 0.1" × 0.9" (DIP-style breakout)
- **Supplier**: Adafruit, SparkFun, Mouser, DigiKey

#### Alternative: INA226 (Higher Resolution)
- **Advantages**: 16-bit ADC, lower shunt voltage (20 mV typical), programmable averaging
- **Interface**: I2C (address 0x40–0x4F)
- **Package**: VSON-10
- **When to use**: If current resolution better than 400 µA needed

---

### 2. Thermal Monitoring: NTC Thermistor (Domain VI, Function #63)

#### Thermistor: 10kΩ NTC (Negative Temperature Coefficient)
- **Purpose**: Monitor SDR (HackRF FPGA) junction temperature to trigger VGA/TX throttle
- **Specs**:
  - Resistance @ 25°C: 10 kΩ ±5%
  - B-value (β₂₅/₁₀₀): 3435–3500 K
  - Temperature range: −40°C to +125°C
  - Package: 1206 SMD or radial lead (thin-film)
  - Time constant: ~5–10 sec (depends on thermal contact)
- **Placement**: Mounted on aluminum backing plate directly under HackRF FPGA (via thermal epoxy or spring clip)
- **ADC Integration**: GPIO 4 (ADC1_CH3 on ESP32-S3)
  - Voltage divider: 10kΩ NTC + 10kΩ pullup to 3.3V
  - Input voltage: 0–3.3V (12-bit resolution = 1.6 mV per step)
- **Calibration**:
  ```
  Temperature (°C) = 1 / (A + B·ln(R) + C·ln³(R)) − 273.15
  where A=1.009×10⁻³, B=2.378×10⁻⁴, C=2.019×10⁻⁷
  R = measured resistance (Ohms)
  ```
- **Cost**: $0.20–0.50 USD
- **Suppliers**: Mouser, DigiKey, TME
- **Example**: Murata NCP18WF104F03RC (10kΩ NTC, β=3380K)

---

### 3. Depth Sensor: MS5837 (Domain VI, Function #64)

#### Barometric/Pressure Sensor: MS5837-30BA (TE Connectivity)
- **Purpose**: Depth measurement for underwater / marine telemetry scenarios
- **Specs**:
  - Pressure range: 0–300 mbar (0–3000 m depth, seawater)
  - I2C address: 0x76 or 0x77 (selectable via CSB pin)
  - Resolution: 0.2 mbar (≈2 cm water depth)
  - Operating temperature: −40°C to +85°C
  - Supply voltage: 1.5–3.6V (1.8V nominal, 5V-tolerant I2C)
  - Current: 1 µA (standby), 250 µA (active measurement)
  - Accuracy: ±10 mbar typical
  - Package: DFN-8 (3mm × 5mm) or breakout board
- **Depth Calculation**:
  ```python
  # Seawater density ρ ≈ 1025 kg/m³, g ≈ 9.81 m/s²
  # P_absolute (mbar) = (pressure_sensor_reading) + 1013.25 mbar (atm)
  depth_m = (P_absolute - 1013.25) * 100 / (1025 * 9.81)
  ```
- **Application in Code**:
  ```python
  from src.sensors.ms5837 import DepthSensor
  depth = DepthSensor(i2c_bus=1)
  depth_meters = depth.calculate_depth()
  raw_pressure = depth.pressure()  # mbar
  ```
- **Cost**: $15–25 USD (breakout board)
- **Suppliers**: SparkFun (MS5837-30BA breakout), Adafruit, Mouser
- **Note**: Requires accurate pressure calibration at sea level before dive

---

### 4. Range Finder: VL53L0X (Domain VI, Function #65)

#### Time-of-Flight Distance Sensor: VL53L0X (STMicroelectronics)
- **Purpose**: Measure distance to nearby objects (walls, antennas, RF hazards within 1m)
- **Specs**:
  - Measuring range: 30 mm to 1200 mm (≤1m typical, outdoors ≤100mm)
  - Accuracy: ±3% of distance (worst-case)
  - Optical field-of-view: ~27° diagonal (cone)
  - I2C interface: 400 kHz (standard), 1 MHz (fast)
  - I2C address: 0x29 (default, changeable via software)
  - Operating voltage: 2.6–3.5V (3.3V typical)
  - Operating temperature: −40°C to +70°C
  - Current: 10 mA (active), <1 mA (standby)
  - Package: LGA-12 (4.4mm × 2.4mm) or breakout board
  - Measurement time: 30 ms (single shot)
- **Hazard Detection Use Case**:
  - If distance < 50 cm to antenna: reduce TX power or inhibit TX
  - Alert operator of RF exposure risk
  - Log proximity events for safety audit
- **Application in Code**:
  ```python
  from src.sensors.vl53l0x import RangeSensor
  range_sensor = RangeSensor(i2c_bus=1)
  distance_mm = range_sensor.range()
  if distance_mm < 500:  # < 50 cm
      HackRF_TxEnable(False)
      log_event("PROXIMITY_ALERT", distance_mm)
  ```
- **Cost**: $8–12 USD (breakout board)
- **Suppliers**: Adafruit, SparkFun, Mouser
- **Limitations**:
  - Sensitive to bright ambient light (outdoor use limited)
  - Non-reflective objects measured at shorter range
  - I2C latency ~30 ms per measurement (not real-time)

---

### 5. Inertial Measurement Unit: MPU6050 or BNO055 (Domain VI, Function #66–67)

#### Option A: MPU6050 (TDK InvenSense) — Budget
- **Purpose**: 6-axis motion sensing (accelerometer + gyroscope)
- **Specs**:
  - Accelerometer: ±2g, ±4g, ±8g, ±16g (selectable)
  - Gyroscope: ±250, ±500, ±1000, ±2000 °/s (selectable)
  - I2C address: 0x68 or 0x69 (AD0 pin selectable)
  - Operating voltage: 3.0–3.5V
  - Supply current: 3.9 mA (active), 50 µA (sleep)
  - Package: QFN-24 (4mm × 4mm) or breakout board
  - Temperature: −40°C to +85°C
  - Output rate: 1 kHz (configurable)
  - 16-bit ADC resolution
- **Cost**: $3–6 USD (breakout board)
- **Suppliers**: Amazon, AliExpress, Mouser
- **Application**: Detect rapid movement (possible physical interference with antenna), 6-axis gesture recognition

#### Option B: BNO055 (Bosch Sensortec) — Premium
- **Purpose**: 9-axis IMU with on-chip Kalman filtering (accelerometer + gyroscope + magnetometer + fusion engine)
- **Specs**:
  - Accelerometer + Gyroscope + Magnetometer (compass)
  - Quaternion fusion: automatically corrected orientation
  - I2C/UART interface (selectable)
  - I2C address: 0x28 or 0x29
  - Operating voltage: 3.3–5V
  - Supply current: 12 mA (active), 1 mA (sleep)
  - Package: LGA-28 (4.4mm × 4.4mm) or breakout
  - Calibration: auto-calibration in software
- **Cost**: $25–35 USD (breakout board, mature market)
- **Suppliers**: Adafruit (most common), SparkFun, Mouser
- **Advantages over MPU6050**:
  - Built-in magnetometer (heading awareness)
  - Internal sensor fusion (Kalman + Madgwick)
  - No manual orientation math needed
  - Better temperature stability

**Recommendation**: Use **BNO055** for production (better thermal compensation, on-board fusion), **MPU6050** for prototyping (cost).

---

## Assembly Checklist: Adding Sensors to Power Board

```
┌──────────────────────────────────┐
│ Power Distribution Board (Level 2) │
├──────────────────────────────────┤
│ [INA219 I2C]                     │ ← Current shunt (5-pin breakout)
│                                  │
│ [NTC Thermistor] (SMD 1206)      │ ← Mounted on HackRF backing plate
│ │                                │   via 2-pin JST connector
│ [10kΩ divider resistor]          │
│                                  │
│ [MS5837 I2C] (optional)          │ ← Depth sensor (4-pin breakout)
│ [VL53L0X I2C] (optional)         │ ← Range sensor (4-pin breakout)
│ [BNO055 I2C] (optional)          │ ← 9-axis IMU (8-pin breakout)
│                                  │
│ I2C Bus Hub (optional):          │
│ - SDA pullup: 4.7kΩ              │
│ - SCL pullup: 4.7kΩ              │
│ - All sensors share GPIO 5/6     │
└──────────────────────────────────┘
```

---

## GPIO Mapping (Updated)

| ESP32-S3 Pin | Function | Sensor | Protocol | Addr |
|---|---|---|---|---|
| GPIO 1 | TX | UART Activation | UART | — |
| GPIO 2 | RX | UART Activation | UART | — |
| GPIO 4 | ADC1_CH3 | NTC Thermistor | Analog (ADC) | — |
| GPIO 5 | SDA | INA219, MS5837, VL53L0X, BNO055 | I2C | 0x40, 0x76, 0x29, 0x28 |
| GPIO 6 | SCL | INA219, MS5837, VL53L0X, BNO055 | I2C | (shared bus) |
| GPIO 8 | CS_N | HackRF | SPI | — |
| GPIO 9 | MOSI | HackRF | SPI | — |
| GPIO 10 | MISO | HackRF | SPI | — |
| GPIO 11 | CLK | HackRF | SPI | — |

---

## Thermal Budget (with Sensors)

| Sensor | Quiescent (µA) | Active (mA) | Duty Cycle | Contribution |
|---|---|---|---|---|
| INA219 | 0.5 | 0.5 | 100% | +0.5 mA |
| NTC Thermistor + ADC | — | 1.0 | Periodic | +0.3 mA (avg) |
| MS5837 | 1 | 5 | ≤1 Hz | +0.005 mA (avg) |
| VL53L0X | 5 | 10 | ≤1 Hz | +0.01 mA (avg) |
| BNO055 | 1000 | 12 | Cont. | +12 mA |
| **Total (all sensors)** | — | — | — | **+13 mA** |

---

## Software Integration

### Power Monitoring Module
```python
# src/power/ina219_monitor.py
from src.power.ina219_monitor import PowerMonitor

pmon = PowerMonitor(i2c_bus=1, address=0x40)
pmon.alert_callback(callback_fn)  # Trigger on >1000mA

while True:
    current = pmon.current_ma()
    voltage = pmon.voltage_v()
    power = pmon.power_mw()
    
    if current > THERMAL_LIMIT:
        HackRF_ThrottleVGA()
        log_event("THERMAL_THROTTLE", current)
```

### Thermal Monitoring Module
```python
# src/sensors/thermistor_monitor.py
from src.sensors.thermistor_monitor import ThermistorMonitor

therm = ThermistorMonitor(adc_pin=4)
temp_c = therm.temperature()

if temp_c > 60:  # FPGA junction temp
    HackRF_TxEnable(False)
    log_event("THERMAL_SHUTDOWN", temp_c)
```

### Depth / Range / IMU Modules (stub integration points)
```python
from src.sensors.ms5837 import DepthSensor
from src.sensors.vl53l0x import RangeSensor
from src.sensors.bno055 import IMU

depth = DepthSensor(i2c_bus=1)
range_m = RangeSensor(i2c_bus=1)
imu = IMU(i2c_bus=1)

# In RF audit loop:
if range_m.distance_mm() < 500:
    log_event("PROXIMITY_HAZARD")
    
# Log orientation for multi-axis RF mapping
orientation = imu.euler_angles()
```

---

## Procurement Summary

| Component | Quantity | Unit Price | Total | Lead Time | Supplier |
|---|---|---|---|---|---|
| INA219 Breakout | 1 | $8 | $8 | 1–3 days | Adafruit |
| NTC 10kΩ (1206) | 2 | $0.30 | $0.60 | Same-day | Mouser |
| MS5837-30BA Breakout | 1 | $20 | $20 | 1 week | SparkFun |
| VL53L0X Breakout | 1 | $10 | $10 | 1–3 days | Adafruit |
| BNO055 Breakout | 1 | $30 | $30 | 3–5 days | Adafruit |
| Resistors (4.7kΩ, etc.) | 10 | $0.05 | $0.50 | Same-day | Mouser |
| JST PH Connectors (2-pin) | 5 | $0.20 | $1.00 | Same-day | Mouser |
| **TOTAL** | — | — | **$70.10** | **3–5 days** | — |

---

## References

- [INA219 Datasheet](https://learn.adafruit.com/adafruit-ina219-current-sensor-breakout)
- [MS5837 Datasheet](https://github.com/bluerobotics/MS5837-Python)
- [VL53L0X Datasheet](https://learn.adafruit.com/adafruit-vl53l0x-micro-lidar-distance-sensor-breakout)
- [BNO055 Datasheet](https://learn.adafruit.com/adafruit-bno055-absolute-orientation-sensor)
- [MPU6050 Datasheet](https://www.invensense.com/wp-content/uploads/2015/02/MPU-6000-Datasheet1.pdf)

---

| Date | Version | Updated |
|---|---|---|
| 2026-07-06 | 1.0 | Initial BOM with 5 sensor families |
