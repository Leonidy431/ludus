using System;
using UnityEngine;
using DeaconsPath.VR.Physics;

namespace DeaconsPath.VR.Cockpit
{
    /// <summary>Channels the cockpit can drive on the vehicle command.</summary>
    public enum CockpitAxis
    {
        None = 0,
        ThrustForward,
        ThrustLateral,
        ThrustVertical,
        Yaw,
        Pitch,
        Roll,
        Ballast,
    }

    [Serializable]
    public struct CockpitAxisBinding
    {
        [Tooltip("ControlId of a CockpitLever or CockpitDial.")]
        public string controlId;

        public CockpitAxis axis;

        [Tooltip("Multiplier applied to the control's normalised value.")]
        public float scale;

        [Tooltip("Bias added after scaling, e.g. +1 to map a [-1..1] lever into 0..1 ballast.")]
        public float bias;
    }

    [Serializable]
    public struct CockpitToggleBinding
    {
        [Tooltip("ControlId of a CockpitToggle.")]
        public string controlId;

        public CockpitAxis axis;

        [Tooltip("Value written when the toggle is ON.")]
        public float onValue;
    }

    /// <summary>
    /// Phase 3 → Phase 2 bridge. Aggregates analog control values (levers and
    /// dials) and latching toggle states into a <see cref="VehicleCommand"/>.
    /// Momentary buttons are deliberately NOT routed here; they emit
    /// <see cref="CockpitEventType.Pressed"/> / <see cref="CockpitEventType.Released"/>
    /// for HUD, audio and mission scripting.
    ///
    /// This is the only file that references both the Cockpit and Physics
    /// namespaces, so <see cref="CockpitControl"/> and the solver stay
    /// unaware of each other. Control-to-thrust mapping lives in serialized
    /// data, not in code.
    /// </summary>
    [DefaultExecutionOrder(-70)]
    public sealed class CockpitCommandSource : MonoBehaviour, IVehicleCommandSource
    {
        [Header("Analog bindings (levers / dials)")]
        [SerializeField] private CockpitAxisBinding[] axisBindings = new CockpitAxisBinding[0];

        [Header("Latching toggle bindings")]
        [SerializeField] private CockpitToggleBinding[] toggleBindings = new CockpitToggleBinding[0];

        private CockpitManager _manager;

        private void Awake()
        {
            _manager = CockpitManager.Instance;
            if (_manager == null)
            {
                _manager = FindObjectOfType<CockpitManager>();
            }
        }

        public VehicleCommand ReadCommand(float deltaTime)
        {
            VehicleCommand cmd = VehicleCommand.Zero;
            if (_manager == null)
                return cmd;

            ApplyAxisBindings(ref cmd);
            ApplyToggleBindings(ref cmd);
            return cmd.Clamped();
        }

        private void ApplyAxisBindings(ref VehicleCommand cmd)
        {
            int n = axisBindings?.Length ?? 0;
            for (int i = 0; i < n; i++)
            {
                CockpitAxisBinding binding = axisBindings[i];
                if (string.IsNullOrEmpty(binding.controlId) || binding.axis == CockpitAxis.None)
                    continue;

                float value = LookupAnalog(binding.controlId);
                if (float.IsNaN(value))
                    continue;

                WriteAxis(ref cmd, binding.axis, value * binding.scale + binding.bias);
            }
        }

        private void ApplyToggleBindings(ref VehicleCommand cmd)
        {
            int n = toggleBindings?.Length ?? 0;
            for (int i = 0; i < n; i++)
            {
                CockpitToggleBinding binding = toggleBindings[i];
                if (string.IsNullOrEmpty(binding.controlId) || binding.axis == CockpitAxis.None)
                    continue;

                ICockpitControl control = _manager.Find(binding.controlId);
                if (!(control is CockpitToggle toggle) || !toggle.IsOn)
                    continue;

                WriteAxis(ref cmd, binding.axis, binding.onValue);
            }
        }

        private float LookupAnalog(string controlId)
        {
            ICockpitControl control = _manager.Find(controlId);
            switch (control)
            {
                case CockpitLever lever:
                    return lever.NormalizedValue;
                case CockpitDial dial:
                    return dial.NormalizedValue;
                default:
                    return float.NaN;
            }
        }

        private static void WriteAxis(ref VehicleCommand cmd, CockpitAxis axis, float value)
        {
            switch (axis)
            {
                case CockpitAxis.ThrustForward:
                    cmd.thrustForward = value;
                    break;
                case CockpitAxis.ThrustLateral:
                    cmd.thrustLateral = value;
                    break;
                case CockpitAxis.ThrustVertical:
                    cmd.thrustVertical = value;
                    break;
                case CockpitAxis.Yaw:
                    cmd.yawRate = value;
                    break;
                case CockpitAxis.Pitch:
                    cmd.pitchRate = value;
                    break;
                case CockpitAxis.Roll:
                    cmd.rollRate = value;
                    break;
                case CockpitAxis.Ballast:
                    cmd.ballastCommand = value;
                    break;
            }
        }
    }
}
