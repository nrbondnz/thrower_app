import { a, defineData, type ClientSchema } from '@aws-amplify/backend';

/**
 * What a signed-in app user backs up (accounts Task 4): their kept games and
 * their player names. Every row is **owned**: `allow.owner()` lets only the
 * user who wrote it read, change or delete it (Cognito `sub`), so no custom
 * resolvers are needed (WhereWillWeVisit's tables are open to any signed-in
 * user and rely on its resolvers instead: its CR-03).
 *
 * The phone's files stay the source of truth (offline-first); these are the
 * backup, merged in on sign-in.
 */
const schema = a.schema({
  /**
   * One kept game. `id` is `<owner sub>:<gameId>` (made by the app), so two
   * users' games that finished in the same microsecond can't collide.
   * `record` is the app's own `GameRecord.toJson()` (its `version` inside),
   * so the app's format can grow without a schema change.
   */
  KeptGame: a
    .model({
      gameId: a.string().required(),
      finishedAt: a.datetime().required(),
      record: a.json().required(),
    })
    .authorization((allow) => [allow.owner()]),

  /** The player names last used (`id` is the owner's `sub`: one row each). */
  PlayerNameList: a
    .model({
      names: a.json().required(),
    })
    .authorization((allow) => [allow.owner()]),
});

export type Schema = ClientSchema<typeof schema>;

export const data = defineData({
  schema,
  authorizationModes: {
    defaultAuthorizationMode: 'userPool',
  },
});
