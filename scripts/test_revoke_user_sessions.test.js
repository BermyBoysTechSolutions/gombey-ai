'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { revokeUserSessions } = require('./revoke-user-sessions');

test('requires the exact confirmation phrase before looking up or deleting sessions', async () => {
  let lookups = 0;
  let deletions = 0;
  const result = await revokeUserSessions({
    email: 'owner@example.test',
    confirmation: 'yes',
    findUser: async () => {
      lookups += 1;
    },
    deleteAllUserSessions: async () => {
      deletions += 1;
    },
  });

  assert.deepEqual(result, { revoked: false, deletedCount: 0 });
  assert.equal(lookups, 0);
  assert.equal(deletions, 0);
});

test('revokes only the sessions belonging to the explicitly entered account', async () => {
  const accountId = '507f1f77bcf86cd799439011';
  let lookupArgs;
  let deleteArgs;
  const result = await revokeUserSessions({
    email: '  owner@example.test  ',
    confirmation: 'REVOKE',
    findUser: async (...args) => {
      lookupArgs = args;
      return { _id: accountId };
    },
    deleteAllUserSessions: async (args) => {
      deleteArgs = args;
      return { deletedCount: 3 };
    },
  });

  assert.deepEqual(lookupArgs, [{ email: 'owner@example.test' }, '_id email']);
  assert.deepEqual(deleteArgs, { userId: accountId });
  assert.deepEqual(result, { revoked: true, deletedCount: 3 });
});

test('fails closed when the account is not found', async () => {
  let deletions = 0;
  await assert.rejects(
    revokeUserSessions({
      email: 'missing@example.test',
      confirmation: 'REVOKE',
      findUser: async () => null,
      deleteAllUserSessions: async () => {
        deletions += 1;
      },
    }),
    /No account matches/,
  );
  assert.equal(deletions, 0);
});

test('fails closed when the matching account has no usable ID', async () => {
  let deletions = 0;
  await assert.rejects(
    revokeUserSessions({
      email: 'owner@example.test',
      confirmation: 'REVOKE',
      findUser: async () => ({}),
      deleteAllUserSessions: async () => {
        deletions += 1;
      },
    }),
    /no usable ID/,
  );
  assert.equal(deletions, 0);
});

test('rejects an empty email without accessing account or session data', async () => {
  let accesses = 0;
  await assert.rejects(
    revokeUserSessions({
      email: '  ',
      confirmation: 'REVOKE',
      findUser: async () => {
        accesses += 1;
      },
      deleteAllUserSessions: async () => {
        accesses += 1;
      },
    }),
    /email is required/,
  );
  assert.equal(accesses, 0);
});
