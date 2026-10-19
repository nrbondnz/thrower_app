import { defineAuth, secret } from '@aws-amplify/backend';

/**
 * Accounts (stage 2 of docs/thrower/stories/accounts/Accounts Roadmap.md;
 * story docs/thrower/stories/story-checkpoint-app-user-accounts.md).
 *
 * Cognito: an email and password (Task 1), Google and Sign in with Apple
 * (Task 3), as WhereWillWeVisit (where_in_nz_v3/amplify/auth/resource.ts).
 * The providers' client IDs, keys and secrets are Amplify secrets (set in the
 * Amplify console → Hosting → Secrets, for every branch), never in git: a
 * deploy fails until all six exist. Common Tasks → Set Up Google and Sign in
 * with Apple.
 *
 * The app's user ID is the Cognito `sub`, never derived from the email
 * (WhereWillWeVisit's "Known incident": Sign in with Apple's relay email
 * isn't stable).
 */
export const auth = defineAuth({
  loginWith: {
    email: true,
    externalProviders: {
      google: {
        clientId: secret('GOOGLE_CLIENT_ID'),
        clientSecret: secret('GOOGLE_CLIENT_SECRET'),
        scopes: ['email', 'profile', 'openid'],
        attributeMapping: {
          email: 'email',
        },
      },
      signInWithApple: {
        clientId: secret('APPLE_CLIENT_ID'),
        teamId: secret('APPLE_TEAM_ID'),
        keyId: secret('APPLE_KEY_ID'),
        privateKey: secret('APPLE_PRIVATE_KEY'),
        scopes: ['email', 'name'],
        attributeMapping: {
          email: 'email',
        },
      },
      // The phone app's return link after the provider's sign-in page: the
      // custom scheme the Android intent filter and the iOS URL type claim.
      // Cognito needs each URL exactly (no wildcards).
      callbackUrls: ['throwerapp://callback/'],
      logoutUrls: ['throwerapp://signout/'],
    },
  },
});
