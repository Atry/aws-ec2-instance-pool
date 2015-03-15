// Copyright (c) 2015, 杨博 (Yang Bo)
// All rights reserved.
//
// Author: 杨博 (Yang Bo) <pop.atry@gmail.com>
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * Neither the name of the <ORGANIZATION> nor the names of its contributors
//   may be used to endorse or promote products derived from this software
//   without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

package awsEc2InstancePool;

import com.dongxiguo.continuation.utils.Sleep.sleep;
import awsEc2InstancePool.EC2;
import haxe.Timer;

private typedef InstanceInformation = {
  PublicDnsName: String,
  InstanceId: String,
}

@:build(com.dongxiguo.continuation.Continuation.cpsByMeta(":async"))
class Ec2InstanceLifecycle
{

  var ec2:EC2;

  var retryInterval:Int;

  var idleTimeout:Int;

  var ec2InstanceConfiguration:Dynamic;

  @:allow(awsEc2InstancePool)
  var acquire(default, null):(String->Void)->Void;

  @:allow(awsEc2InstancePool)
  var release(default, null):Void->Void;

  public function new(ec2:EC2, retryInterval:Int, idleTimeout:Int, ec2InstanceConfiguration:Dynamic)
  {
    this.ec2 = ec2;
    this.retryInterval = retryInterval;
    this.idleTimeout = idleTimeout;
    this.ec2InstanceConfiguration = ec2InstanceConfiguration;

    // Start an instance when the first task comes
    acquire = function(firstTask) {
      creating([firstTask]);
    }
    release = function() {
      throw "Unable to release a instance before started.";
    };
  }

  @:async
  function retry<Error, Data>(operation:(Error->Data->Void)->Void):Data {
    var error, result = @await operation();
    if (error != null) {
      trace('Error calling an AWS API: $error, will retry in $retryInterval milliseconds.');
      @await sleep(retryInterval);
      return @await retry(operation);
    } else {
      return result;
    }
  }

  @:async
  function stopInstance(id:String):Void {
    trace('Stopping EC2 instance $id...');
    @await retry(ec2.stopInstances.bind({InstanceIds: [id]}));
    @await retry(ec2.waitFor.bind("instanceStopped", {InstanceIds: [id]}));
    trace('EC2 instance $id is stopped now.');
  }

  @:async
  function createInstance():InstanceInformation {
    trace("Createing a new EC2 instance...");
    var id = (@await retry(ec2.runInstances.bind(ec2InstanceConfiguration))).Instances[0].InstanceId;
    trace('EC2 instance $id is created, now booting...');
    var data = @await retry(ec2.waitFor.bind("instanceRunning", { InstanceIds: [id] } ));
    var runningInstance = data.Reservations[0].Instances[0];
    trace('EC2 instance $id is running now.');
    return runningInstance;
  }

  @:async
  function resumeInstance(id:String):InstanceInformation {
    trace("Resuming EC2 instance $id...");
    @await retry(ec2.startInstances.bind({InstanceIds: [id]}));
    trace('EC2 instance $id is booting...');
    var data = @await retry(ec2.waitFor.bind("instanceRunning", { InstanceIds: [id] } ));
    var runningInstance = data.Reservations[0].Instances[0];
    trace('EC2 instance $id is running now.');
    return runningInstance;
  }

  function resuming(instanceId:String, tasks:Array<String->Void>) {
    acquire = tasks.push;
    release = function() {
      throw "Unable to release a instance when it is resuming.";
    };
    resumeInstance(instanceId, function (newInstance) {
      dispathing(newInstance, tasks, tasks.length);
    });
  }

  function suspended(instanceId:String) {
    acquire = function(task) {
      resuming(instanceId, [task]);
    };
    release = function() {
      throw "Unable to release a instance when it is suspended.";
    };

  }

  function suspending(instanceId:String, tasks:Array<String->Void>) {
    acquire = tasks.push;
    release = function() {
      throw "Unable to release a instance when it is suspending.";
    };
    stopInstance(instanceId, function() {
      if (tasks.length > 0) {
        resuming(instanceId, tasks);
      } else {
        suspended(instanceId);
      }
    });
  }

  function idle(instance:InstanceInformation) {
    var timer = Timer.delay(function() {
      suspending(instance.InstanceId, []);
    }, idleTimeout);
    acquire = function (task) {
      timer.stop();
      dispathing(instance, [task], 1);
    }
    release = function() {
      throw "Unable to release a instance when it is idle.";
    };
  }

  function busy(instance:InstanceInformation, numPendingTask:Int) {
    acquire = function (task) {
      numPendingTask++;
      task(instance.PublicDnsName);
    };
    release = function () {
      if (--numPendingTask == 0) {
        idle(instance);
      }
    };
  }

  function dispathing(instance:InstanceInformation, tasks:Array<String->Void>, numPendingTasks:Int) {
    var newTasks = [];
    acquire = function(task) {
      numPendingTasks++;
      newTasks.push(task);
    }
    release = function() {
      numPendingTasks--;
    };
    for (task in tasks) {
      task(instance.PublicDnsName);
    }
    if (tasks.length > 0) {
      dispathing(instance, newTasks, numPendingTasks);
    } else if (numPendingTasks > 0) {
      busy(instance, numPendingTasks);
    } else {
      idle(instance);
    }
  }

  function creating(tasks:Array<String->Void>) {
    acquire = tasks.push;
    release = function() {
      throw "Unable to release a instance when it is creating.";
    };
    createInstance(function (instance:InstanceInformation) {
      dispathing(instance, tasks, tasks.length);
    });
  }

}