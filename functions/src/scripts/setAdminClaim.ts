/**
 * setAdminClaim.ts — One-off provisioning script for the S12 admin custom claim.
 *
 * Grants (or revokes) `{ admin: true }` on a Firebase Auth user, which
 * firestore.rules' `isAdmin()` and functions/src/middleware/auth.ts's
 * `requireAdmin()` both check. This is intentionally NOT a Cloud Function —
 * an HTTP-triggerable "make me admin" endpoint would defeat the whole point
 * of the claim. Run it locally against production credentials, by a human,
 * the same way seedDemiurgeData.ts is run.
 *
 * Usage:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json
 *   npx ts-node src/scripts/setAdminClaim.ts <uid> grant
 *   npx ts-node src/scripts/setAdminClaim.ts <uid> revoke
 *
 * The uid is a Firebase Auth UID (not an email) — look it up via the
 * Firebase Console or `admin.auth().getUserByEmail(email)` first if needed.
 */

import { initializeApp, applicationDefault, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

function usageAndExit(message: string): never {
  // eslint-disable-next-line no-console
  console.error(message);
  // eslint-disable-next-line no-console
  console.error('Usage: ts-node setAdminClaim.ts <uid> <grant|revoke>');
  process.exit(1);
}

async function main() {
  const [, , uid, action] = process.argv;

  if (!uid) usageAndExit('Missing required argument: uid');
  if (action !== 'grant' && action !== 'revoke') {
    usageAndExit(`Invalid action "${action}" — must be "grant" or "revoke"`);
  }

  if (getApps().length === 0) {
    initializeApp({ credential: applicationDefault() });
  }

  const auth = getAuth();
  const user = await auth.getUser(uid); // fail loud if the uid doesn't exist
  const existingClaims = user.customClaims || {};

  const nextClaims = action === 'grant'
    ? { ...existingClaims, admin: true }
    : { ...existingClaims, admin: false };

  await auth.setCustomUserClaims(uid, nextClaims);

  // eslint-disable-next-line no-console
  console.log(
    `${action === 'grant' ? 'Granted' : 'Revoked'} admin claim for ${uid} (${user.email || 'no email'}). ` +
    'Existing sessions must sign out/in (or force-refresh the ID token) to pick up the new claim — ' +
    'Firebase ID tokens cache claims for up to 1 hour.'
  );
}

main().catch((error) => {
  // eslint-disable-next-line no-console
  console.error('setAdminClaim failed:', error instanceof Error ? error.message : error);
  process.exit(1);
});
