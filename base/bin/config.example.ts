// base/bin/config.example.ts
// ─────────────────────────────────────────────────────────────────────────────
// Copy this file to config.ts and fill in your values. config.ts is gitignored.
//
//   cp base/bin/config.example.ts base/bin/config.ts
//
// ─────────────────────────────────────────────────────────────────────────────

export const config = {
  // Short prefix for all AWS resource names.
  // Lowercase letters, numbers, hyphens only (S3 naming rules).
  // Example: "johndoe", "myapp", "acme123"
  id: "your-id-here",

  // AWS region to deploy into.
  awsRegion: "us-east-1",

  // Cognito User Pool name.
  userPoolName: "your-id-here-app-users",

  // Email address Cognito sends invite emails from.
  // Must be verified in AWS SES for production use.
  fromEmail: "noreply@yourdomain.com",
};
