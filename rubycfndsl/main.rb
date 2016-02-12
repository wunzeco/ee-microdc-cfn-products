#!/usr/bin/env ruby

# Standard cfn-ruby libraries:
require 'pry'
require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

# Set environment
environment = ENV['EV_ENVIRONMENT'] || fail('error: no EV_ENVIRONMENT provided')
application = ENV['EV_APPLICATION'] || fail('error: no EV_APPLICATION provided')
bucketname = ENV['EV_BUCKET_NAME'] || fail('error: no EV_BUCKET_NAME provided')
region = ENV['AWS_DEFAULT_REGION'] || 'eu-west-1'
category = 'eemicrodc'

template do

  # Format Version:
  
  value :AWSTemplateFormatVersion => '2010-09-09'

  # Description:
  
  value :Description => "MAIN VPC Configuration for #{application.upcase}"

  ####################################################################################################
  ####################################################################################################
  #
  # Parameters
  #
  ####################################################################################################
  ####################################################################################################
  
  # Default Mandatory Parameters

  parameter 'EnvironmentName',
    :Default => environment,
    :Description => 'The environment Name',
    :Type => 'String',
    :MinLength => '1',
    :MaxLength => '64',
    :AllowedPattern => '[a-zA-Z][a-zA-Z0-9]*',
    :ConstraintDescription => 'must begin with a letter and contain only alphanumeric characters.'

  parameter 'Application',
    :Default => application,
    :Description => 'The Project Name',
    :Type => 'String',
    :MinLength => '1',
    :MaxLength => '64',
    :AllowedPattern => '[a-zA-Z][a-zA-Z0-9]*',
    :ConstraintDescription => 'must begin with a letter and contain only alphanumeric characters.'

  parameter 'BucketName',
    :Default => bucketname,
    :Description => 'The Project Name',
    :Type => 'String',
    :MinLength => '1',
    :MaxLength => '64',
    :AllowedPattern => '[a-zA-Z0-9-\.]*',
    :ConstraintDescription => 'must begin with a letter and contain only alphanumeric characters.'

  parameter 'Category',
    :Default => category,
    :Description => 'Category for billing purpose',
    :Type => 'String',
    :MinLength => '1',
    :MaxLength => '64',
    :AllowedPattern => '[a-zA-Z0-9-\.]*',
    :ConstraintDescription => 'must begin with a letter and contain only alphanumeric characters.'

  # Specific parameters

  parameter 'AvailabilityZone1',
    :Description => 'First Availability Zone',
    :Type => 'String',
    :Default => "#{region}a",
    :AllowedValues => [ 'eu-west-1a', 'eu-west-1b', 'eu-west-1c', 'eu-central-1a', 'eu-central-1b', 
                        'us-east-1a', 'us-east-1b', 'us-east-1c', 'us-west-1b', 'us-west-1c' ],
    :ConstraintDescription => 'must be a valid availability zone'

  parameter 'AvailabilityZone2',
    :Description => 'Second Availability Zone',
    :Type => 'String',
    :Default => "#{region}b",
    :AllowedValues => [ 'eu-west-1a', 'eu-west-1b', 'eu-west-1c', 'eu-central-1a', 'eu-central-1b', 
                        'us-east-1a', 'us-east-1b', 'us-east-1c', 'us-west-1b', 'us-west-1c' ],
    :ConstraintDescription => 'must be a valid availability zone'

  # Size Parameters
  
  parameter 'AZDesiredCapacity',
    :Description => 'Number of instances per stack',
    :Type => 'String',
    :Default => 2,
    :AllowedPattern => '[0-9]*',
    :ConstraintDescription => 'Must be a number between 1 and 10'
  

  ####################################################################################################
  ####################################################################################################
  #
  # Conditions
  #
  ####################################################################################################
  ####################################################################################################
 
  condition 'CreateMultipleAZs',
    equal(ref('AZDesiredCapacity'),2)

  ####################################################################################################
  ####################################################################################################
  #
  # Mappings including Subnets
  #
  ####################################################################################################
  ####################################################################################################
 
  Dir[File.join(File.expand_path(File.dirname($PROGRAM_NAME)),'maps','*')].each do |map|
    eval File.read(map)
  end

  ####################################################################################################
  ####################################################################################################
  #
  # VPC STANDARD Resources
  #
  ####################################################################################################
  ####################################################################################################

  resource 'VPC',
    :Type => 'AWS::EC2::VPC',
    :Properties => {
      :CidrBlock => find_in_map(ref('EnvironmentName'), 'VPC', 'CIDR'),
      :EnableDnsSupport => 'true',
      :EnableDnsHostnames => 'true',
      :Tags => [ 
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'vpc') }, 
        { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
        { :Key => 'Application', :Value => ref('Application') }, 
        { :Key => 'Category', :Value => ref('Category') }, 
      ],
    }

  resource 'InternetGateway',
    :Type => 'AWS::EC2::InternetGateway',
    :Properties => {
      :Tags => [ 
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'igw') }, 
        { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
        { :Key => 'Application', :Value => ref('Application') }, 
        { :Key => 'Category', :Value => ref('Category') }, 
      ],
    }

  resource 'GatewayToInternet',
    :Type => 'AWS::EC2::VPCGatewayAttachment',
    :Properties => {
      :VpcId => ref('VPC'),
      :InternetGatewayId => ref('InternetGateway'),
    }

  ####################################################################################################
  # Public Subnets definition and routing tables

  resource 'PublicSubnetAZ1',
    :Type => 'AWS::EC2::Subnet',
    :Properties => {
      :VpcId => ref('VPC'),
      :CidrBlock => find_in_map(ref('EnvironmentName'), 'PublicAZ1', 'CIDR'),
      :AvailabilityZone => ref('AvailabilityZone1'),
      :Tags => [
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'sn','publicAZ1') }, 
        { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
        { :Key => 'Application', :Value => ref('Application') }, 
        { :Key => 'Category', :Value => ref('Category') }, 
        { :Key => 'Purpose', :Value => 'publicAZ1' },
      ],
    }

  resource 'PublicSubnetAZ2',
    :Type => 'AWS::EC2::Subnet',
    :Condition => "CreateMultipleAZs",
    :Properties => {
      :VpcId => ref('VPC'),
      :CidrBlock => find_in_map(ref('EnvironmentName'), 'PublicAZ2', 'CIDR'),
      :AvailabilityZone => ref('AvailabilityZone2'),
      :Tags => [
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'sn','publicAZ2',) }, 
        { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
        { :Key => 'Application', :Value => ref('Application') }, 
        { :Key => 'Category', :Value => ref('Category') }, 
        { :Key => 'Purpose', :Value => 'publicAZ2' },
      ],
    }


  resource 'PublicRouteTable',
    :Type => 'AWS::EC2::RouteTable',
    :Properties => {
      :VpcId => ref('VPC'),
      :Tags => [
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'rt','public') }, 
        { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
        { :Key => 'Application', :Value => ref('Application') }, 
        { :Key => 'Category', :Value => ref('Category') }, 
        { :Key => 'Purpose', :Value => 'public' },
      ],
    }

  resource 'PublicRoute',
    :Type => 'AWS::EC2::Route',
    :Properties => {
      :RouteTableId => ref('PublicRouteTable'),
      :DestinationCidrBlock => '0.0.0.0/0',
      :GatewayId => ref('InternetGateway'),
  }

  resource 'PublicSubnetRouteTableAssociationAZ1',
    :Type => 'AWS::EC2::SubnetRouteTableAssociation',
    :Properties => {
      :SubnetId => ref('PublicSubnetAZ1'),
      :RouteTableId => ref('PublicRouteTable'),
  }

  resource 'PublicSubnetRouteTableAssociationAZ2',
    :Condition => "CreateMultipleAZs",
    :Type => 'AWS::EC2::SubnetRouteTableAssociation',
    :Properties => {
      :SubnetId => ref('PublicSubnetAZ2'),
      :RouteTableId => ref('PublicRouteTable'),
  }

  ####################################################################################################
  # Nat Instances definition

  resource "DefaultSecurityGroup",
    :Type => "AWS::CloudFormation::Stack",
    :Properties => {
      :TemplateURL => join('/', 'https://s3.amazonaws.com', ref('BucketName'), ref('Application'),
                           ref('EnvironmentName'), 'cloudformation', join('','securitygroup_default.template')),
      :Parameters => {
        :EnvironmentName => ref('EnvironmentName'),
        :Application => ref('Application'),
        :Category => ref('Category'),
        :VPC => ref('VPC'),
      }
    }

  resource "NATIAMRole",
    :Type => "AWS::CloudFormation::Stack",
    :Properties => {
      :TemplateURL => join("/","https://s3.amazonaws.com",ref('BucketName'),ref('Application'),
                           ref('EnvironmentName'),'cloudformation','role_nat.template'),
      :Parameters => {
        :EnvironmentName => ref('EnvironmentName'),
        :Application => ref('Application'),
        :BucketName => ref('BucketName'),
        :AnsibleRole => "nat",
      }
    }

  resource "NATSecurityGroup",
    :Type => "AWS::CloudFormation::Stack",
    :Properties => {
      :TemplateURL => join("/","https://s3.amazonaws.com",ref('BucketName'),ref('Application'),
                            ref('EnvironmentName'),'cloudformation','securitygroup_nat.template'),
      :Parameters => {
        :EnvironmentName => ref('EnvironmentName'),
        :Application => ref('Application'),
        :Category => ref('Category'),
        :VPC => ref('VPC'),
        :Purpose => 'nat',
      }
    }
 
  resource "NatEc2InstanceAZ1v0",
    :Type => "AWS::CloudFormation::Stack",
    :Properties => {
      :TemplateURL => join("/","https://s3.amazonaws.com",ref('BucketName'),ref('Application'),
                           ref('EnvironmentName'),'cloudformation','ec2_stack_nat.template'),
      :Parameters => {
        :EnvironmentName => ref('EnvironmentName'),
        :Application => ref('Application'),
        :Category => ref('Category'),
        :VPC => ref('VPC'),
        :SubnetId => ref('PublicSubnetAZ1'),
        :ImageId => find_in_map('AMI', region, 'NAT'),
        :InstanceType => 't2.micro',
        :KeyName => 'eemicrodc',
        :Purpose => 'NAT-Gateway',
        :BucketName => ref('BucketName'),
        :AnsibleRole => "nat",
        :Role => get_att('NATIAMRole','Outputs.IAMRole'),
        :SecurityGroup => join(',', get_att('DefaultSecurityGroup','Outputs.SecurityGroup'),
                               get_att('NATSecurityGroup','Outputs.SecurityGroup'))
        
      }
    }

  resource "NatEc2InstanceAZ2v0",
    :Condition => "CreateMultipleAZs",
    :Type => "AWS::CloudFormation::Stack",
    :Properties => {
      :TemplateURL => join("/","https://s3.amazonaws.com",ref('BucketName'),ref('Application'),
                           ref('EnvironmentName'),'cloudformation','ec2_stack_nat.template'),
      :Parameters => {
        :EnvironmentName => ref('EnvironmentName'),
        :Application => ref('Application'),
        :Category => ref('Category'),
        :VPC => ref('VPC'),
        :SubnetId => ref('PublicSubnetAZ2'),
        :ImageId => find_in_map('AMI', region, 'NAT'),
        :InstanceType => 't2.micro',
        :KeyName => 'eemicrodc',
        :Purpose => 'NAT-Gateway',
        :BucketName => ref('BucketName'),
        :AnsibleRole => "nat",
        :Role => get_att('NATIAMRole','Outputs.IAMRole'),
        :SecurityGroup => join(',', get_att('DefaultSecurityGroup','Outputs.SecurityGroup'),
                               get_att('NATSecurityGroup','Outputs.SecurityGroup'))
      }
    }
 
 
  # ###################################################################################################
  # Private Subnets and routing tables

  # Subnets

  resource 'AppTierPrivateSubnetAZ1',
    :Type => 'AWS::EC2::Subnet',
    :Properties => {
      :VpcId => ref('VPC'),
      :CidrBlock => find_in_map(ref('EnvironmentName'), 'AppTierPrivateAZ1', 'CIDR'),
      :AvailabilityZone => ref('AvailabilityZone1'),
      :Tags => [
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'sn','apptier','privateAZ1') }, 
        { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
        { :Key => 'Application', :Value => ref('Application') }, 
        { :Key => 'Category', :Value => ref('Category') }, 
        { :Key => 'Purpose', :Value => 'privateAZ1' },
      ],
  }

  # Create subnet on AZ2 regardless. This is needed in case we need to 
  # Deploy an RDS instance on the VPC, which requires multiple AZs
  resource 'AppTierPrivateSubnetAZ2',
    :Type => 'AWS::EC2::Subnet',
    :Properties => {
      :VpcId => ref('VPC'),
      :CidrBlock => find_in_map(ref('EnvironmentName'), 'AppTierPrivateAZ2', 'CIDR'),
      :AvailabilityZone => ref('AvailabilityZone2'),
      :Tags => [
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'sn','apptier','privateAZ2') }, 
        { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
        { :Key => 'Application', :Value => ref('Application') }, 
        { :Key => 'Category', :Value => ref('Category') }, 
        { :Key => 'Purpose', :Value => 'privateAZ2' },
      ],
    }

  resource 'DbTierPrivateSubnetAZ1',
    :Type => 'AWS::EC2::Subnet',
    :Properties => {
      :VpcId => ref('VPC'),
      :CidrBlock => find_in_map(ref('EnvironmentName'), 'DbTierPrivateAZ1', 'CIDR'),
      :AvailabilityZone => ref('AvailabilityZone1'),
      :Tags => [
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'sn','dbtier','privateAZ1') }, 
        { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
        { :Key => 'Application', :Value => ref('Application') }, 
        { :Key => 'Category', :Value => ref('Category') }, 
        { :Key => 'Purpose', :Value => 'privateAZ1' },
      ],
  }

  # Create subnet on AZ2 regardless. This is needed in case we need to 
  # Deploy an RDS instance on the VPC, which requires multiple AZs
  resource 'DbTierPrivateSubnetAZ2',
    :Type => 'AWS::EC2::Subnet',
    :Properties => {
      :VpcId => ref('VPC'),
      :CidrBlock => find_in_map(ref('EnvironmentName'), 'DbTierPrivateAZ2', 'CIDR'),
      :AvailabilityZone => ref('AvailabilityZone2'),
      :Tags => [
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'sn','dbtier','privateAZ2') }, 
        { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
        { :Key => 'Application', :Value => ref('Application') }, 
        { :Key => 'Category', :Value => ref('Category') }, 
        { :Key => 'Purpose', :Value => 'privateAZ2' },
      ],
    }

  # Routing Tables:
    
  resource 'PrivateRouteTableAZ1',
    :Type => 'AWS::EC2::RouteTable',
    :Properties => {
      :VpcId => ref('VPC'),
      :Tags => [
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'rt','privateAZ1') }, 
        { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
        { :Key => 'Application', :Value => ref('Application') }, 
        { :Key => 'Category', :Value => ref('Category') }, 
        { :Key => 'Purpose', :Value => 'privateAZ1' },
        { :Key => 'AvailabilityZone', :Value => ref('AvailabilityZone1') },
      ],
    }

  resource 'PrivateRouteTableAZ2',
    :Type => 'AWS::EC2::RouteTable',
    :Condition => "CreateMultipleAZs",
    :Properties => {
      :VpcId => ref('VPC'),
      :Tags => [
        { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'rt','privateAZ2') }, 
        { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
        { :Key => 'Application', :Value => ref('Application') }, 
        { :Key => 'Category', :Value => ref('Category') }, 
        { :Key => 'Purpose', :Value => 'privateAZ2' },
        { :Key => 'AvailabilityZone', :Value => ref('AvailabilityZone2') },
      ],
    }

  # Routes:

  resource 'PrivateRouteAZ1',
    :Type => 'AWS::EC2::Route',
    :Properties => {
      :RouteTableId => ref('PrivateRouteTableAZ1'),
      :DestinationCidrBlock => '0.0.0.0/0',
      :InstanceId => get_att('NatEc2InstanceAZ1v0','Outputs.EC2Instance'),
    }

  resource 'PrivateRouteAZ2',
    :Condition => "CreateMultipleAZs",
    :Type => 'AWS::EC2::Route',
    :Properties => {
      :RouteTableId => ref('PrivateRouteTableAZ2'),
      :DestinationCidrBlock => '0.0.0.0/0',
      :InstanceId => get_att('NatEc2InstanceAZ2v0','Outputs.EC2Instance'),
    }

  # Route table asociation:

  resource 'AppTierPrivateSubnetRouteTableAssociationAZ1',
    :Type => 'AWS::EC2::SubnetRouteTableAssociation',
    :Properties => {
      :SubnetId => ref('AppTierPrivateSubnetAZ1'),
      :RouteTableId => ref('PrivateRouteTableAZ1'),
  }

  resource 'AppTierPrivateSubnetRouteTableAssociationAZ2',
    :Condition => "CreateMultipleAZs",
    :Type => 'AWS::EC2::SubnetRouteTableAssociation',
    :Properties => {
      :SubnetId => ref('AppTierPrivateSubnetAZ2'),
      :RouteTableId => ref('PrivateRouteTableAZ2'),
    }

  resource 'DbTierPrivateSubnetRouteTableAssociationAZ1',
    :Type => 'AWS::EC2::SubnetRouteTableAssociation',
    :Properties => {
      :SubnetId => ref('DbTierPrivateSubnetAZ1'),
      :RouteTableId => ref('PrivateRouteTableAZ1'),
  }

  resource 'DbTierPrivateSubnetRouteTableAssociationAZ2',
    :Condition => "CreateMultipleAZs",
    :Type => 'AWS::EC2::SubnetRouteTableAssociation',
    :Properties => {
      :SubnetId => ref('DbTierPrivateSubnetAZ2'),
      :RouteTableId => ref('PrivateRouteTableAZ2'),
    }

  # Hosted Zone:

  # resource 'HostedZone',
  #   :Type => "AWS::Route53::HostedZone",
  #   :Properties => {
  #     :HostedZoneConfig => {
  #       :Comment => join('',"Internal zone for ",ref('Application'),'-',ref("EnvironmentName"),' Environment')
  #     },
  #     :HostedZoneTags => [
  #       { :Key => 'Name', :Value => join('-',ref('Application'),ref('EnvironmentName'),'zone') }, 
  #       { :Key => 'Environment', :Value => ref('EnvironmentName') }, 
  #       { :Key => 'Application', :Value => ref('Application') }, 
  #       { :Key => 'Category', :Value => ref('Category') },
  #     ],
  #     :Name => join('.', ref('EnvironmentName'), ref('Application'), 'microdc', 'internal'),
  #     :VPCs => [ { :VPCId => ref('VPC'), :VPCRegion => region } ]
  #   }


  ####################################################################################################
  ####################################################################################################
  #
  # Application specific configurations
  #
  ####################################################################################################
  ####################################################################################################

  # ###################################################################################################
  # AppTier Stack definition

  resource "AppTierStack",
  :Type => "AWS::CloudFormation::Stack",
  :DependsOn => "NatEc2InstanceAZ1v0",
  :Properties => {
    :TemplateURL => join("/","https://s3.amazonaws.com",ref('BucketName'),ref('Application'),
                         ref('EnvironmentName'),'cloudformation','ec2_stack_apptier.template'),
    :Parameters => {
      :NatAZ1IpAddress => get_att('NatEc2InstanceAZ1v0','Outputs.PublicIp'),
      :NatAZ2IpAddress => fn_if('CreateMultipleAZs',
                                get_att('NatEc2InstanceAZ2v0','Outputs.PublicIp'),
                                get_att('NatEc2InstanceAZ1v0','Outputs.PublicIp')),
      :EnvironmentName => ref('EnvironmentName'),
      :Application => ref('Application'),
      :VPC => ref('VPC'),
      :PrivateSubnets => fn_if('CreateMultipleAZs',
                               join(',',ref('AppTierPrivateSubnetAZ1'),ref('AppTierPrivateSubnetAZ2')),
                               ref('AppTierPrivateSubnetAZ1')),
      :PublicSubnets => fn_if('CreateMultipleAZs',
                              join(',',ref('PublicSubnetAZ1'),ref('PublicSubnetAZ2')),
                              ref('PublicSubnetAZ1')),
      :ImageId => find_in_map('AMI', region, 'default'),
      :InstanceType => 'm3.medium',
      :KeyName => 'eemicrodc',
      :Purpose => 'apptier',
      :BucketName => ref('BucketName'),
      :AnsibleRole => "apptier",
      :Category => ref('Category'),
      :HostedZone => 'eemicrodc.equalexperts.com',
      :DefaultSecurityGroup => get_att('DefaultSecurityGroup','Outputs.SecurityGroup')
    }
  }

  # ###################################################################################################
  # DbTier Stack definition
  
  resource "DbTierStack",
  :Type => "AWS::CloudFormation::Stack",
  :DependsOn => "NatEc2InstanceAZ1v0",
  :Properties => {
    :TemplateURL => join("/","https://s3.amazonaws.com",ref('BucketName'),ref('Application'),
                         ref('EnvironmentName'),'cloudformation','ec2_stack_dbtier.template'),
    :Parameters => {
      :NatAZ1IpAddress => get_att('NatEc2InstanceAZ1v0','Outputs.PublicIp'),
      :NatAZ2IpAddress => fn_if('CreateMultipleAZs',
                                get_att('NatEc2InstanceAZ2v0','Outputs.PublicIp'),
                                get_att('NatEc2InstanceAZ1v0','Outputs.PublicIp')),
      :EnvironmentName => ref('EnvironmentName'),
      :Application => ref('Application'),
      :VPC => ref('VPC'),
      :PrivateSubnets => fn_if('CreateMultipleAZs',
                               join(',',ref('DbTierPrivateSubnetAZ1'),ref('DbTierPrivateSubnetAZ2')),
                               ref('DbTierPrivateSubnetAZ1')),
      :PublicSubnets => fn_if('CreateMultipleAZs',
                              join(',',ref('PublicSubnetAZ1'),ref('PublicSubnetAZ2')),
                              ref('PublicSubnetAZ1')),
      :ImageId => find_in_map('AMI', region, 'default'),
      :InstanceType => 'm3.medium',
      :KeyName => 'eemicrodc',
      :Purpose => 'dbtier',
      :BucketName => ref('BucketName'),
      :AnsibleRole => "dbtier",
      :Category => ref('Category'),
      :DefaultSecurityGroup => get_att('DefaultSecurityGroup','Outputs.SecurityGroup'),
      :AppTierSecurityGroup => get_att('AppTierStack','Outputs.SecurityGroup')
    }
  }


end.exec!
