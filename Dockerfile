FROM amazonlinux:2017.09

ENV PS1='\u@\h [\w] \\$ '

## Install build tools
RUN yum group install -y 'Development tools'

## Install python
RUN yum install -y python36 && ln -s /usr/bin/pip-3.6 /usr/bin/pip

## Install aws cli
RUN pip install awscli && mkdir ~/.aws

# Install terraform
RUN curl https://releases.hashicorp.com/terraform/0.11.1/terraform_0.11.1_linux_amd64.zip > terraform.zip \
    && yum install -y unzip && unzip terraform.zip -d /opt && rm -f terraform.zip \
    && chmod a+x /opt/terraform

ENV PATH="${PATH}:/opt/"

RUN mkdir /workspace

WORKDIR /workspace
