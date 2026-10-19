import { defineAuth } from '@aws-amplify/backend';

/**
 * Accounts (stage 2 of docs/thrower/stories/accounts/Accounts Roadmap.md;
 * story docs/thrower/stories/story-checkpoint-app-user-accounts.md).
 *
 * Cognito, signing in with an email and password for now (Task 1). Google and
 * Sign in with Apple come in Task 3, as WhereWillWeVisit has them
 * (where_in_nz_v3/amplify/auth/resource.ts): they need their client secrets
 * set in the Amplify console first (secret(...)), or the deploy fails.
 *
 * The app's user ID is the Cognito `sub`, never derived from the email
 * (WhereWillWeVisit's "Known incident": Sign in with Apple's relay email
 * isn't stable).
 */
export const auth = defineAuth({
  loginWith: {
    email: true,
  },
});
