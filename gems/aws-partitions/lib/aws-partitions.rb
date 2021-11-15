# frozen_string_literal: true

require_relative 'aws-partitions/endpoint_provider'
require_relative 'aws-partitions/partition'
require_relative 'aws-partitions/partition_list'
require_relative 'aws-partitions/region'
require_relative 'aws-partitions/service'

require 'json'

module Aws

  # A {Partition} is a group of AWS {Region} and {Service} objects. You
  # can use a partition to determine what services are available in a region,
  # or what regions a service is available in.
  #
  # ## Partitions
  #
  # **AWS accounts are scoped to a single partition**. You can get a partition
  # by name. Valid partition names include:
  #
  # * `"aws"` - Public AWS partition
  # * `"aws-cn"` - AWS China
  # * `"aws-us-gov"` - AWS GovCloud
  #
  # To get a partition by name:
  #
  #     aws = Aws::Partitions.partition('aws')
  #
  # You can also enumerate all partitions:
  #
  #     Aws::Partitions.each do |partition|
  #       puts partition.name
  #     end
  #
  # ## Regions
  #
  # A {Partition} is divided up into one or more regions. For example, the
  # "aws" partition contains, "us-east-1", "us-west-1", etc. You can get
  # a region by name. Calling {Partition#region} will return an instance
  # of {Region}.
  #
  #     region = Aws::Partitions.partition('aws').region('us-west-2')
  #     region.name
  #     #=> "us-west-2"
  #
  # You can also enumerate all regions within a partition:
  #
  #     Aws::Partitions.partition('aws').regions.each do |region|
  #       puts region.name
  #     end
  #
  # Each {Region} object has a name, description and a list of services
  # available to that region:
  #
  #     us_west_2 = Aws::Partitions.partition('aws').region('us-west-2')
  #
  #     us_west_2.name #=> "us-west-2"
  #     us_west_2.description #=> "US West (Oregon)"
  #     us_west_2.partition_name "aws"
  #     us_west_2.services #=> #<Set: {"APIGateway", "AutoScaling", ... }
  #
  # To know if a service is available within a region, you can call `#include?`
  # on the set of service names:
  #
  #     region.services.include?('DynamoDB') #=> true/false
  #
  # The service name should be the service's module name as used by
  # the AWS SDK for Ruby. To find the complete list of supported
  # service names, see {Partition#services}.
  #
  # Its also possible to enumerate every service for every region in
  # every partition.
  #
  #     Aws::Partitions.partitions.each do |partition|
  #       partition.regions.each do |region|
  #         region.services.each do |service_name|
  #           puts "#{partition.name} -> #{region.name} -> #{service_name}"
  #         end
  #       end
  #     end
  #
  # ## Services
  #
  # A {Partition} has a list of services available. You can get a
  # single {Service} by name:
  #
  #     Aws::Partitions.partition('aws').service('DynamoDB')
  #
  # You can also enumerate all services in a partition:
  #
  #     Aws::Partitions.partition('aws').services.each do |service|
  #       puts service.name
  #     end
  #
  # Each {Service} object has a name, and information about regions
  # that service is available in.
  #
  #     service.name #=> "DynamoDB"
  #     service.partition_name #=> "aws"
  #     service.regions #=> #<Set: {"us-east-1", "us-west-1", ... }
  #
  # Some services have multiple regions, and others have a single partition
  # wide region. For example, {Aws::IAM} has a single region in the "aws"
  # partition. The {Service#regionalized?} method indicates when this is
  # the case.
  #
  #     iam = Aws::Partitions.partition('aws').service('IAM')
  #
  #     iam.regionalized? #=> false
  #     service.partition_region #=> "aws-global"
  #
  # Its also possible to enumerate every region for every service in
  # every partition.
  #
  #     Aws::Partitions.partitions.each do |partition|
  #       partition.services.each do |service|
  #         service.regions.each do |region_name|
  #           puts "#{partition.name} -> #{region_name} -> #{service.name}"
  #         end
  #       end
  #     end
  #
  # ## Service Names
  #
  # {Service} names are those used by the the AWS SDK for Ruby. They
  # correspond to the service's module.
  #
  module Partitions

    class << self

      include Enumerable

      # @return [Enumerable<Partition>]
      def each(&block)
        default_partition_list.each(&block)
      end

      # Return the partition with the given name. A partition describes
      # the services and regions available in that partition.
      #
      #     aws = Aws::Partitions.partition('aws')
      #
      #     puts "Regions available in the aws partition:\n"
      #     aws.regions.each do |region|
      #       puts region.name
      #     end
      #
      #     puts "Services available in the aws partition:\n"
      #     aws.services.each do |services|
      #       puts services.name
      #     end
      #
      # @param [String] name The name of the partition to return.
      #   Valid names include "aws", "aws-cn", and "aws-us-gov".
      #
      # @return [Partition]
      #
      # @raise [ArgumentError] Raises an `ArgumentError` if a partition is
      #   not found with the given name. The error message contains a list
      #   of valid partition names.
      def partition(name)
        default_partition_list.partition(name)
      end

      # Returns an array with every partitions. A partition describes
      # the services and regions available in that partition.
      #
      #     Aws::Partitions.partitions.each do |partition|
      #
      #       puts "Regions available in #{partition.name}:\n"
      #       partition.regions.each do |region|
      #         puts region.name
      #       end
      #
      #       puts "Services available in #{partition.name}:\n"
      #       partition.services.each do |service|
      #         puts service.name
      #       end
      #     end
      #
      # @return [Enumerable<Partition>] Returns an enumerable of all
      #   known partitions.
      def partitions
        default_partition_list
      end

      # @param [Hash] new_partitions
      # @api private For internal use only.
      def add(new_partitions)
        new_partitions['partitions'].each do |partition|
          default_partition_list.add_partition(Partition.build(partition))
          defaults['partitions'] << partition
        end
      end

      # @api private For internal use only.
      def clear
        default_partition_list.clear
        defaults['partitions'].clear
      end

      # @return [PartitionList]
      # @api private
      def default_partition_list
        @default_partition_list ||= PartitionList.build(defaults)
      end

      # @return [Hash]
      # @api private
      def defaults
        @defaults ||= begin
          path = File.expand_path('../../partitions.json', __FILE__)
          defaults = JSON.parse(File.read(path), freeze: true)
          defaults.merge('partitions' => defaults['partitions'].dup)
        end
      end

      # @return [Hash<String,String>] Returns a map of service module names
      #   to their id as used in the endpoints.json document.
      # @api private For internal use only.
      def service_ids
        @service_ids ||= begin
          # service ids
          {
            'ACM' => 'acm',
            'ACMPCA' => 'acm-pca',
            'APIGateway' => 'apigateway',
            'AccessAnalyzer' => 'access-analyzer',
            'Account' => 'account',
            'AlexaForBusiness' => 'a4b',
            'Amplify' => 'amplify',
            'AmplifyBackend' => 'amplifybackend',
            'ApiGatewayManagementApi' => 'execute-api',
            'ApiGatewayV2' => 'apigateway',
            'AppConfig' => 'appconfig',
            'AppIntegrationsService' => 'app-integrations',
            'AppMesh' => 'appmesh',
            'AppRegistry' => 'servicecatalog-appregistry',
            'AppRunner' => 'apprunner',
            'AppStream' => 'appstream2',
            'AppSync' => 'appsync',
            'Appflow' => 'appflow',
            'ApplicationAutoScaling' => 'application-autoscaling',
            'ApplicationCostProfiler' => 'application-cost-profiler',
            'ApplicationDiscoveryService' => 'discovery',
            'ApplicationInsights' => 'applicationinsights',
            'Athena' => 'athena',
            'AuditManager' => 'auditmanager',
            'AugmentedAIRuntime' => 'a2i-runtime.sagemaker',
            'AutoScaling' => 'autoscaling',
            'AutoScalingPlans' => 'autoscaling-plans',
            'Backup' => 'backup',
            'Batch' => 'batch',
            'Braket' => 'braket',
            'Budgets' => 'budgets',
            'Chime' => 'chime',
            'ChimeSDKIdentity' => 'identity-chime',
            'ChimeSDKMeetings' => 'meetings-chime',
            'ChimeSDKMessaging' => 'messaging-chime',
            'Cloud9' => 'cloud9',
            'CloudControlApi' => 'cloudcontrolapi',
            'CloudDirectory' => 'clouddirectory',
            'CloudFormation' => 'cloudformation',
            'CloudFront' => 'cloudfront',
            'CloudHSM' => 'cloudhsm',
            'CloudHSMV2' => 'cloudhsmv2',
            'CloudSearch' => 'cloudsearch',
            'CloudTrail' => 'cloudtrail',
            'CloudWatch' => 'monitoring',
            'CloudWatchEvents' => 'events',
            'CloudWatchLogs' => 'logs',
            'CodeArtifact' => 'codeartifact',
            'CodeBuild' => 'codebuild',
            'CodeCommit' => 'codecommit',
            'CodeDeploy' => 'codedeploy',
            'CodeGuruProfiler' => 'codeguru-profiler',
            'CodeGuruReviewer' => 'codeguru-reviewer',
            'CodePipeline' => 'codepipeline',
            'CodeStar' => 'codestar',
            'CodeStarNotifications' => 'codestar-notifications',
            'CodeStarconnections' => 'codestar-connections',
            'CognitoIdentity' => 'cognito-identity',
            'CognitoIdentityProvider' => 'cognito-idp',
            'CognitoSync' => 'cognito-sync',
            'Comprehend' => 'comprehend',
            'ComprehendMedical' => 'comprehendmedical',
            'ComputeOptimizer' => 'compute-optimizer',
            'ConfigService' => 'config',
            'Connect' => 'connect',
            'ConnectContactLens' => 'contact-lens',
            'ConnectParticipant' => 'participant.connect',
            'ConnectWisdomService' => 'wisdom',
            'CostExplorer' => 'ce',
            'CostandUsageReportService' => 'cur',
            'CustomerProfiles' => 'profile',
            'DAX' => 'dax',
            'DLM' => 'dlm',
            'DataExchange' => 'dataexchange',
            'DataPipeline' => 'datapipeline',
            'DataSync' => 'datasync',
            'DatabaseMigrationService' => 'dms',
            'Detective' => 'api.detective',
            'DevOpsGuru' => 'devops-guru',
            'DeviceFarm' => 'devicefarm',
            'DirectConnect' => 'directconnect',
            'DirectoryService' => 'ds',
            'DocDB' => 'rds',
            'DynamoDB' => 'dynamodb',
            'DynamoDBStreams' => 'streams.dynamodb',
            'EBS' => 'ebs',
            'EC2' => 'ec2',
            'EC2InstanceConnect' => 'ec2-instance-connect',
            'ECR' => 'api.ecr',
            'ECRPublic' => 'api.ecr-public',
            'ECS' => 'ecs',
            'EFS' => 'elasticfilesystem',
            'EKS' => 'eks',
            'EMR' => 'elasticmapreduce',
            'EMRContainers' => 'emr-containers',
            'ElastiCache' => 'elasticache',
            'ElasticBeanstalk' => 'elasticbeanstalk',
            'ElasticInference' => 'api.elastic-inference',
            'ElasticLoadBalancing' => 'elasticloadbalancing',
            'ElasticLoadBalancingV2' => 'elasticloadbalancing',
            'ElasticTranscoder' => 'elastictranscoder',
            'ElasticsearchService' => 'es',
            'EventBridge' => 'events',
            'FIS' => 'fis',
            'FMS' => 'fms',
            'FSx' => 'fsx',
            'FinSpaceData' => 'finspace-api',
            'Finspace' => 'finspace',
            'Firehose' => 'firehose',
            'ForecastQueryService' => 'forecastquery',
            'ForecastService' => 'forecast',
            'FraudDetector' => 'frauddetector',
            'GameLift' => 'gamelift',
            'Glacier' => 'glacier',
            'GlobalAccelerator' => 'globalaccelerator',
            'Glue' => 'glue',
            'GlueDataBrew' => 'databrew',
            'Greengrass' => 'greengrass',
            'GreengrassV2' => 'greengrass',
            'GroundStation' => 'groundstation',
            'GuardDuty' => 'guardduty',
            'Health' => 'health',
            'HealthLake' => 'healthlake',
            'Honeycode' => 'honeycode',
            'IAM' => 'iam',
            'IVS' => 'ivs',
            'IdentityStore' => 'identitystore',
            'Imagebuilder' => 'imagebuilder',
            'ImportExport' => 'importexport',
            'Inspector' => 'inspector',
            'IoT' => 'iot',
            'IoT1ClickDevicesService' => 'devices.iot1click',
            'IoT1ClickProjects' => 'projects.iot1click',
            'IoTAnalytics' => 'iotanalytics',
            'IoTDeviceAdvisor' => 'api.iotdeviceadvisor',
            'IoTEvents' => 'iotevents',
            'IoTEventsData' => 'data.iotevents',
            'IoTFleetHub' => 'api.fleethub.iot',
            'IoTJobsDataPlane' => 'data.jobs.iot',
            'IoTSecureTunneling' => 'api.tunneling.iot',
            'IoTSiteWise' => 'iotsitewise',
            'IoTThingsGraph' => 'iotthingsgraph',
            'IoTWireless' => 'api.iotwireless',
            'KMS' => 'kms',
            'Kafka' => 'kafka',
            'KafkaConnect' => 'kafkaconnect',
            'Kendra' => 'kendra',
            'Kinesis' => 'kinesis',
            'KinesisAnalytics' => 'kinesisanalytics',
            'KinesisAnalyticsV2' => 'kinesisanalytics',
            'KinesisVideo' => 'kinesisvideo',
            'KinesisVideoArchivedMedia' => 'kinesisvideo',
            'KinesisVideoMedia' => 'kinesisvideo',
            'KinesisVideoSignalingChannels' => 'kinesisvideo',
            'LakeFormation' => 'lakeformation',
            'Lambda' => 'lambda',
            'LambdaPreview' => 'lambda',
            'Lex' => 'runtime.lex',
            'LexModelBuildingService' => 'models.lex',
            'LexModelsV2' => 'models-v2-lex',
            'LexRuntimeV2' => 'runtime-v2-lex',
            'LicenseManager' => 'license-manager',
            'Lightsail' => 'lightsail',
            'LocationService' => 'geo',
            'LookoutEquipment' => 'lookoutequipment',
            'LookoutMetrics' => 'lookoutmetrics',
            'LookoutforVision' => 'lookoutvision',
            'MQ' => 'mq',
            'MTurk' => 'mturk-requester',
            'MWAA' => 'airflow',
            'MachineLearning' => 'machinelearning',
            'Macie' => 'macie',
            'Macie2' => 'macie2',
            'ManagedBlockchain' => 'managedblockchain',
            'ManagedGrafana' => 'grafana',
            'MarketplaceCatalog' => 'catalog.marketplace',
            'MarketplaceCommerceAnalytics' => 'marketplacecommerceanalytics',
            'MarketplaceEntitlementService' => 'entitlement.marketplace',
            'MarketplaceMetering' => 'metering.marketplace',
            'MediaConnect' => 'mediaconnect',
            'MediaConvert' => 'mediaconvert',
            'MediaLive' => 'medialive',
            'MediaPackage' => 'mediapackage',
            'MediaPackageVod' => 'mediapackage-vod',
            'MediaStore' => 'mediastore',
            'MediaStoreData' => 'data.mediastore',
            'MediaTailor' => 'api.mediatailor',
            'MemoryDB' => 'memory-db',
            'Mgn' => 'mgn',
            'MigrationHub' => 'mgh',
            'MigrationHubConfig' => 'migrationhub-config',
            'MigrationHubStrategyRecommendations' => 'migrationhub-strategy',
            'Mobile' => 'mobile',
            'Neptune' => 'rds',
            'NetworkFirewall' => 'network-firewall',
            'NetworkManager' => 'networkmanager',
            'NimbleStudio' => 'nimble',
            'OpenSearchService' => 'es',
            'OpsWorks' => 'opsworks',
            'OpsWorksCM' => 'opsworks-cm',
            'Organizations' => 'organizations',
            'Outposts' => 'outposts',
            'PI' => 'pi',
            'Panorama' => 'panorama',
            'Personalize' => 'personalize',
            'PersonalizeEvents' => 'personalize-events',
            'PersonalizeRuntime' => 'personalize-runtime',
            'Pinpoint' => 'pinpoint',
            'PinpointEmail' => 'email',
            'PinpointSMSVoice' => 'sms-voice.pinpoint',
            'Polly' => 'polly',
            'Pricing' => 'api.pricing',
            'PrometheusService' => 'aps',
            'Proton' => 'proton',
            'QLDB' => 'qldb',
            'QLDBSession' => 'session.qldb',
            'QuickSight' => 'quicksight',
            'RAM' => 'ram',
            'RDS' => 'rds',
            'RDSDataService' => 'rds-data',
            'Redshift' => 'redshift',
            'RedshiftDataAPIService' => 'redshift-data',
            'Rekognition' => 'rekognition',
            'ResilienceHub' => 'resiliencehub',
            'ResourceGroups' => 'resource-groups',
            'ResourceGroupsTaggingAPI' => 'tagging',
            'RoboMaker' => 'robomaker',
            'Route53' => 'route53',
            'Route53Domains' => 'route53domains',
            'Route53RecoveryCluster' => 'route53-recovery-cluster',
            'Route53RecoveryControlConfig' => 'route53-recovery-control-config',
            'Route53RecoveryReadiness' => 'route53-recovery-readiness',
            'Route53Resolver' => 'route53resolver',
            'S3' => 's3',
            'S3Control' => 's3-control',
            'S3Outposts' => 's3-outposts',
            'SES' => 'email',
            'SESV2' => 'email',
            'SMS' => 'sms',
            'SNS' => 'sns',
            'SQS' => 'sqs',
            'SSM' => 'ssm',
            'SSMContacts' => 'ssm-contacts',
            'SSMIncidents' => 'ssm-incidents',
            'SSO' => 'portal.sso',
            'SSOAdmin' => 'sso',
            'SSOOIDC' => 'oidc',
            'STS' => 'sts',
            'SWF' => 'swf',
            'SageMaker' => 'api.sagemaker',
            'SageMakerFeatureStoreRuntime' => 'featurestore-runtime.sagemaker',
            'SageMakerRuntime' => 'runtime.sagemaker',
            'SagemakerEdgeManager' => 'edge.sagemaker',
            'SavingsPlans' => 'savingsplans',
            'Schemas' => 'schemas',
            'SecretsManager' => 'secretsmanager',
            'SecurityHub' => 'securityhub',
            'ServerlessApplicationRepository' => 'serverlessrepo',
            'ServiceCatalog' => 'servicecatalog',
            'ServiceDiscovery' => 'servicediscovery',
            'ServiceQuotas' => 'servicequotas',
            'Shield' => 'shield',
            'Signer' => 'signer',
            'SimpleDB' => 'sdb',
            'SnowDeviceManagement' => 'snow-device-management',
            'Snowball' => 'snowball',
            'States' => 'states',
            'StorageGateway' => 'storagegateway',
            'Support' => 'support',
            'Synthetics' => 'synthetics',
            'Textract' => 'textract',
            'TimestreamQuery' => 'query.timestream',
            'TimestreamWrite' => 'ingest.timestream',
            'TranscribeService' => 'transcribe',
            'TranscribeStreamingService' => 'transcribestreaming',
            'Transfer' => 'transfer',
            'Translate' => 'translate',
            'VoiceID' => 'voiceid',
            'WAF' => 'waf',
            'WAFRegional' => 'waf-regional',
            'WAFV2' => 'wafv2',
            'WellArchitected' => 'wellarchitected',
            'WorkDocs' => 'workdocs',
            'WorkLink' => 'worklink',
            'WorkMail' => 'workmail',
            'WorkMailMessageFlow' => 'workmailmessageflow',
            'WorkSpaces' => 'workspaces',
            'XRay' => 'xray',
          }
          # end service ids
        end
      end

    end
  end
end
