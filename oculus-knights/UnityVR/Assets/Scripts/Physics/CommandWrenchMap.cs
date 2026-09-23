using System;
using UnityEngine;

namespace DeaconsPath.VR.Physics
{
    /// <summary>
    /// Data-driven mapping from a <see cref="VehicleCommand"/> to a desired
    /// local-frame wrench (force + torque). This is what
    /// <see cref="ThrusterAllocator"/> consumes — the allocator itself knows
    /// nothing about pilot channels.
    ///
    /// Sign convention matches the shipped Phase 2 mixer in
    /// <see cref="SixDofBody"/> exactly so the allocator can be swapped in
    /// without retuning:
    ///   linear = ( +Strafe, -Heave, +Throttle )
    ///   angular = ( +Roll,  +Yaw,  -Pitch )
    /// All maxima are the values reached at |command| = 1 on that channel.
    /// </summary>
    [Serializable]
    public struct CommandWrenchMap
    {
        [Header("Linear (newtons)")]
        [Tooltip("Force along local +Z at Throttle = +1.")]
        public float maxForwardForce;

        [Tooltip("Force along local -Z at Throttle = -1. Author weaker for a single shaft.")]
        public float maxReverseForce;

        [Tooltip("Force along local +X at Strafe = +1.")]
        public float maxStrafeForce;

        [Tooltip("Force along local -Y (down) at Heave = +1 (dive).")]
        public float maxHeaveForce;

        [Header("Angular (newton-metres)")]
        [Tooltip("Torque about local +X at Roll = +1.")]
        public float maxRollTorque;

        [Tooltip("Torque about local +Y at Yaw = +1.")]
        public float maxYawTorque;

        [Tooltip("Torque about local -Z at Pitch = +1 (nose-up).")]
        public float maxPitchTorque;

        /// <summary>
        /// Translates a pilot command into the wrench the allocator should
        /// attempt to achieve. Allocation-free.
        /// </summary>
        public void Map(in VehicleCommand cmd, out Vector3 force, out Vector3 torque)
        {
            float longitudinal = cmd.Throttle >= 0f
                ? cmd.Throttle * maxForwardForce
                : cmd.Throttle * maxReverseForce;

            force = new Vector3(
                 cmd.Strafe   * maxStrafeForce,
                -cmd.Heave    * maxHeaveForce,
                 longitudinal);

            torque = new Vector3(
                 cmd.Roll  * maxRollTorque,
                 cmd.Yaw   * maxYawTorque,
                -cmd.Pitch * maxPitchTorque);
        }

        /// <summary>
        /// Sensible starting values for the default seven-nozzle "six-pack"
        /// produced by <see cref="SixDofBody.CreateDefaultThrusters"/>.
        /// </summary>
        public static CommandWrenchMap Default => new CommandWrenchMap
        {
            maxForwardForce = 3200f,
            maxReverseForce = 1600f,
            maxStrafeForce  = 1800f,
            maxHeaveForce   = 2400f,
            maxRollTorque   = 1200f,
            maxYawTorque    =  900f,
            maxPitchTorque  = 1400f,
        };
    }
}
