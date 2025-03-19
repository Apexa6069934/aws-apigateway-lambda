#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { AwsApigatewayLambdaStack } from '../lib/aws-apigateway-lambda-stack';

const app = new cdk.App();
new AwsApigatewayLambdaStack(app, 'AwsApigatewayLambdaStack');
