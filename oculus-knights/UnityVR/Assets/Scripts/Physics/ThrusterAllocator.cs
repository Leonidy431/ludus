using UnityEngine;

namespace DeaconsPath.VR.Physics
{
    /// <summary>
    /// Weighted pseudo-inverse control allocator with iterative saturation
    /// redistribution. Given a desired wrench (local-frame force + torque),
    /// it distributes effort across N thruster nozzles and honours each
    /// nozzle's [-1, 1] authority limit.
    ///
    /// This is the over-actuated complement to the direct mixer in
    /// <see cref="SixDofBody"/>: when N &gt; 6 the naive per-axis weight table
    /// cannot resolve conflicts, so some thrusters fight each other and total
    /// authority silently degrades. The allocator instead solves
    ///
    ///     u = argmin  || B u - w ||^2 + λ || u ||^2
    ///
    /// (the ridge-regularised least-squares pseudo-inverse), then clips the
    /// worst violator and re-solves against the residual wrench. This is the
    /// classic active-set allocator; it terminates in at most N passes.
    ///
    /// Every scratch buffer is pre-allocated in the constructor; the hot path
    /// is allocation-free and safe to call from FixedUpdate on the
    /// Snapdragon XR2. The allocator is a pure numeric utility: it never
    /// references a Rigidbody, Transform or MonoBehaviour, so it is fully
    /// unit-testable without a scene.
    /// </summary>
    public sealed class ThrusterAllocator
    {
        public const int MaxThrusters = 16;
        private const int Dofs = 6;
        private const float DefaultRegularization = 1e-4f;
        private const int MaxSaturationIterations = MaxThrusters;

        // B is (Dofs x N), stored row-major so a row walk is contiguous.
        //   row 0..2 = local force from a unit command (N)
        //   row 3..5 = local torque from a unit command (N*m)
        private readonly float[] _b = new float[Dofs * MaxThrusters];
        private readonly float[] _btb = new float[MaxThrusters * MaxThrusters];
        private readonly float[] _btw = new float[MaxThrusters];
        private readonly float[] _u = new float[MaxThrusters];
        private readonly float[] _y = new float[MaxThrusters];
        private readonly float[] _l = new float[MaxThrusters * MaxThrusters];
        private readonly float[] _w = new float[Dofs];
        private readonly float[] _w0 = new float[Dofs];
        private readonly bool[] _active = new bool[MaxThrusters];

        private int _n;

        // ---- Telemetry ---------------------------------------------------
        public int ThrusterCount => _n;
        public bool IsConfigured => _n > 0;

        /// <summary>True when the last Allocate() clipped at least one nozzle.</summary>
        public bool LastSolveSaturated { get; private set; }

        /// <summary>Number of saturation passes the last Allocate() required.</summary>
        public int LastSaturationPasses { get; private set; }

        /// <summary>Squared norm of the wrench left unachieved by the last solve.</summary>
        public float LastResidualSquared { get; private set; }

        /// <summary>
        /// Ridge term. Larger values bias toward minimum-effort distributions
        /// and tolerate near-singular geometry; smaller values track the
        /// requested wrench more exactly.
        /// </summary>
        public float Regularization { get; set; } = DefaultRegularization;

        /// <summary>
        /// Precomputes the (Dofs x N) influence matrix from the nozzle specs.
        /// After this call the allocator never allocates.
        /// </summary>
        public void Configure(ThrusterSpec[] thrusters)
        {
            if (thrusters == null || thrusters.Length == 0)
            {
                _n = 0;
                return;
            }

            int n = Mathf.Min(thrusters.Length, MaxThrusters);
            _n = n;

            for (int i = 0; i < n; i++)
            {
                ThrusterSpec t = thrusters[i];

                Vector3 dir = t.NormalizedDirection;
                Vector3 force = dir * Mathf.Max(0f, t.maxForceNewtons);
                Vector3 torque = Vector3.Cross(t.localPosition, force);

                _b[0 * n + i] = force.x;
                _b[1 * n + i] = force.y;
                _b[2 * n + i] = force.z;
                _b[3 * n + i] = torque.x;
                _b[4 * n + i] = torque.y;
                _b[5 * n + i] = torque.z;
            }
        }

        /// <summary>
        /// Allocates per-nozzle commands. Writes exactly <see cref="ThrusterCount"/>
        /// entries into <paramref name="output"/>; each entry is in [-1, 1].
        /// Returns true when the wrench was achieved without clipping any nozzle.
        /// </summary>
        public bool Allocate(in Vector3 desiredForce, in Vector3 desiredTorque, float[] output)
        {
            if (_n == 0 || output == null || output.Length < _n) return false;

            _w0[0] = desiredForce.x;
            _w0[1] = desiredForce.y;
            _w0[2] = desiredForce.z;
            _w0[3] = desiredTorque.x;
            _w0[4] = desiredTorque.y;
            _w0[5] = desiredTorque.z;

            for (int r = 0; r < Dofs; r++) _w[r] = _w0[r];

            for (int i = 0; i < _n; i++)
            {
                _active[i] = true;
                _u[i] = 0f;
            }

            LastSolveSaturated = false;
            LastSaturationPasses = 0;

            for (int iter = 0; iter <= MaxSaturationIterations; iter++)
            {
                if (!SolveActive()) return FailSolve(output);

                int violator = -1;
                float worstOver = 0f;
                for (int i = 0; i < _n; i++)
                {
                    if (!_active[i]) continue;

                    float over = Mathf.Abs(_u[i]) - 1f;
                    if (over > worstOver)
                    {
                        worstOver = over;
                        violator = i;
                    }
                }

                if (violator < 0)
                {
                    Commit(output);
                    ComputeResidual(output);
                    return !LastSolveSaturated;
                }

                float saturated = Mathf.Clamp(_u[violator], -1f, 1f);
                float delta = saturated - _u[violator];

                _u[violator] = saturated;
                _active[violator] = false;

                for (int r = 0; r < Dofs; r++)
                {
                    _w[r] -= _b[r * _n + violator] * delta;
                }

                LastSolveSaturated = true;
                LastSaturationPasses++;
            }

            Commit(output);
            ComputeResidual(output);
            return false;
        }

        // ------------------------------------------------------------------
        //  Internal helpers
        // ------------------------------------------------------------------

        private bool FailSolve(float[] output)
        {
            for (int i = 0; i < _n; i++) output[i] = 0f;
            LastResidualSquared = _w0[0] * _w0[0] + _w0[1] * _w0[1] + _w0[2] * _w0[2]
                                + _w0[3] * _w0[3] + _w0[4] * _w0[4] + _w0[5] * _w0[5];
            return false;
        }

        private void Commit(float[] output)
        {
            for (int i = 0; i < _n; i++) output[i] = _u[i];
        }

        private void ComputeResidual(float[] u)
        {
            int n = _n;
            float b0 = 0f, b1 = 0f, b2 = 0f, b3 = 0f, b4 = 0f, b5 = 0f;

            for (int i = 0; i < n; i++)
            {
                float ui = u[i];
                if (ui == 0f) continue;

                b0 += _b[0 * n + i] * ui;
                b1 += _b[1 * n + i] * ui;
                b2 += _b[2 * n + i] * ui;
                b3 += _b[3 * n + i] * ui;
                b4 += _b[4 * n + i] * ui;
                b5 += _b[5 * n + i] * ui;
            }

            float d0 = _w0[0] - b0;
            float d1 = _w0[1] - b1;
            float d2 = _w0[2] - b2;
            float d3 = _w0[3] - b3;
            float d4 = _w0[4] - b4;
            float d5 = _w0[5] - b5;

            LastResidualSquared = d0 * d0 + d1 * d1 + d2 * d2
                                + d3 * d3 + d4 * d4 + d5 * d5;
        }

        // Active-set ridge solve:  u = (B^T B + λI)^-1 B^T w
        private bool SolveActive()
        {
            int n = _n;
            float lambda = Mathf.Max(0f, Regularization);

            for (int i = 0; i < n; i++)
            {
                if (!_active[i])
                {
                    // Pin a saturated nozzle: an identity row lets the
                    // Cholesky factorisation pass it back out unchanged.
                    for (int j = 0; j < n; j++) _btb[i * n + j] = 0f;
                    _btb[i * n + i] = 1f;
                    _btw[i] = _u[i];
                    continue;
                }

                for (int j = 0; j < n; j++)
                {
                    if (!_active[j]) { _btb[i * n + j] = 0f; continue; }

                    float s = 0f;
                    for (int r = 0; r < Dofs; r++) s += _b[r * n + i] * _b[r * n + j];
                    _btb[i * n + j] = s;
                }
                _btb[i * n + i] += lambda;

                float btw = 0f;
                for (int r = 0; r < Dofs; r++) btw += _b[r * n + i] * _w[r];
                _btw[i] = btw;
            }

            if (!CholeskyFactorize()) return false;

            // Forward-substitute L y = btw.
            for (int i = 0; i < n; i++)
            {
                float sum = _btw[i];
                for (int k = 0; k < i; k++) sum -= _l[i * n + k] * _y[k];
                _y[i] = sum / _l[i * n + i];
            }

            // Back-substitute L^T u = y.
            for (int i = n - 1; i >= 0; i--)
            {
                float sum = _y[i];
                for (int k = i + 1; k < n; k++) sum -= _l[k * n + i] * _u[k];
                _u[i] = sum / _l[i * n + i];
            }

            return true;
        }

        private bool CholeskyFactorize()
        {
            int n = _n;
            for (int i = 0; i < n; i++)
            {
                for (int j = 0; j <= i; j++)
                {
                    float sum = _btb[i * n + j];
                    for (int k = 0; k < j; k++) sum -= _l[i * n + k] * _l[j * n + k];

                    if (i == j)
                    {
                        if (sum <= 1e-12f) return false;
                        _l[i * n + i] = Mathf.Sqrt(sum);
                    }
                    else
                    {
                        _l[i * n + j] = sum / _l[j * n + j];
                    }
                }
            }
            return true;
        }
    }
}
