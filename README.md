# AWS Idle Instance Shutdown CloudFormation Template

This CloudFormation template automatically shuts down idle EC2 instances across multiple AWS accounts in an organization to help reduce costs. It can work in both single-account and multi-account (AWS Organizations) modes.

## Features

- **Automated Monitoring**: Continuously monitors EC2 instances for idle activity
- **Configurable Thresholds**: Customizable CPU and network activity thresholds
- **Tag-based Exclusions**: Exclude critical instances using tags
- **Scheduled Checks**: Configurable schedule for checking instance activity
- **CloudWatch Integration**: Uses CloudWatch metrics for accurate idle detection
- **Logging**: Comprehensive logging for monitoring and debugging

## How It Works

### Single Account Mode
1. **CloudWatch Events Rule**: Triggers the Lambda function on a schedule (default: every 15 minutes)
2. **Lambda Function**: Checks all running EC2 instances for idle activity
3. **Instance Shutdown**: Automatically stops instances that meet idle criteria

### Multi-Account Mode (AWS Organizations)
1. **CloudWatch Events Rule**: Triggers the Lambda function on a schedule
2. **Organization Discovery**: Lambda function queries AWS Organizations to get all active accounts
3. **Cross-Account Role Assumption**: For each account, assumes a predefined IAM role
4. **Instance Analysis**: Checks all running EC2 instances across all accounts for idle activity by analyzing:
   - CPU utilization (default: < 5% average)
   - Network traffic (default: < 1MB total)
   - Activity duration (default: 60 minutes of low activity)
5. **Instance Shutdown**: Automatically stops instances that meet idle criteria across all accounts
6. **Exclusion Logic**: Skips instances with specific tags and can exclude entire accounts

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `IdleThresholdMinutes` | 60 | Minutes of inactivity before shutdown |
| `CPUThresholdPercent` | 5 | CPU utilization threshold (%) |
| `NetworkThresholdBytes` | 1000000 | Network traffic threshold (bytes) |
| `ScheduleExpression` | `rate(15 minutes)` | How often to check for idle instances |
| `ExcludeInstanceTags` | `Environment=Production,DoNotShutdown=true` | Tags to exclude from shutdown |
| `CrossAccountRoleName` | `IdleInstanceShutdownRole` | IAM role name in member accounts |
| `ExcludeAccountIds` | `` | Comma-separated account IDs to exclude |
| `IncludeAccountIds` | `` | Comma-separated account IDs to include (if empty, processes all) |

## Deployment

### Multi-Account Setup (Recommended)

#### Step 1: Deploy Member Account Role
Deploy this template in **each member account** where you want to manage EC2 instances:

```bash
aws cloudformation create-stack \
  --stack-name idle-shutdown-member-role \
  --template-body file://member-account-role.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=CentralAccountId,ParameterValue=123456789012 \
    ParameterKey=RoleName,ParameterValue=IdleInstanceShutdownRole
```

#### Step 2: Deploy Central Account Template
Deploy this template in your **central/management account**:

```bash
aws cloudformation create-stack \
  --stack-name idle-instance-shutdown \
  --template-body file://idle-instance-shutdown.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=CrossAccountRoleName,ParameterValue=IdleInstanceShutdownRole \
    ParameterKey=IdleThresholdMinutes,ParameterValue=60 \
    ParameterKey=CPUThresholdPercent,ParameterValue=5
```

### Single Account Setup

For single account deployment, use the original parameters:

```bash
aws cloudformation create-stack \
  --stack-name idle-instance-shutdown \
  --template-body file://idle-instance-shutdown.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=IdleThresholdMinutes,ParameterValue=60 \
    ParameterKey=CPUThresholdPercent,ParameterValue=5
```

### Using AWS Console

1. Open the AWS CloudFormation console
2. Click "Create stack" → "With new resources"
3. Upload the `idle-instance-shutdown.yaml` template
4. Configure parameters as needed
5. Review and create the stack

## Protecting Instances from Shutdown

To prevent specific instances from being shut down, add one of these tags:

- `Environment=Production`
- `DoNotShutdown=true`

Or customize the `ExcludeInstanceTags` parameter with your own tag patterns.

## Monitoring

- **CloudWatch Logs**: Check `/aws/lambda/{stack-name}-idle-instance-shutdown` for execution logs
- **SNS Notifications**: Subscribe to the created SNS topic for shutdown notifications
- **CloudWatch Metrics**: Monitor Lambda function execution and errors

## Cost Considerations

### Multi-Account Mode
- **Lambda Costs**: Slightly higher due to cross-account operations (~$2-5/month depending on organization size)
- **CloudWatch Costs**: Small cost for log storage and metrics
- **Organizations API**: No additional cost for API calls
- **Savings**: Can save thousands to tens of thousands of dollars monthly across the entire organization

### Single Account Mode
- **Lambda Costs**: Minimal cost for function execution (typically < $1/month)
- **CloudWatch Costs**: Small cost for log storage and metrics
- **Savings**: Can save hundreds to thousands of dollars monthly by shutting down idle instances

## Security

### Central Account Permissions
The central account Lambda role has permissions for:
- `organizations:ListAccounts` - To discover organization accounts
- `organizations:DescribeOrganization` - To get organization details
- `sts:AssumeRole` - To assume roles in member accounts
- Basic Lambda execution permissions

### Member Account Permissions
Each member account role has minimal required permissions:
- `ec2:DescribeInstances` - To list running instances
- `ec2:StopInstances` - To shut down idle instances
- `cloudwatch:GetMetricStatistics` - To check instance metrics

### Cross-Account Trust
- Member account roles trust only the specific central account ID
- Uses external ID for additional security
- Follows AWS security best practices for cross-account access

## Customization

### Modify Idle Detection Logic

Edit the Lambda function code to add custom metrics or change detection logic:

```python
# Example: Add disk I/O monitoring
disk_response = cloudwatch.get_metric_statistics(
    Namespace='AWS/EC2',
    MetricName='DiskReadBytes',
    # ... additional configuration
)
```

### Add Notifications

Integrate with the SNS topic to send notifications when instances are shut down:

```python
sns = boto3.client('sns')
sns.publish(
    TopicArn=os.environ['SNS_TOPIC_ARN'],
    Message=f'Shut down idle instances: {instances_to_shutdown}',
    Subject='Idle Instance Shutdown Notification'
)
```

## Troubleshooting

### Common Issues

#### Multi-Account Mode
1. **Access denied errors**: Verify member account roles are deployed and trust the correct central account ID
2. **No accounts being processed**: Check Organizations permissions in central account
3. **Some accounts skipped**: Check exclude/include account ID parameters and role existence
4. **Lambda timeouts**: Increase timeout value for large organizations (consider 15 minutes)

#### Single Account Mode
1. **No instances being shut down**: Check CloudWatch logs for errors, verify IAM permissions
2. **Wrong instances being shut down**: Adjust thresholds or add exclusion tags
3. **Lambda timeouts**: Increase timeout value or optimize the code for large numbers of instances

### Debugging

1. Check CloudWatch logs: `/aws/lambda/{stack-name}-idle-instance-shutdown`
2. Test the Lambda function manually with a test event
3. Verify CloudWatch metrics are available for your instances
4. For multi-account issues:
   - Verify Organizations API access in central account
   - Check cross-account role trust relationships
   - Test role assumption manually using AWS CLI
   - Review account-specific error messages in logs

## Cleanup

To remove the idle instance shutdown system:

```bash
aws cloudformation delete-stack --stack-name idle-instance-shutdown
```

## License

This template is provided as-is for educational and operational use. Test thoroughly in a non-production environment before deploying to production.
