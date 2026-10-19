import { defineBackend } from '@aws-amplify/backend';
import type { CfnResource } from 'aws-cdk-lib';
import { auth } from './auth/resource.js';

/**
 * Thrower App's backend (AWS Amplify Gen 2; Nigel, 2026-10-19: "stage two will
 * always be AWS Amplify", following WhereWillWeVisit). Deployed by Amplify
 * Hosting from this repo, in London: `main` is production, `dev` is
 * development (amplify.yml runs `ampx pipeline-deploy`). The app is a phone
 * app, so nothing here is needed to score: signing in only adds backup,
 * friends and (later) the Game Centre.
 *
 * Task 1: sign-in; Task 3: Google and Sign in with Apple. The data models
 * (history, player names) come in Task 4.
 */
const backend = defineBackend({
  auth,
});

/**
 * Each branch's Cognito sign-in domain (`<prefix>.auth.eu-west-2.amazoncognito.com`),
 * set from the first deploy that has Google and Apple. Without it Amplify
 * makes a hash domain, which Google's consent screen shows ("to continue to
 * 4642c8c2…"). WhereWillWeVisit learned that renaming one later takes two
 * deploys (Cognito allows one domain per pool): its docs, Infrastructure →
 * AWS Resources → "Cognito Hosted UI Domain & OAuth". Google's redirect URIs
 * and Apple's Services ID return URLs list `https://<domain>/oauth2/idpresponse`
 * for every branch here. A sandbox keeps Amplify's own domain.
 */
const domainPrefixByBranch: Record<string, string> = {
  main: 'throwerapp',
  dev: 'throwerapp-dev',
};
const prefix = domainPrefixByBranch[process.env.AWS_BRANCH ?? ''];
if (prefix) {
  // The construct's ID is `<auth name>UserPoolDomain` in this version (WhereWillWeVisit's was
  // plain `UserPoolDomain`); fail the deploy rather than silently keep a hash domain.
  const userPoolDomain = backend.auth.resources.userPool.node.children.find((c) => c.node.id.endsWith('UserPoolDomain'));
  if (!userPoolDomain) throw new Error('No UserPoolDomain on the user pool: cannot set the sign-in domain');
  (userPoolDomain.node.findChild('Resource') as CfnResource).addPropertyOverride('Domain', prefix);
}
