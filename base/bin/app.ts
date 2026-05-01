#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { BaseStack } from "../lib/base-stack";
import { config } from "./config";

const app = new cdk.App();

// Stack name is derived from config.id so multiple deployments on the same
// AWS account don't collide — important for local fork testing.
const stackName = `CognitoS3BaseStack-${config.id}`;

new BaseStack(app, stackName, {
  id:           config.id,
  awsRegion:    config.awsRegion,
  userPoolName: config.userPoolName,
  fromEmail:    config.fromEmail,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region:  config.awsRegion,
  },
});
