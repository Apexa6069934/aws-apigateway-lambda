#!/usr/bin/env node
import 'source-map-support/register';
import { AwsApigatewayLambdaStack } from '../lib/aws-apigateway-lambda-stack';
import { TRCdk } from 'tr-cdk-lib';

const app = TRCdk.newApp(
    {
        assetId: '205451',
        resourceOwner: 'Apexa.Dabhi@thomsonreuters.com',
        awsTargetEnv: {}, // Use defaults, this will load your currently active aws credentials profile and default region
        namingProps: {prefix: 'doe'},  // Use defaults, this will use the standard TR name formatter with no name prefix.
    }
);

const stack = new AwsApigatewayLambdaStack(app, 'api-endpoint-lambda');
stack.templateOptions.description = 'Creates an API that runs a lambda upon accessing an endpoint.';
