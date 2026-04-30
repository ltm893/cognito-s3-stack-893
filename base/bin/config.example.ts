// base/bin/config.example.ts
// ─────────────────────────────────────────────────────────────────────────────
// Copy this file to config.ts and fill in your values.
// config.ts is gitignored — never commit it.
//
//   cp base/bin/config.example.ts base/bin/config.ts
//
// ─────────────────────────────────────────────────────────────────────────────

export const config = {
  // Short identifier used as a prefix for all AWS resource names.
  // Use lowercase letters, numbers, and hyphens only (S3 naming rules apply).
  // Examples: "johndoe", "myapp", "acme123"
  id: "your-id-here",

  // AWS region to deploy into.
  awsRegion: "us-east-1",

  // Name for your Cognito User Pool.
  // Defaults to "{id}-app-users" if you leave it as-is.
  userPoolName: "your-id-here-app-users",

  // Email address Cognito sends invite emails from.
  // Must be verified in AWS SES for production use.
  fromEmail: "noreply@yourdomain.com",
};
