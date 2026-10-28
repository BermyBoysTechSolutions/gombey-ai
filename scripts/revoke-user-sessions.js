'use strict';

/**
 * Revoke all stored refresh-token sessions for one account in this dedicated
 * customer deployment. Existing signed access JWTs remain valid until expiry.
 * This is an operator recovery aid, not a substitute for global secret rotation
 * when immediate containment is required.
 */
async function revokeUserSessions({ email, confirmation, findUser, deleteAllUserSessions }) {
  const normalizedEmail = typeof email === 'string' ? email.trim() : '';
  if (!normalizedEmail) {
    throw new Error('An account email is required.');
  }
  if (confirmation !== 'REVOKE') {
    return { revoked: false, deletedCount: 0 };
  }

  const user = await findUser({ email: normalizedEmail }, '_id email');
  if (!user) {
    throw new Error('No account matches that email. No sessions were changed.');
  }

  const userId = user._id?.toString?.() ?? String(user._id ?? '');
  if (!userId) {
    throw new Error('The matching account has no usable ID. No sessions were changed.');
  }

  const result = await deleteAllUserSessions({ userId });
  return { revoked: true, deletedCount: result?.deletedCount ?? 0 };
}

async function main() {
  const readline = require('node:readline');
  const mongoose = require('mongoose');

  // The supported LibreChat connector sets the `~/` alias before models load.
  const connect = require('/app/config/connect');
  await connect();
  let rl;
  try {
    const { findUser, deleteAllUserSessions } = require('/app/api/models');
    rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const ask = (prompt) => new Promise((resolve) => rl.question(prompt, resolve));
    const email = await ask('Account email: ');
    const confirmation = await ask(
      'Type REVOKE to delete this account’s stored refresh sessions: ',
    );
    const result = await revokeUserSessions({
      email,
      confirmation: confirmation.trim(),
      findUser,
      deleteAllUserSessions,
    });

    if (!result.revoked) {
      console.log('Cancelled. No sessions were changed.');
      return;
    }

    console.log(`Deleted ${result.deletedCount} stored refresh-token session(s).`);
    console.log(
      'Already-issued access tokens remain usable until expiry (15 minutes by default).',
    );
  } finally {
    rl?.close();
    await mongoose.disconnect();
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`Session revocation failed: ${error.message}`);
    process.exitCode = 1;
  });
}

module.exports = { revokeUserSessions };
