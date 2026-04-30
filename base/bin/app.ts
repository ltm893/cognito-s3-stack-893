#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { BaseStack } from "../lib/base-stack";
import { config } from "./config";

const app = new cdk.App();

new BaseStack(app, "CognitoS3BaseStack", {
  id:           config.id,
  awsRegion:    config.awsRegion,
  userPoolName: config.userPoolName,
  fromEmail:    config.fromEmail,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region:  config.awsRegion,
  },
});
