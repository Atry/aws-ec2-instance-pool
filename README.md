# aws-ec2-instance-pool

**aws-ec2-instance-pool** is a cross-platform [Haxe](http://haxe.org/) library that manages AWS EC2 instances' lifecycles on demand.

## Installation

```
haxelib install aws-ec2-instance-pool
```

## Usage

### Creating a `Ec2InstancePool`
``` haxe
#if nodejs
  // awsEc2InstancePool.EC2 is compatible with AWS SDK for JavaScript.
  // See https://github.com/aws/aws-sdk-js
  var AWS = js.Node.require("aws-sdk");
  var ec2:awsEc2InstancePool.EC2 = Type.createInstance(AWS.EC2, [{}]);
#else
  // You need to adapt AWS SDK to awsEc2InstancePool.EC2,
  // if you are on a platform other than JavaScript.
  var ec2:awsEc2InstancePool.EC2 = new YourOwnAwsEc2ApiImplementation();
#end

var retryInterval = 15000;
var idleTimeout = 300000;
var terminationTimeout = 60000;
var ec2InstanceOptions = {
  ImageId: 'ami-xxxxxxxx',
  InstanceType: 't1.micro',
  MaxCount: 1,
  MinCount: 1,
  SecurityGroups: [ "launch-wizard-1" ]
};
var maxWorkloads = 5;

var pool = new awsEc2InstancePool.Ec2InstancePool(
  function() {
    return new awsEc2InstancePool.Ec2InstanceLifecycle(
      ec2,
      retryInterval,
      idleTimeout,
      terminationTimeout,
      ec2InstanceOptions);
  },
  maxWorkloads);
```

### Using an EC2 instance

``` haxe
// Acquire the EC2 instance before using it
pool.acquire(function(instanceIndex:Int, instanceHostName:String):Void {

  // Using the EC2 instance
  ...

  // Release the EC2 instance after using it
  pool.release(instanceIndex);
});
```
