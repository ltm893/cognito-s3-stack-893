// apps/music-player/backend/lib/music-stack.ts
// Music Player add-on. Reads base_outputs.json for Cognito + S3.
// Deploys: new App Client, Lambda (file listing + presigned URLs), API Gateway.

import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import * as cognito from "aws-cdk-lib/aws-cognito";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as lambdaNodejs from "aws-cdk-lib/aws-lambda-nodejs";
import * as apigateway from "aws-cdk-lib/aws-apigateway";
import * as path from "path";
import { BaseOutputs } from "../../../../shared/types/base-outputs";

export interface MusicPlayerStackProps extends cdk.StackProps {
  base: BaseOutputs;
}

export class MusicPlayerStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: MusicPlayerStackProps) {
    super(scope, id, props);

    const { base } = props;

    // ── Import shared User Pool from base ─────────────────────────────────────
    const userPool = cognito.UserPool.fromUserPoolId(
      this, "SharedUserPool", base.auth.user_pool_id
    );

    // ── New App Client for MusicPlayer ───────────────────────────────────────
    const appClient = userPool.addClient("MusicPlayerClient", {
      userPoolClientName: "music-player-client",
      authFlows: {
        userPassword:      true,
        userSrp:           true,
        adminUserPassword: true,
      },
      preventUserExistenceErrors: true,
    });

    // ── Private bucket reference (from base) ──────────────────────────────────
    const privateBucket = cdk.aws_s3.Bucket.fromBucketName(
      this, "PrivateBucket", base.storage.private_bucket
    );

    // ── Files Lambda ──────────────────────────────────────────────────────────
    const filesLambda = new lambdaNodejs.NodejsFunction(this, "FilesLambda", {
      entry:       path.join(__dirname, "../lambda/files.ts"),
      handler:     "handler",
      runtime:     lambda.Runtime.NODEJS_20_X,
      environment: {
        PRIVATE_BUCKET:     base.storage.private_bucket,
        AWS_ACCOUNT_REGION: base.aws_region,
      },
      timeout: cdk.Duration.seconds(15),
      bundling: {
        externalModules: ["@aws-sdk/client-s3", "@aws-sdk/s3-request-presigner"],
      },
    });

    privateBucket.grantRead(filesLambda);
    privateBucket.grantPut(filesLambda);

    // ── API Gateway ───────────────────────────────────────────────────────────
    const api = new apigateway.RestApi(this, "MusicPlayerAPI", {
      restApiName: "music-player-api",
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
        allowHeaders: ["Content-Type", "Authorization"],
      },
    });

    const authorizer = new apigateway.CognitoUserPoolsAuthorizer(
      this, "MusicAuthorizer", { cognitoUserPools: [userPool] }
    );
    const auth: apigateway.MethodOptions = {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    };

    // GET /files?prefix=Music/   → list files and folders
    // GET /files/{key+}          → presigned download URL
    const files = api.root.addResource("files");
    files.addMethod("GET", new apigateway.LambdaIntegration(filesLambda), auth);
    const file = files.addResource("{key+}");
    file.addMethod("GET", new apigateway.LambdaIntegration(filesLambda), auth);

    // ── Outputs ───────────────────────────────────────────────────────────────
    new cdk.CfnOutput(this, "ApiUrl",       { value: api.url });
    new cdk.CfnOutput(this, "UserPoolId",   { value: userPool.userPoolId });
    new cdk.CfnOutput(this, "AppClientId",  { value: appClient.userPoolClientId });
    new cdk.CfnOutput(this, "PrivateBucket",{ value: base.storage.private_bucket });
    new cdk.CfnOutput(this, "AwsRegion",    { value: base.aws_region });
  }
}
