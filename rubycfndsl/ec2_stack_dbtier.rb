#!/usr/bin/env ruby

# Standard cfn-ruby libraries:
require 'pry'
require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

template do

  # Format Version:
  
  value :AWSTemplateFormatVersion => '2010-09-09'

  # Description:

  value :Description => 'EC2 Instance'

  # Default Mandatory Parameters

  parameter 'EnvironmentName',
    :Description => 'The environment Name',
    :Type => 'String',
    :MinLength => '1',
    :MaxLength => '64',
    :AllowedPattern => '[a-zA-Z][a-zA-Z0-9]*',
    :ConstraintDescription => 'must begin with a letter and contain only alphanumeric characters.'

  parameter 'Application',
    :Description => 'The Project Name',
    :Type => 'String',
    :MinLength => '1',
    :MaxLength => '64',
    :AllowedPattern => '[a-zA-Z][a-zA-Z0-9]*',
    :ConstraintDescription => 'must begin with a letter and contain only alphanumeric characters.'

  parameter 'VPC',
    :Description => 'The VPC Id',
    :Type => 'String',
    :MinLength => '1',
    :MaxLength => '64',
    :AllowedPattern => 'vpc-[a-zA-Z0-9]*',
    :ConstraintDescription => 'must begin with vpc- and contain only alphanumeric characters.'

  parameter 'Category',
    :Description => 'Category for billing purpose',
    :Type => 'String',
    :MinLength => '1',
    :MaxLength => '64',
    :AllowedPattern => '[a-zA-Z0-9-\.]*',
    :ConstraintDescription => 'must begin with a letter and contain only alphanumeric characters.'

  # Specific parameters

  parameter 'DefaultSecurityGroup',
    :Type => 'String'

  parameter 'PublicSubnets',
    :Description => 'The subnet Id',
    :Type => 'CommaDelimitedList'

  parameter 'PrivateSubnets',
    :Description => 'The subnet Id',
    :Type => 'CommaDelimitedList'

  parameter 'ImageId',
    :Description => 'The AMI Id',
    :Type => 'String',
    :ConstraintDescription => 'must begin with ami- and contain only alphanumeric characters.',
    :AllowedPattern => 'ami-[a-zA-Z0-9]*'

  parameter 'InstanceType',
    :Description => 'EC2 instance type"',
    :Type => 'String',
    :AllowedValues => [ "t2.micro", "m1.small", "m1.medium", "m1.large", "m1.xlarge", "m2.xlarge", "m2.2xlarge", 
                        "m2 .4xlarge", "c1.medium", "c1.xlarge", "hi1.4xlarge", "hs1.8xlarge", "m3.medium",
                        "m3.large", "m3.xlarge", "m3.2xlarge", "c3.large", "c3.xlarge", "c3.2xlarge", "c3.4xlarge",
                        "c3.8xlarge" ]

  parameter 'KeyName',
    :Description => 'Key pair name',
    :Type => 'String',
    :ConstraintDescription => 'must contain only alphanumeric characters.',
    :AllowedPattern => '[a-zA-Z0-9]*'

  parameter 'Purpose',
    :Description => 'Instance Purpose',
    :Type => 'String'

  parameter 'BucketName',
    :Description => 'The bucket name',
    :Type => 'String',
    :ConstraintDescription => 'must contain only alphanumeric characters.',
    :AllowedPattern => '[a-zA-Z0-9-\.]*'

  parameter 'AnsibleRole',
    :Description => 'The bucket name',
    :Type => 'String',
    :ConstraintDescription => 'must contain only alphanumeric characters.',
    :AllowedPattern => '[a-zA-Z0-9-\.]*'

  parameter 'NatAZ1IpAddress',
    :Type => 'String'

  parameter 'NatAZ2IpAddress',
    :Type => 'String'

  parameter 'AppTierSecurityGroup',
    :Description => 'AppTier Security Group',
    :Type => 'String',
    :AllowedPattern => '[a-zA-Z0-9-\.]*'

  # Include Mappings under maps/*
  
  Dir[File.join(File.expand_path(File.dirname($0)),'maps','*')].each do |map|
    eval File.read(map)
  end

  # Resource creation

  # The instance security group

  resource "SecurityGroup",
    :Type => "AWS::CloudFormation::Stack",
    :Properties => {
      :TemplateURL => join('/', 'https://s3.amazonaws.com', ref('BucketName'), ref('Application'),
                           ref('EnvironmentName'), 'cloudformation', join('','securitygroup_',ref('Purpose'),'.template')),
       :Parameters => {
         :EnvironmentName => ref('EnvironmentName'),
         :Application => ref('Application'),
         :Category => ref('Category'),
         :VPC => ref('VPC'),
         :Purpose => ref('Purpose'),
         :AppTierSecurityGroup => ref('AppTierSecurityGroup') 
       }
    }

  # The instance role

  resource "Role",
    :Type => "AWS::CloudFormation::Stack",
    :Properties => {
      :TemplateURL => join('/', 'https://s3.amazonaws.com', ref('BucketName'), ref('Application'),
                           ref('EnvironmentName'), 'cloudformation', 'role_default.template'),
      :Parameters => {
        :EnvironmentName => ref('EnvironmentName'),
        :Application => ref('Application'),
        :BucketName => ref('BucketName'),
        :AnsibleRole => ref('Purpose'),
      }
    }

  resource 'IAMInstanceProfile',
    :Type => "AWS::IAM::InstanceProfile",
    :Properties => {
      :Path => "/",
      :Roles => [ get_att('Role','Outputs.IAMRole') ]
    }

  # The instance auto scaling group

  resource 'ServerGroup',
    :Type => 'AWS::AutoScaling::AutoScalingGroup',
    :Properties => {
      :VPCZoneIdentifier => ref('PrivateSubnets'),
      :LaunchConfigurationName => ref('LaunchConfig'),
      :MinSize => '1',
      :MaxSize => '3',
      :DesiredCapacity => '3',
      :Tags => [
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'ec2',ref('AnsibleRole')), :PropagateAtLaunch => "true"}, 
        { :Key => 'Environment', :Value => ref('EnvironmentName'), :PropagateAtLaunch => "true"}, 
        { :Key => 'AnsibleRole', :Value => ref('AnsibleRole'), :PropagateAtLaunch => "true"}, 
        { :Key => 'Application', :Value => ref('Application'), :PropagateAtLaunch => "true"}, 
        { :Key => 'category', :Value => ref('Category'), :PropagateAtLaunch => "true"}, 
        { :Key => 'BucketName', :Value => ref('BucketName'), :PropagateAtLaunch => "true"}, 
        { :Key => 'Purpose', :Value => ref('Purpose'), :PropagateAtLaunch => "true"}, 
      ]
    }

  resource 'LaunchConfig',
    :Type => 'AWS::AutoScaling::LaunchConfiguration',
    :Properties => {
      :AssociatePublicIpAddress => "false",
      :IamInstanceProfile => ref('IAMInstanceProfile'),
      :KeyName => ref('KeyName'),
      :ImageId => ref('ImageId'),
      :SecurityGroups => [ 
        get_att('SecurityGroup','Outputs.SecurityGroup'),
        ref('DefaultSecurityGroup')
      ],
      :InstanceType => ref('InstanceType'),
      :UserData => base64(interpolate(file('user-data/ubuntu-bootstrap.sh'))),
      :BlockDeviceMappings => [
        {
          :DeviceName => "/dev/sda1",
          :Ebs => { :VolumeSize => "100" } 
        },
      ]
    }

end.exec!
