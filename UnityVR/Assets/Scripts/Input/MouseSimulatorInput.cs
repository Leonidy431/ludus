using System;
using UnityEngine;

namespace DeaconsPath.VR.Input
{
    /// <summary>
    /// Desktop/Editor fallback. Maps mouse + WASD to the same contract the
    /// OpenXR rig exposes, so gameplay code never branches on platform.
    /// Left mouse = trigger, right mouse = grip, Space = primary button.
    /// </summary>
    public sealed class MouseSimulatorInput : IPlayerInput
    {
        private const float Deadzone = 0.15f;

        private readonly Transform _head;
        private readonly Transform _hand;

        private float _yaw;
        private float _pitch;
        private bool _primaryDown;
        private bool _secondaryDown;

        public event Action PrimaryButtonPressed;
        public event Action PrimaryButtonReleased;
        public event Action SecondaryButtonPressed;

        public MouseSimulatorInput(Transform head, Transform hand)
        {
            _head  = head  != null ? head  : throw new ArgumentNullException(nameof(head));
            _hand  = hand  != null ? hand  : throw new ArgumentNullException(nameof(hand));
            _yaw   = head.eulerAngles.y;
        }

        public Pose HeadPose => new Pose(_head.position, _head.rotation);

        public bool IsPrimaryHandTracked => true;

        public Pose PrimaryHandPose => new Pose(_hand.position, _hand.rotation);

        public Vector2 MoveAxis { get; private set; }
        public Vector2 LookAxis { get; private set; }
        public float PrimaryTrigger { get; private set; }
        public float PrimaryGrip { get; private set; }

        public void Tick(float deltaTime)
        {
            // --- Look (mouse look, free cursor) --------------------------
            _yaw   += UnityEngine.Input.GetAxisRaw("Mouse X") * 2f;
            _pitch  = Mathf.Clamp(
                _pitch - UnityEngine.Input.GetAxisRaw("Mouse Y") * 2f, -85f, 85f);
            _head.rotation = Quaternion.Euler(_pitch, _yaw, 0f);

            LookAxis = new Vector2(
                ApplyDeadzone(UnityEngine.Input.GetAxisRaw("Mouse X")),
                ApplyDeadzone(UnityEngine.Input.GetAxisRaw("Mouse Y")));

            // --- Move (WASD) ---------------------------------------------
            MoveAxis = new Vector2(
                ApplyDeadzone(UnityEngine.Input.GetAxisRaw("Horizontal")),
                ApplyDeadzone(UnityEngine.Input.GetAxisRaw("Vertical")));

            // --- Analog mimics -------------------------------------------
            PrimaryTrigger = UnityEngine.Input.GetMouseButton(0) ? 1f : 0f;
            PrimaryGrip    = UnityEngine.Input.GetMouseButton(1) ? 1f : 0f;

            // --- Discrete buttons ----------------------------------------
            if (UnityEngine.Input.GetKeyDown(KeyCode.Space) && !_primaryDown)
            {
                _primaryDown = true;
                PrimaryButtonPressed?.Invoke();
            }
            else if (UnityEngine.Input.GetKeyUp(KeyCode.Space) && _primaryDown)
            {
                _primaryDown = false;
                PrimaryButtonReleased?.Invoke();
            }

            if (UnityEngine.Input.GetKeyDown(KeyCode.Tab) && !_secondaryDown)
            {
                _secondaryDown = true;
                SecondaryButtonPressed?.Invoke();
            }
            else if (UnityEngine.Input.GetKeyUp(KeyCode.Tab))
            {
                _secondaryDown = false;
            }
        }

        private static float ApplyDeadzone(float v)
            => Mathf.Abs(v) < Deadzone ? 0f : v;
    }
}
