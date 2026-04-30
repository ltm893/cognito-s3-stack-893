#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import * as path from "path";
import { MusicPlayerStack } from "../lib/music-stack";
import { loadBaseOutputs } from "../../../../shared/types/base-outputs";

const base = loadBaseOutputs(path.join(__dirname, "../../../.."));

const app = new cdk.App();

new MusicPlayerStack(app, "MusicPlayerStack", {
  base,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region:  base.aws_region,
  },
});
