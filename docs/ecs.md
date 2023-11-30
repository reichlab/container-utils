# Steps to set up AWS ECS

Set up [Amazon Elastic Container Service](https://aws.amazon.com/ecs/) (Amazon ECS) using the following steps. This requires the published image from the "Steps to publish the image" step above. NB: The following can be complicated to get correct.

Notes:

- Below we use the prefix "container_demo_app".
- Make sure you select the same region to use for all the following steps.
- [ecs-diagram.jpg](ecs-diagram.jpg) outlines the ECS components involved.

## A note regarding permissions

At least on ECS, the user and group of the cloned repos must all match. Note that the default user when running a temporary EC2 instance to modify the EFS is `ec2-user` (not `root`, which is the user when the container runs). We currently recommend that you change freshly cloned repos to `root:root`, e.g., `sudo chown -R root:root /data/sandbox`. Otherwise, you'll see errors like this when doing `git pull`: _fatal: detected dubious ownership in repository at ..._ .


## Create a security group

NB: these rules may not be safe for production, given this AWS warning:
> Rules with source of 0.0.0.0/0 or ::/0 allow all IP addresses to access your instance. We recommend setting security group rules to allow access from known IP addresses only.

- go to the VPC console > Security > Security groups
- click: "Create security group"
    - Security group name: container_demo_app
    - Description: group for https://github.com/reichlab/container-demo-app
    - VPC: choose default
    - Inbound rules: add the following two rules:
  > NFS | TCP | 2049 | Custom | 0.0.0.0/0
  > SSH | TCP | 22 | Custom | 0.0.0.0/0
    - Outbound rules: keep the default:
  > All traffic | All | All | Custom | 0.0.0.0/0
    - click: "Create security group"

## Create a cluster

- go to the ECS console
- click: "Create cluster"
    - Cluster name: container_demo_app
    - Infrastructure: AWS Fargate (serverless)
    - click: "Create"

## Create an EFS file system

- go to the EFS console
- click: "Create file system"
    - Name: container_demo_app
    - VPC: choose default
    - click: "Create"
    - make note of the new id (e.g., fs-0a493be23f192e911)
- you now need to replace the automatically-selected default security groups
- go to the new file system's Network tab and click "Manage"
- for each security group in the six Availability zone rows' Security groups column:
    - click the "X" to remove it
    - click the "Choose security groups" dropdown
    - type "container_demo_app" and select the found group
- when you've replaced all six, click "Save"

## Populate the file system using a temporary EC2 instance

As described above, the app needs a `/data/config` directory with three files. You will be populating the EFS by launching a temporary EC2 instance that mounts the EFS, and then copying those files from the `/config` directory that you created.

create and launch the container_demo_app_temp ec2 instance that mounts slack_app EFS volume at /data :

- go to the EC2 console
- click: "Launch instance"
- name: container_demo_app_temp
- Number of instances: 1 # right sidebar
- Amazon Machine Image (AMI): Amazon Linux 2023 AMI
- Architecture: 64-bit (x86)
- Instance type: t2.micro
- Key pair name: select an existing key pair (e.g., baseline_root) or click "Create new key pair"
- Network settings > Edit > Subnet: us-east-1a # @todo this is an arbitrary choice - I'm not sure this the best one
- Network: click "Select an existing security group", type "container_demo_app", and select the found group
- Configure storage > click "Edit" to the right of "0 x File systems"
    - click "Add shared file system"
    - File system: type "container_demo_app" and select the found file system
    - Mount point: /data

- click: "Launch instance"
- click the new instance and copy the "Public IPv4 DNS"
- open two terminals on your Mac and type the following in this order
- make sure you substitute your own .pem file's location and your DNS address

# terminal 1: ssh to the instance and chown `/data` to ec2-user # @todo not sure chown is necessary

```bash
ssh -o "StrictHostKeyChecking no" -i /Users/cornell/Downloads/baseline_root.pem ec2-user@ec2-3-239-32-252.compute-1.amazonaws.com
sudo chown ec2-user -R /data
```

# terminal 2:

```bash
scp -o "StrictHostKeyChecking no" -i /Users/cornell/Downloads/baseline_root.pem  -r /Users/cornell/IdeaProjects/container-demo-app/config/  ec2-user@ec2-44-195-78-234.compute-1.amazonaws.com:/data
```

# terminal 1:

```bash
$ ls -al /data/config/
-rw-r--r--. 1 ec2-user ec2-user  164 Sep 26 13:04 .env
-rw-r--r--. 1 ec2-user ec2-user   76 Sep 26 13:04 .git-credentials
-rw-r--r--. 1 ec2-user ec2-user   93 Sep 26 13:04 .gitconfig
```

- exit both terminals
- on the instance page, click "Instance state > Terminate instance", verify that you're operating on the container_demo_app_temp instance, and click "Terminate"

## Create the task definition

- go to the ECS console
- click "Task definitions" on the left sidebar:
- click "Create new Task Definition > Create new Task Definition"
    - Task definition family: container_demo_app
    - Launch type: AWS Fargate
    - Operating system/Architecture: Linux/X86_64
    - CPU: 0.5 vCPU , Memory: 1 GB
    - Task role: -
    - Task execution role: ecsTaskExecutionRole # @todo not sure if this should be different
    - scroll down to "Storage - optional" and click "Add volume" to create a "Volume - 1" section
        - Volume type: EFS
        - Volume name: container_demo_app_efs_volume | File system ID: type "container_demo_app" and select the found file system
        - Root directory: / | Access point ID: None
            - scroll up to "Container - 1"
        - Name: container_demo_app_container
        - Image URI: reichlab/container-demo-app:1.0 # this is the docker hub image you created above
        - Port mappings: click "Remove"
        - Environment variables - optional: click "Add environment variable": Key: SECRET, Value type: Value, Value: shh! (from AWS)
    - scroll down to "Volume - 1" and click "Add mount point"
        - Container: container_demo_app_container | Source volume: container_demo_app_efs_volume | Container path: /data
            - scroll to the bottom and click "Create"

## Run a task and check the output logs

- on the task definition page, click "Deploy > Run task"
    - Existing cluster: container_demo_app
    - Launch type: FARGATE | Platform version: LATEST
    - click "Create"
- click the new task and wait for "Last status" to be "Running"
- click the Logs tab, click "View in CloudWatch", and look ath the output, which should look something like:

```text
---------------------------------------------------------------------------------------------------------------------------------------------
|   timestamp   |                                                          message                                                          |
|---------------|---------------------------------------------------------------------------------------------------------------------------|
| 1695921585477 | required file found: './slack.sh'. loading                                                                                |
| 1695921585485 | required dir found: '/data/config'                                                                                        |
| 1695921585490 | required file found: '/data/config/.env'. copying to '/root'                                                              |
| 1695921585498 | required file found: '/data/config/.gitconfig'. copying to '/root'                                                        |
| 1695921585505 | required file found: '/data/config/.git-credentials'. copying to '/root'                                                  |
| 1695921585519 | slack_message: [app2.sh] entered. SECRET='shh! (from AWS)' [Thu Sep 28 17:19:45 UTC 2023 | ip-172-31-14-114.ec2.internal] |
| 1695921585784 | slack_message: [app2.sh] editing file [Thu Sep 28 17:19:45 UTC 2023 | ip-172-31-14-114.ec2.internal]                      |
| 1695921586474 | Already up to date.                                                                                                       |
| 1695921586766 | [main 6439301] update                                                                                                     |
| 1695921586766 |  1 file changed, 1 insertion(+)                                                                                           |
| 1695921586770 | slack_message: [app2.sh] pushing [Thu Sep 28 17:19:46 UTC 2023 | ip-172-31-14-114.ec2.internal]                           |
| 1695921587600 | To https://github.com/reichlabmachine/sandbox.git                                                                         |
| 1695921587600 |    3d54340..6439301  main -> main                                                                                         |
| 1695921587911 | 2 OPEN test issue  2023-09-25 19:41:59 +0000 UTC                                                                          |
| 1695921587922 | slack_message: [app2.sh] gh OK [Thu Sep 28 17:19:47 UTC 2023 | ip-172-31-14-114.ec2.internal]                             |
| 1695921588132 | slack_upload: README.md                                                                                                   |
| 1695921588544 | slack_message: [app2.sh] done [Thu Sep 28 17:19:48 UTC 2023 | ip-172-31-14-114.ec2.internal]                              |
 ---------------------------------------------------------------------------------------------------------------------------------------------
```

- go to the #tmp slack channel, which should have messages like the following:

```text
[app2.sh] entered. SECRET='shh! (from AWS)' [Thu Sep 28 17:19:45 UTC 2023 | ip-172-31-14-114.ec2.internal]
[app2.sh] editing file [Thu Sep 28 17:19:45 UTC 2023 | ip-172-31-14-114.ec2.internal]
[app2.sh] pushing [Thu Sep 28 17:19:46 UTC 2023 | ip-172-31-14-114.ec2.internal]
[app2.sh] gh OK [Thu Sep 28 17:19:47 UTC 2023 | ip-172-31-14-114.ec2.internal]
README
[app2.sh] done [Thu Sep 28 17:19:48 UTC 2023 | ip-172-31-14-114.ec2.internal]
```

## Schedule a task to run hourly (temporary schedule)

- go to the ECS console
- click container_demo_app
- click the Scheduled tasks tab
- click "Create"
    - Scheduled rule name: container_demo_app_hourly
    - Scheduled rule type: Run at fixed interval
        - Value for the rate expression: 1 | Unit for the rate expression: Hour(s)
            - scroll down to "Target - 1"
        - Target ID: container_demo_app_hourly_target # @todo ID matters?
        - Launch type: FARGATE | Platform version: LATEST
        - Task definition > Family: choose container_demo_app | Revision: choose LATEST
        - Number of tasks: 1
            - Security group name: choose container_demo_app
            - EventBridge IAM role for this target: ecsEventsRole
- click "Create"
- in the green message at the top, click the newly-created EventBridge rule to open it

- go to the #tmp slack channel, which should have new messages like above (the rule runs immediately)
- optionally: wait an hour to see the task run again.
- go back to the EventBridge rule page and click "Delete" and confirm the delete
