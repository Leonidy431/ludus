using System;
using UnityEngine;

namespace DeaconsPath.VR.Input
{
    /// <summary>
    /// Hardware-agnostic input contract. All gameplay systems (physics thruster
    /// commands, cockpit levers, tooltips) depend on this interface only.
    /// Implementations: <see cref="MouseSimulatorInput"/> (Editor) and
    /// <see cref="OpenXRInput"/> (Quest 3 device).
    /// </summary>
    public interface IPlayerInput
    {
        // ---- Head / pose -------------------------------------------------
        /// <summary>World-space head pose. In editor this is the camera rig.</summary>
        Pose HeadPose { get; }

        // ---- Hands / controllers ----------------------------------------
        /// <summary>True while the primary hand controller is tracked.</summary>
        bool IsPrimaryHandTracked { get; }

        /// <summary>World-space grip pose of the primary hand.</summary>
        Pose PrimaryHandPose { get; }

        // ---- Continuous axes (normalized -1..1 or 0..1) ------------------
        /// <summary>Left stick X/Y, already deadzoned and clamped.</summary>
        Vector2 MoveAxis { get; }

        /// <summary>Right stick X/Y, already deadzoned and clamped.</summary>
        Vector2 LookAxis { get; }

        // ---- Analog triggers / grips (0..1) ------------------------------
        /// <summary>Primary hand trigger, 0.0 (released) .. 1.0 (fully squeezed).</summary>
        float PrimaryTrigger { get; }

        /// <summary>Primary hand grip, 0.0 .. 1.0.</summary>
        float PrimaryGrip { get; }

        // ---- Discrete events --------------------------------------------
        /// <summary>Fired once on the frame the primary action button goes down.</summary>
        event Action PrimaryButtonPressed;

        /// <summary>Fired once on the frame the primary action button goes up.</summary>
        event Action PrimaryButtonReleased;

        /// <summary>Fired once on the frame the secondary (menu) button goes down.</summary>
        event Action SecondaryButtonPressed;

        /// <summary>
        /// Called once per frame by <see cref="InputProvider"/>. Implementations
        /// must not allocate here; cache all values into backing fields.
        /// </summary>
        void Tick(float deltaTime);
    }
}
