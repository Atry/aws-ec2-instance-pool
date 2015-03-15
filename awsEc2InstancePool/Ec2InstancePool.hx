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
import com.dongxiguo.continuation.utils.Tuple.pair;

@:build(com.dongxiguo.continuation.Continuation.cpsByMeta(":async"))
class Ec2InstancePool
{
  var instanceLifecycles = new Map<Int, Ec2InstanceLifecycle>();
  var instanceLifecycleFactory:Void->Ec2InstanceLifecycle;
  var scheduler:Scheduler;

  public function new(instanceLifecycleFactory:Void->Ec2InstanceLifecycle, maxTasksPerInstance:Int) {
    this.instanceLifecycleFactory = instanceLifecycleFactory;
    this.scheduler = new Scheduler(maxTasksPerInstance);
  }

  @:async
  public function acquire() {
    // Acquire a idle EC2 instance index
    var instanceIndex = scheduler.acquire();

    // Create an EC2 instance if the index is new.
    var existingInstanceLifecycle = instanceLifecycles[instanceIndex];
    var instanceLifecycle = if (existingInstanceLifecycle != null) {
      existingInstanceLifecycle;
    } else {
      instanceLifecycles[instanceIndex] = instanceLifecycleFactory();
    }

    // Make sure the instance is ready.
    var instanceHostName = @await instanceLifecycle.acquire();

    return @await pair(instanceIndex, instanceHostName);
  }

  public function release(instanceIndex:Int):Void {
    // Release the instance
    instanceLifecycles[instanceIndex].release();
    scheduler.release(instanceIndex);
  }

}