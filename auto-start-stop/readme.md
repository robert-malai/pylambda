## Auto Start-Stop

Will start or stop EC2 instances based on their cron schedule. Will enforce to be at least 60 minutes on or off.

In order to judge if an instance should be started or stopped, the following visual representation helps us to derive
the rule based on prev and next start / stop times:

![Timeline of start/stop triggers](doc/start-stop-times.png "Timeline of prev/next start/stop triggers")

We're observing that the usecases A and C are similar. Usecase B gives us a hint on how to lay down the conditions for 
start / stop triggers in order for an instance to be on: `prev_stop < prev_start` or `next_stop < next_start`.