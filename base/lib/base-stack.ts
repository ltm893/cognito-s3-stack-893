// base/lib/base-stack.ts
// Foundation shared by every add-on:
//   - Cognito User Pool (invite-only) + App Client
//   - Cognito Identity Pool (temp AWS creds for mobile apps)
//   - S3 public bucket  (publicly readable, authenticated write)
//   - S3 private bucket (authenticated users only)
//   - IAM authenticated role scoped to both buckets
//
// Outputs written to base_outputs.json at repo root by deploy.sh.
// Add-ons read base_outputs.json to get pool IDs, bucket names etc.

import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as cognito from "aws-cdk-lib/aws-cognito";
import * as iam from "aws-cdk-lib/aws-iam";

export interface BaseStackProps extends cdk.StackProps {
  id:           string;
  awsRegion:    string;
  userPoolName: string;
  fromEmail:    string;
}

export class BaseStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: BaseStackProps) {
    super(scope, id, props);

    // ── S3 Public Bucket ──────────────────────────────────────────────────────
    const publicBucket = new s3.Bucket(this, "PublicBucket", {
      bucketName:        `${props.id}-public`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ACLS,
      publicReadAccess:  false,
      versioned:         false,
      removalPolicy:     cdk.RemovalPolicy.RETAIN,
      cors: [{
        allowedOrigins: ["*"],
        allowedMethods: [s3.HttpMethods.GET, s3.HttpMethods.HEAD,
                         s3.HttpMethods.PUT, s3.HttpMethods.DELETE],
        allowedHeaders: ["*"],
        exposedHeaders: ["ETag"],
        maxAge: 3000,
      }],
    });

    publicBucket.addToResourcePolicy(new iam.PolicyStatement({
      sid:        "PublicReadGetObject",
      effect:     iam.Effect.ALLOW,
      principals: [new iam.AnyPrincipal()],
      actions:    ["s3:GetObject"],
      resources:  [`${publicBucket.bucketArn}/*`],
    }));

    // ── S3 Private Bucket ─────────────────────────────────────────────────────
    const privateBucket = new s3.Bucket(this, "PrivateBucket", {
      bucketName:        `${props.id}-private`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      versioned:         true,
      removalPolicy:     cdk.RemovalPolicy.RETAIN,
      cors: [{
        allowedOrigins: ["*"],
        allowedMethods: [s3.HttpMethods.GET, s3.HttpMethods.HEAD,
                         s3.HttpMethods.PUT, s3.HttpMethods.DELETE],
        allowedHeaders: ["*"],
        exposedHeaders: ["ETag"],
        maxAge: 3000,
      }],
    });

    // ── Cognito User Pool (invite-only) ───────────────────────────────────────
    const userPool = new cognito.UserPool(this, "UserPool", {
      userPoolName:      props.userPoolName,
      selfSignUpEnabled: false,
      signInAliases:     { email: true },
      autoVerify:        { email: true },
      userInvitation: {
        emailSubject: "You've been invited",
        emailBody:
          "Hi {username},<br/><br/>" +
          "Your temporary password is: <strong>{####}</strong><br/>" +
          "You will be prompted to set a new password on first sign in.",
      },
      passwordPolicy: {
        minLength:        8,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits:    true,
        requireSymbols:   true,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      removalPolicy:   cdk.RemovalPolicy.RETAIN,
    });

    const appClient = userPool.addClient("AppClient", {
      userPoolClientName: `${props.id}-app-client`,
      authFlows: {
        userPassword:      true,
        userSrp:           true,
        adminUserPassword: true,
      },
      preventUserExistenceErrors: true,
    });

    // ── Cognito Identity Pool ─────────────────────────────────────────────────
    const identityPool = new cognito.CfnIdentityPool(this, "IdentityPool", {
      identityPoolName:               `${props.id.replace(/-/g, "_")}_identity_pool`,
      allowUnauthenticatedIdentities: false,
      cognitoIdentityProviders: [{
        clientId:     appClient.userPoolClientId,
        providerName: userPool.userPoolProviderName,
      }],
    });

    // ── IAM Authenticated Role ────────────────────────────────────────────────
    const authRole = new iam.Role(this, "AuthenticatedRole", {
      description: "Temporary credentials for authenticated app users",
      assumedBy: new iam.FederatedPrincipal(
        "cognito-identity.amazonaws.com",
        {
          StringEquals: { "cognito-identity.amazonaws.com:aud": identityPool.ref },
          "ForAnyValue:StringLike": { "cognito-identity.amazonaws.com:amr": "authenticated" },
        },
        "sts:AssumeRoleWithWebIdentity"
      ),
    });

    authRole.addToPolicy(new iam.PolicyStatement({
      actions:   ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      resources: [`${publicBucket.bucketArn}/*`],
    }));
    authRole.addToPolicy(new iam.PolicyStatement({
      actions:   ["s3:ListBucket"],
      resources: [publicBucket.bucketArn],
    }));
    authRole.addToPolicy(new iam.PolicyStatement({
      actions:   ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      resources: [`${privateBucket.bucketArn}/*`],
    }));
    authRole.addToPolicy(new iam.PolicyStatement({
      actions:   ["s3:ListBucket"],
      resources: [privateBucket.bucketArn],
    }));

    new cognito.CfnIdentityPoolRoleAttachment(this, "IdentityPoolRoles", {
      identityPoolId: identityPool.ref,
      roles: { authenticated: authRole.roleArn },
    });

    // ── Outputs (read by deploy.sh → base_outputs.json) ───────────────────────
    new cdk.CfnOutput(this, "AwsRegion",           { value: props.awsRegion });
    new cdk.CfnOutput(this, "UserPoolId",           { value: userPool.userPoolId });
    new cdk.CfnOutput(this, "UserPoolClientId",     { value: appClient.userPoolClientId });
    new cdk.CfnOutput(this, "UserPoolProviderName", { value: userPool.userPoolProviderName });
    new cdk.CfnOutput(this, "IdentityPoolId",       { value: identityPool.ref });
    new cdk.CfnOutput(this, "AuthRoleArn",          { value: authRole.roleArn });
    new cdk.CfnOutput(this, "PublicBucketName",     { value: publicBucket.bucketName });
    new cdk.CfnOutput(this, "PrivateBucketName",    { value: privateBucket.bucketName });
  }
}
