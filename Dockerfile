FROM amazonlinux:2

## Install python
RUN amazon-linux-extras install python3 && \
    pip-3.6 install --user awscli boto3 && mkdir ~/.aws

# Install terraform
RUN curl https://releases.hashicorp.com/terraform/0.11.1/terraform_0.11.1_linux_amd64.zip > terraform.zip \
    && yum install -y zip unzip && unzip terraform.zip -d /opt && rm -f terraform.zip \
    && chmod a+x /opt/terraform

COPY build-lambda.sh /opt/build-lambda

ENV PATH="${PATH}:/opt/" \
    PS1="\u@\h [\w] \\$ "

RUN mkdir /workspace

WORKDIR /workspace
