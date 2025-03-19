import { Duration, Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { ApiGatewayToLambda } from 'tr-cdk-lib/aws-apigateway-lambda/lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigw from "aws-cdk-lib/aws-apigateway";

export class AwsApigatewayLambdaStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    new ApiGatewayToLambda(this, 'ApiGatewayToLambdaPattern', {
      lambdaFunctionProps: {
        runtime: lambda.Runtime.PYTHON_3_9,
        code: lambda.Code.fromAsset('lambda'),
        handler: 'hello.handler',
      },
      apiGatewayProps: {
        defaultMethodOptions: {
          authorizationType: apigw.AuthorizationType.NONE,
        }
      },
    });
  }
}
