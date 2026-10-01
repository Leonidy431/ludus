// hydrophone_v1.ino — "Model 1" hydrophone firmware (ESP32)
//
// Scope, stated honestly (full rationale: hardware/HYDROPHONE_V1.md):
// samples the preamp output at ~40 kHz (Nyquist ~20 kHz), which covers
// dolphin WHISTLE-band content, not the full echolocation-click
// bandwidth (up to ~150 kHz) -- that needs a faster external ADC, out of
// scope for this simple working model. This is a level/threshold
// monitor, not a calibrated instrument and not a species classifier.
//
// Hardware: preamp output -> GPIO34 (ADC1_CH6, input-only, WiFi-safe).
// See hardware/HYDROPHONE_V1.md for the full preamp circuit.

#include <Arduino.h>

// ---------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------
static const int ADC_PIN = 34;              // ADC1_CH6, input-only, safe alongside WiFi
static const uint32_t SAMPLE_RATE_HZ = 40000;
static const uint32_t SAMPLE_PERIOD_US = 1000000UL / SAMPLE_RATE_HZ;

// Threshold-crossing "possible whistle" flag -- a coarse level monitor,
// not a real detector. Tune ADC_THRESHOLD on the bench against the
// specific piezo/preamp gain actually built (see HYDROPHONE_V1.md's
// note that gain resistor values are placeholders pending real
// measurement -- this threshold is the same kind of placeholder).
static const int ADC_THRESHOLD = 2200;       // out of the ESP32's 12-bit 0-4095 range
static const uint32_t EVENT_HOLDOFF_MS = 200; // debounce: one event report per holdoff window

// Rolling stats reported once per REPORT_INTERVAL_MS over Serial.
static const uint32_t REPORT_INTERVAL_MS = 500;

// ---------------------------------------------------------------------
// State
// ---------------------------------------------------------------------
static hw_timer_t *sampleTimer = nullptr;
static volatile bool sampleReady = false;

static int peakSinceReport = 0;
static int troughSinceReport = 4095;
static uint32_t sampleCountSinceReport = 0;
static uint32_t lastReportMs = 0;
static uint32_t lastEventMs = 0;

// ---------------------------------------------------------------------
// Timer ISR: just flags that a sample is due. All real work (the ADC
// read itself, and any Serial I/O) happens in loop() -- keeping the ISR
// minimal avoids the classic "blocking work inside an ISR" mistake that
// would desync the sample timing it's meant to guarantee.
// ---------------------------------------------------------------------
void IRAM_ATTR onSampleTimer() {
    sampleReady = true;
}

void setup() {
    Serial.begin(115200);
    analogReadResolution(12);       // ESP32 ADC: 0-4095
    analogSetPinAttenuation(ADC_PIN, ADC_11db);  // full ~0-3.3V input range

    sampleTimer = timerBegin(0, 80, true);       // 80MHz / 80 = 1MHz timer tick
    timerAttachInterrupt(sampleTimer, &onSampleTimer, true);
    timerAlarmWrite(sampleTimer, SAMPLE_PERIOD_US, true);
    timerAlarmEnable(sampleTimer);

    lastReportMs = millis();

    Serial.println("hydrophone_v1: model 1 -- whistle-band level monitor");
    Serial.printf(
        "sample_rate_hz=%lu threshold=%d (placeholder, tune on bench)\n",
        (unsigned long)SAMPLE_RATE_HZ, ADC_THRESHOLD
    );
}

void loop() {
    if (!sampleReady) {
        return;
    }
    sampleReady = false;

    int sample = analogRead(ADC_PIN);
    sampleCountSinceReport++;

    if (sample > peakSinceReport) {
        peakSinceReport = sample;
    }
    if (sample < troughSinceReport) {
        troughSinceReport = sample;
    }

    uint32_t now = millis();

    if (sample > ADC_THRESHOLD && (now - lastEventMs) >= EVENT_HOLDOFF_MS) {
        lastEventMs = now;
        Serial.printf("EVENT possible_whistle adc=%d t_ms=%lu\n", sample, (unsigned long)now);
    }

    if ((now - lastReportMs) >= REPORT_INTERVAL_MS) {
        Serial.printf(
            "LEVEL peak=%d trough=%d p2p=%d samples=%lu\n",
            peakSinceReport, troughSinceReport,
            peakSinceReport - troughSinceReport,
            (unsigned long)sampleCountSinceReport
        );
        peakSinceReport = 0;
        troughSinceReport = 4095;
        sampleCountSinceReport = 0;
        lastReportMs = now;
    }
}
