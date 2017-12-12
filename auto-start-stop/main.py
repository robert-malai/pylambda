"""
Auto start-stop functionality for the account's EC2 containers.

In order to enable the feature on a container, define the following configured tags on it:
  - ENABLE_TAG (start-stop:enable) with a value of 1, True, Yes of Enabled (case insensitive); optional, if missing we
  consider a True value for it.
  - START_TAG (start-stop:start) with a valid cron expression (5 or 6 columns)
  - STOP_TAG (start-stop:stop) with a valid cron expression

The cron expressions should depict scheduled uptime and downtimes greater than MIN_UPTIME (30 minutes) and
MIN_DOWNTIME (30 minutes)
"""

import logging
import os
from datetime import datetime, timedelta

import boto3
from croniter import croniter, CroniterBadDateError, CroniterBadCronError
from dateutil import tz
from dateutil.parser import parse as parse_datetime

# Script constants
ENABLE_TAG = 'start-stop:enable'
START_TAG = 'start-stop:start'
STOP_TAG = 'start-stop:stop'
ENVIRONMENT_TAG = 'Environment'
MIN_UPTIME = timedelta(minutes=60)
MIN_DOWNTIME = timedelta(minutes=60)

# Environment variables
TIMEZONE = tz.gettz(os.getenv('TIMEZONE', 'America/New_York'))


# One time initializations
logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.resource('ec2')


def get_instance_params(instance: ec2.Instance, now: datetime):
    """
    Will extract the start-stop parameters out of the instance's tags. Performs validation and will throw ValueError in
    case of any inconsistencies.
    :param now: the current timestamp, from the outer context
    :param instance: an ec2 instance resource
    :return: tuple of enabled, prev_start_time, prev_stop_time
    """
    try:
        start_tag = next(tag['Value'] for tag in instance.tags if tag['Key'] == START_TAG)
        stop_tag = next(tag['Value'] for tag in instance.tags if tag['Key'] == STOP_TAG)
        environment_tag = next((tag['Value'] for tag in instance.tags if tag['Key'] == ENVIRONMENT_TAG), None)
        enable_tag = next((tag['Value'].lower() for tag in instance.tags if tag['Key'] == ENABLE_TAG), "enabled")
    except StopIteration:
        raise ValueError(f"Problem reading the tag values on instance {instance.id}")
    else:
        if enable_tag in ["enabled", "yes", "true", "1", "on"]:
            try:
                prev_start_time, prev_stop_time = None, None
                next_start_time, next_stop_time = None, None
                if start_tag:
                    prev_start_time = croniter(start_tag, now, ret_type=datetime).get_prev()
                    next_start_time = croniter(start_tag, now, ret_type=datetime).get_next()

                if stop_tag:
                    prev_stop_time = croniter(stop_tag, now, ret_type=datetime).get_prev()
                    next_stop_time = croniter(stop_tag, now, ret_type=datetime).get_next()

            except (CroniterBadDateError, CroniterBadCronError, TypeError) as e:
                raise ValueError(f"Bad cron expression: {e}")
            else:
                if environment_tag and environment_tag.lower() in ['prod', 'production']:
                    raise ValueError("Production instances shouldn't be started / stopped automatically")
                if not stop_tag and not stop_tag:
                    raise ValueError("Bad cron expression: you have to provide at least one expression")
                if start_tag and int(start_tag.split()[0]) % 10 != 0:
                    raise ValueError("Bad cron expression: start schedule must be multiple of 10 minutes")
                if stop_tag and int(stop_tag.split()[0]) % 10 != 0:
                    raise ValueError("Bad cron expression: stop schedule must be multiple of 10 minutes")

                if start_tag and stop_tag:
                    # In this case we can validate the scheduled uptime and downtime of the instance
                    if prev_stop_time < prev_start_time:
                        scheduled_running_time = next_stop_time - prev_start_time
                        scheduled_stopped_time = prev_start_time - prev_stop_time
                    else:
                        scheduled_running_time = prev_stop_time - prev_start_time
                        scheduled_stopped_time = next_start_time - prev_stop_time

                    if scheduled_running_time < MIN_UPTIME:
                        raise ValueError(f"Bad cron expression: instance uptime ({scheduled_running_time}) is less "
                                         f"then minimum ({MIN_UPTIME})")

                    if scheduled_stopped_time < MIN_DOWNTIME:
                        raise ValueError(f"Bad cron expression: instance downtime ({scheduled_stopped_time}) is less "
                                         f"then minimum ({MIN_DOWNTIME})")

                return True, prev_start_time, prev_stop_time
        else:
            return False, None, None


def handler(event, context):
    """
    Will search through all the instances from this account filtered based on the tags START_TAG and STOP_TAG. Will
    extract the parameters out of the instance tags and then will run either in schedule detection mode or in trigger
    detection mode.
    """
    now = datetime.now(TIMEZONE)
    try:
        trigger = parse_datetime(event['time']).astimezone(TIMEZONE)
    except (TypeError, KeyError, ValueError):
        raise ValueError("Cannot read trigger event time")

    logger.info(f"Triggered execution at {trigger}")
    for instance in ec2.instances.filter(Filters=[{'Name': f'tag:{START_TAG}', 'Values': ['*']},
                                                  {'Name': f'tag:{STOP_TAG}', 'Values': ['*']}]):
        instance_name = next((tag['Value'] for tag in instance.tags if tag['Key'] == 'Name'), 'Unnamed')
        try:
            enabled, prev_start_time, prev_stop_time = get_instance_params(instance, now)
        except ValueError as e:
            logger.error(f"Wrong params values for '{instance.id}' ({instance_name}): {e}")
            continue
        else:
            logger.info(f"Inspecting instance {instance.id} ({instance_name}); auto start-stop: {enabled}")
            if enabled:
                if prev_start_time and prev_stop_time:
                    logger.info("Operate in schedule detection mode")

                    if prev_stop_time < prev_start_time:
                        # instance should be running
                        if instance.state['Name'] in ['stopped']:
                            logger.info(f"Starting instance {instance.id} ({instance_name})")
                            instance.start()
                    else:
                        # instance should be stopped
                        if instance.state['Name'] in ['running']:
                            logger.info(f"Stopping instance {instance.id} ({instance_name})")
                            instance.stop()
                else:
                    logger.info("Operate in trigger detection mode")

                    if prev_start_time and prev_start_time == trigger:
                        # we should start the instance
                        if instance.state['Name'] in ['stopped']:
                            logger.info(f"Starting instance {instance.id} ({instance_name})")
                            instance.start()

                    if prev_stop_time and prev_stop_time == trigger:
                        # we should stop the instance
                        if instance.state['Name'] in ['running']:
                            logger.info(f"Stopping instance {instance.id} ({instance_name})")
                            instance.stop()


if __name__ == '__main__' and 'LAMBDA_TASK_ROOT' not in os.environ:
    # Test code in order to check the functionality in a controlled virtual environment

    import sys

    # redirect logging to console
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.DEBUG)
    ch.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
    logger.addHandler(ch)

    test_trigger = croniter('*/10 * * * *', datetime.now(tz.tzutc()), ret_type=datetime).get_prev()

    handler({"time": test_trigger.isoformat()}, None)
