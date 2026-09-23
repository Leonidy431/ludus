using UnityEngine;
using DeaconsPath.VR.Input;

namespace DeaconsPath.VR.Cockpit
{
    /// <summary>
    /// Per-frame snapshot of "what the hand is doing right now". Passed by
    /// readonly reference to control callbacks so no allocation occurs and
    /// controls never touch the raw <see cref="IPlayerInput"/> API.
    /// </summary>
    public struct CockpitInteractionContext
    {
        public IPlayerInput input;

        /// <summary>Hand (or cursor) world position at the moment of the tick.</summary>
        public Vector3 handPosition;

        /// <summary>World ray used for hover picking.</summary>
        public Vector3 rayOrigin;
        public Vector3 rayDirection;

        /// <summary>World point where the ray struck the control's collider.</summary>
        public Vector3 hitPoint;

        public float deltaTime;
    }

    /// <summary>
    /// Anything in the cockpit that a hand can hover, grab, or press.
    /// Implementations must never query the input layer themselves; the
    /// <see cref="CockpitInteractor"/> is the sole bridge to Phase 1.
    /// </summary>
    public interface ICockpitControl
    {
        string ControlId { get; }
        Transform ControlTransform { get; }
        bool IsEnabled { get; }

        void HoverEnter(in CockpitInteractionContext ctx);
        void HoverExit(in CockpitInteractionContext ctx);

        void GrabBegin(in CockpitInteractionContext ctx);
        void GrabTick(in CockpitInteractionContext ctx);
        void GrabEnd(in CockpitInteractionContext ctx);

        void ButtonDown(in CockpitInteractionContext ctx);
        void ButtonUp(in CockpitInteractionContext ctx);
    }
}
