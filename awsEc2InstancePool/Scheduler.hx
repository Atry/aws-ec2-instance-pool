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

import de.polygonal.ds.Prioritizable;
import de.polygonal.ds.PriorityQueue;

/**
 * Internal item for PriorityQueue
 */
private class QueueItem implements Prioritizable {

	/**
	 *  Used internal for <code>PriorityQueue</code>
	 */
	public var position:Int;

	/**
	 * Priority of the instance, smaller number has high priority.
   *
   * Always equals to index;
	 */
	public var priority:Float;

  public var index(get, never):Int;

  inline function get_index():Int {
    return cast priority;
  }

  public function new(index:Int) {
    priority = index;
  }

}

/**
 * A scheduler to allocate instance Indices for tasks.
 */
@:dox(hide)
class Scheduler {

  var numPendingTasksById:Array<Int> = [];

  var availableInstanceStatuses:PriorityQueue<QueueItem> = new PriorityQueue<QueueItem>(true);

  /**
   * The max tasks per instance
   */
  var maxTasksPerInstance:Int;

  /**
   * Create a new scheduler
   * @param maxTasksPerInstance the max tasks per instance
   */
  @:allow(awsEc2InstancePool)
  function new(maxTasksPerInstance:Int) {
    if (maxTasksPerInstance <= 0) {
      throw "maxTasksPerInstance must greater than zero!";
    }
    this.maxTasksPerInstance = maxTasksPerInstance;
  }

  /**
   * Acquires an available instance index for a new task.
   *
   * User will need to create the instance if it returns a new ID.
   *
   * @return an available instance index.
   */
  @:allow(awsEc2InstancePool)
  function acquire():Int {
    if (availableInstanceStatuses.isEmpty()) {
      // Returns a new instance index if no instance available.
      var newInstanceStatus = new QueueItem(numPendingTasksById.length);
      numPendingTasksById.push(1);
      if (maxTasksPerInstance > 1) {
        availableInstanceStatuses.enqueue(newInstanceStatus);
      }
      return newInstanceStatus.index;
    } else {
      // Returns the smallest index in all available instances.
      var instanceStatus = availableInstanceStatuses.peek();
      var numPendingTasks = ++numPendingTasksById[instanceStatus.index];
      if (numPendingTasks == maxTasksPerInstance) {
        availableInstanceStatuses.dequeue();
      }
      return instanceStatus.index;
    }
  }

  /**
   * Tells the scheduler a task on an instance is completed.
   *
   * @param index the index of the instance to release
   */
  @:allow(awsEc2InstancePool)
  function release(index:Int):Void {
    var originalNumPendingTasks = numPendingTasksById[index]--;
    if (maxTasksPerInstance == originalNumPendingTasks) {
      availableInstanceStatuses.enqueue(new QueueItem(index));
    }
  }

}