#  Pylambda

This is an example workflow for the development of lambda functions, using Python 3.6. It contains an infrastructure oriented
lambda function in order to exemplify the whole workflow. It uses [Terraform](https://www.terraform.io/) in order to 
operate on the infrastructure.

## Design

The functions will use AWS Python SDK (boto3) to interact with AWS resources. Besides it's clear goal, each function
faces a set of common patterns:

 - extract parameters from the instance tags; here we also treat the parameters for validity and raise any exceptions;
 general rule is that we continue with the next instance in case of exception.
 - perform function task based on the parameters.
 
In order to have a complete functional package, we need to define the individual infrastructure elements that the current
function make use of. Concrete, we must specify the following:

 - IAM role for the function, with the right permissions which will allow the function to perform its operations
 - the Lambda function
 - CloudWatch trigger, or any other trigger source
 - CloudWatch alarms: based on the Error count of Invocation count.

Each function will live in a separate folder, together with it's Terraform configuration (`main.tf`) and declared 
dependencies (`requirements.txt`).
 
## Terraform state

Whenever there are modifications to be done to the infrastructure, Terraform wil capture the current state, and will 
record any updates it makes, so that one can destroy the artifacts created. In order to be visible from everywhere, the
state is persisted on S3, in `<! YOUR ACCOUNT ID !>-terraform` bucket. In order to synchronize the update of the infrastructure,
a DynamoDb table is used `terraform_locks`. Both of this objects must exist before running terraform. We've provided
a utility script to create them, idempotent in it's operation: `aws-init-terraform.sh`.

Each function will have a different state file in S3, so they act independently. The lock table is safe to be used in
common - the lock keys created here are based on the hash of the state.

## Deploying functions

There is a 2 step process in deploying a function:
 
 * first we must bundle the function code into a zip package which contains the main code and it's dependencies;
 * afterwards we will use Terraform to deploy the code bundle and to create / update any infrastructure artefacts
 that we have configured.

For convenience, we have provided a build script (`build-lambda`) which will prepare the code bundle in the output folder.
The script must be run from that path in order for it to work. The workflow then would look like this:
 
 * build your function using `build-lambda <your-function-name>`
 * from within the function folder (`cd <your-function-name>`) run terraform:
    - `terraform init`
    - `terraform plan`; review the proposed plan
    - `terraform apply`

In order for terraform to work you need to have set up in advance `aws` cli tools. Terraform will use your profile from
`~/.aws` to connect to your account and do the deployment.