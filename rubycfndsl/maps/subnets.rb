# Total CIDR provisioned for this service:
#
# 10.183.144.0/21 => production
#
# 10.140.16.0/21 => non production
#   10.140.16.0/23 => INT VPC
#   10.140.32.0/23 => TEST VPC
#   10.140.48.0/23 => STAGE VPC
#   10.140.64.0/23 => PROD VPC

mapping 'INT',
  :VPC                => { :CIDR => '10.140.16.0/23' },
  :PublicAZ1          => { :CIDR => '10.140.16.0/25' },
  :PublicAZ2          => { :CIDR => '10.140.16.128/25' },
  :AppTierPrivateAZ1  => { :CIDR => '10.140.17.0/25' },
  :AppTierPrivateAZ2  => { :CIDR => '10.140.17.128/25' },
  :DbTierPrivateAZ1   => { :CIDR => '10.140.17.0/25' },
  :DbTierPrivateAZ2   => { :CIDR => '10.140.17.128/25' }

mapping 'TEST',
  :VPC                => { :CIDR => '10.140.32.0/23' },
  :PublicAZ1          => { :CIDR => '10.140.32.0/25' },
  :PublicAZ2          => { :CIDR => '10.140.32.128/25' },
  :AppTierPrivateAZ1  => { :CIDR => '10.140.32.0/25' },
  :AppTierPrivateAZ2  => { :CIDR => '10.140.32.128/25' },
  :DbTierPrivateAZ1   => { :CIDR => '10.140.32.0/25' },
  :DbTierPrivateAZ2   => { :CIDR => '10.140.32.128/25' }

mapping 'STAGE',
  :VPC                => { :CIDR => '10.140.48.0/23' },
  :PublicAZ1          => { :CIDR => '10.140.48.0/25' },
  :PublicAZ2          => { :CIDR => '10.140.48.128/25' },
  :AppTierPrivateAZ1  => { :CIDR => '10.140.48.0/25' },
  :AppTierPrivateAZ2  => { :CIDR => '10.140.48.128/25' },
  :DbTierPrivateAZ1   => { :CIDR => '10.140.48.0/25' },
  :DbTierPrivateAZ2   => { :CIDR => '10.140.48.128/25' }

mapping 'PROD',
  :VPC                => { :CIDR => '10.140.64.0/23' },
  :PublicAZ1          => { :CIDR => '10.140.64.0/25' },
  :PublicAZ2          => { :CIDR => '10.140.64.128/25' },
  :AppTierPrivateAZ1  => { :CIDR => '10.140.64.0/25' },
  :AppTierPrivateAZ2  => { :CIDR => '10.140.64.128/25' },
  :DbTierPrivateAZ1   => { :CIDR => '10.140.64.0/25' },
  :DbTierPrivateAZ2   => { :CIDR => '10.140.64.128/25' }
