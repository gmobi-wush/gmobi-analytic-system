#! /bin/bash
aws emr create-cluster --termination-protected --applications Name=Spark \
  --bootstrap-actions '
  [
    {
      "Path":"s3://cn-north-1.elasticmapreduce/bootstrap-actions/run-if",
      "Args":["instance.isMaster=true","aws","s3","sync","s3://gmobi-emr-bootstrap","/home/hadoop"],
      "Name":"Sync Gmobi Bootstrap"
    },
    {
      "Path":"s3://cn-north-1.elasticmapreduce/bootstrap-actions/run-if",
      "Args":["instance.isMaster=true","bash","/home/hadoop/R/emr-bootstrap-R.sh","2>emr-bootstrap-R.err"],
      "Name":"Install rstudio-server"
    }
  ]' \
  --ec2-attributes '{"KeyName":"china","InstanceProfile":"EMR_EC2_DefaultRole","SubnetId":"subnet-09525b7d","EmrManagedSlaveSecurityGroup":"sg-b4e9add1","EmrManagedMasterSecurityGroup":"sg-b5e9add0"}' \
  --service-role EMR_DefaultRole --enable-debugging --release-label emr-4.2.0 --log-uri 's3n://aws-logs-289584829664-cn-north-1/elasticmapreduce/' --name 'gmobi-sparkR-mongo' \
  --instance-groups '[{"InstanceCount":1,"InstanceGroupType":"CORE","InstanceType":"m3.xlarge","Name":"Core instance group - 2"},{"InstanceCount":1,"InstanceGroupType":"MASTER","InstanceType":"m3.xlarge","Name":"Master instance group - 1"}]' \
  --configurations '[{"Classification":"mapred-site","Properties":{"mapreduce.jobtracker.system.dir.permission":"777"},"Configurations":[]}]' \
  --region cn-north-1
