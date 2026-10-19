import { defineBackend } from '@aws-amplify/backend';
import { auth } from './auth/resource.js';

/**
 * Thrower App's backend (AWS Amplify Gen 2; Nigel, 2026-10-19: "stage two will
 * always be AWS Amplify", following WhereWillWeVisit). Deployed by Amplify
 * Hosting from this repo: `main` is production, `dev` is development
 * (amplify.yml runs `ampx pipeline-deploy`). The app is a phone app, so
 * nothing here is needed to score: signing in only adds backup, friends and
 * (later) the Game Centre.
 *
 * Task 1: sign-in only. The data models (history, player names) come in Task 4.
 */
defineBackend({
  auth,
});
