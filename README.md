aws-asg-restart
===============

This script can be used to restart all instances in an AWS auto-scaling group.  Reasons you may want to do this:
* You have made a change to the underlying launch-config, and want to replace the currently running instances with new instances running the new launch config
* Your user-data file automatically fetches the latest version of your app, and you want to replace instances running the old version of the app with instances running the new version


Features:
* Each instance is removed from the elastic-load-balancer before being terminated, in order that traffic isn't being routed to the instance as it is being terminated
* There is a delay in between each instance termination, in order for the auto-scaling group to bring up replacement instances
