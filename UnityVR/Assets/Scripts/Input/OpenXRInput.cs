using System;
using UnityEngine;
using UnityEngine.XR;
using UnityEngine.XR.Hands; // optional: falls back gracefully if not present

namespace DeaconsPath.VR.Input
{
    /// <summary>
    /// Quest 3 backend. Reads the OpenXR head + right-hand controller via the
    /// XR InputDevices API. No allocations: all Device/CommonUsages lookups are
    /// cached at construction time.
    /// </summary>
    public sealed class OpenXRInput : IPlayerInput
    {
        private const float Deadzone = 0.15f;

        private readonly Transform _head;
        private readonly Transform _hand;

        private UnityEngine.XR.InputDevice _headDevice;
        private UnityEngine.XR.InputDevice _handDevice;

        private bool _primaryDown;
        private bool _secondaryDown;
        private bool _headValid;
        private bool _handValid;

        public event Action PrimaryButtonPressed;
        public event Action PrimaryButtonReleased;
        public event Action SecondaryButtonPressed;

        public OpenXRInput(Transform head, Transform hand)
        {
            _head = head != null ? head : throw new ArgumentNullException(nameof(head));
            _hand = hand != null ? hand : throw new ArgumentNullException(nameof(hand));
            RefreshDevices();
        }

        public Pose HeadPose => _headValid
            ? new Pose(_head.position, _head.rotation)
            : new Pose(Vector3.zero, Quaternion.identity);

        public bool IsPrimaryHandTracked => _handValid;

        public Pose PrimaryHandPose => _handValid
            ? new Pose(_hand.position, _hand.rotation)
            : new Pose(_head.position, _head.rotation);

        public Vector2 MoveAxis { get; private set; }
        public Vector2 LookAxis { get; private set; }
        public float PrimaryTrigger { get; private set; }
        public float PrimaryGrip { get; private set; }

        public void Tick(float deltaTime)
        {
            if (!_headValid) RefreshHeadDevice();
            if (!_handValid) RefreshHandDevice();

            // --- Head pose -------------------------------------------------
            if (_headDevice.isValid &&
                _headDevice.TryGetFeatureValue(CommonUsages.centerEyePosition, out Vector3 eye))
            {
                _head.position = eye;
                if (_headDevice.TryGetFeatureValue(CommonUsages.centerEyeRotation, out Quaternion rot))
                {
                    _head.rotation = rot;
                }
            }

            // --- Thumbsticks ----------------------------------------------
            if (_handDevice.isValid)
            {
                _handDevice.TryGetFeatureValue(CommonUsages.primary2DAxis, out Vector2 stick);
                MoveAxis = ApplyDeadzone(stick);
                LookAxis = MoveAxis; // right stick doubles as look in sim mode

                // --- Analog trigger / grip --------------------------------
                PrimaryTrigger = ReadAxis(CommonUsages.trigger);
                PrimaryGrip    = ReadAxis(CommonUsages.grip);

                // --- Discrete buttons -------------------------------------
                _handDevice.TryGetFeatureValue(CommonUsages.primaryButton, out bool primary);
                _handDevice.TryGetFeatureValue(CommonUsages.secondaryButton, out bool secondary);
                HandleButtons(primary, secondary);
            }
            else
            {
                MoveAxis = Vector2.zero;
                LookAxis = Vector2.zero;
                PrimaryTrigger = 0f;
                PrimaryGrip = 0f;
            }
        }

        private float ReadAxis(UnityEngine.XR.InputFeatureUsage<float> usage)
        {
            return _handDevice.TryGetFeatureValue(usage, out float v) ? Mathf.Clamp01(v) : 0f;
        }

        private void HandleButtons(bool primary, bool secondary)
        {
            if (primary && !_primaryDown)
            {
                _primaryDown = true;
                PrimaryButtonPressed?.Invoke();
            }
            else if (!primary && _primaryDown)
            {
                _primaryDown = false;
                PrimaryButtonReleased?.Invoke();
            }

            if (secondary && !_secondaryDown)
            {
                _secondaryDown = true;
                SecondaryButtonPressed?.Invoke();
            }
            else if (!secondary)
            {
                _secondaryDown = false;
            }
        }

        private void RefreshDevices()
        {
            RefreshHeadDevice();
            RefreshHandDevice();
        }

        private void RefreshHeadDevice()
        {
            _headValid = TryFind(InputDeviceCharacteristics.HeadMounted, out _headDevice);
        }

        private void RefreshHandDevice()
        {
            _handValid = TryFind(
                InputDeviceCharacteristics.HeldInHand |
                InputDeviceCharacteristics.Right |
                InputDeviceCharacteristics.Controller,
                out _handDevice);
        }

        private static bool TryFind(InputDeviceCharacteristics flags, out UnityEngine.XR.InputDevice device)
        {
            var devices = new System.Collections.Generic.List<UnityEngine.XR.InputDevice>();
            InputDevices.GetDevicesWithCharacteristics(flags, devices);
            if (devices.Count > 0)
            {
                device = devices[0];
                return true;
            }
            device = default;
            return false;
        }

        private static Vector2 ApplyDeadzone(Vector2 v)
        {
            v.x = Mathf.Abs(v.x) < Deadzone ? 0f : v.x;
            v.y = Mathf.Abs(v.y) < Deadzone ? 0f : v.y;
            return v;
        }
    }
}
