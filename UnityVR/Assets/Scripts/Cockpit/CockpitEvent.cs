using UnityEngine;

namespace DeaconsPath.VR.Cockpit
{
    /// <summary>
    /// Category of a cockpit interaction. Every physical control emits one or
    /// more of these through <see cref="CockpitEventBus"/>, so HUDs, audio,
    /// haptics and mission scripting never need a direct reference to a
    /// specific lever or button.
    /// </summary>
    public enum CockpitEventType
    {
        None = 0,
        HoverEnter,
        HoverExit,
        GrabBegin,
        GrabEnd,
        Pressed,
        Released,
        Toggled,
        LeverMoved,
        DialTurned,
    }

    /// <summary>
    /// A single immutable cockpit fact. Deliberately a value type with no
    /// managed collections, so raising an event is allocation-free.
    /// </summary>
    public struct CockpitEvent
    {
        public CockpitEventType type;
        public ICockpitControl control;
        public string controlId;

        /// <summary>Analog magnitude; its meaning depends on <see cref="type"/>.</summary>
        public float value;

        /// <summary>Discrete state; meaningful for buttons and toggles.</summary>
        public bool state;

        public Vector3 worldPosition;
        public float timeSeconds;
    }

    /// <summary>
    /// Minimal pub/sub hub. Multiple subscribers are supported; dispatch is a
    /// single multicast delegate invocation with no per-event allocation.
    /// Subscribers are never required for the game to function.
    /// </summary>
    public sealed class CockpitEventBus
    {
        public delegate void Handler(CockpitEvent e);

        private Handler _any;

        public void Subscribe(Handler handler)
        {
            if (handler != null)
            {
                _any += handler;
            }
        }

        public void Unsubscribe(Handler handler)
        {
            if (handler != null)
            {
                _any -= handler;
            }
        }

        public void Raise(CockpitEvent e)
        {
            _any?.Invoke(e);
        }
    }
}
