#!/bin/bash
set -e

# ========================
# VARIABLES
# ========================
CLUSTER_NAME="churn-cluster"
SERVICE_NAME="churn-api-service"
TASK_NAME="churn-api-task"
CONTAINER_NAME="churn-api"
CONTAINER_PORT=8080
SUBNETS="subnet-00c6e0b259c7f3ba1,subnet-0ad637c4eae6ac710"
SECURITY_GROUP="sg-0eff4ee8692bdd2b9"
LOG_GROUP="/ecs/churn-api"
REGION="us-east-1"

EXECUTION_ROLE="ecsTaskExecutionRole"
TASK_ROLE="ecsTaskRole"

TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-east-1:001393350085:targetgroup/churn-TG-ip/a7c5c162be53c41c"

# ========================
# CREATE LOG GROUP IF NOT EXISTS
# ========================
if ! aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$REGION" | grep -q "$LOG_GROUP"; then
    echo "Creating CloudWatch log group: $LOG_GROUP"
    aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$REGION"
else
    echo "CloudWatch log group already exists: $LOG_GROUP"
fi

# ========================
# REGISTER TASK DEFINITION
# ========================
TASK_DEF_JSON=$(cat <<EOF
{
  "family": "$TASK_NAME",
  "networkMode": "awsvpc",
  "executionRoleArn": "arn:aws:iam::001393350085:role/$EXECUTION_ROLE",
  "taskRoleArn": "arn:aws:iam::001393350085:role/$TASK_ROLE",
  "containerDefinitions": [
    {
      "name": "$CONTAINER_NAME",
      "image": "74ba432f3904",
      "portMappings": [
        {
          "containerPort": $CONTAINER_PORT,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "$LOG_GROUP",
          "awslogs-region": "$REGION",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512"
}
EOF
)

echo "Registering new task definition..."
NEW_TASK_ARN=$(aws ecs register-task-definition \
    --cli-input-json "$TASK_DEF_JSON" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text \
    --region "$REGION")
echo "New task definition ARN: $NEW_TASK_ARN"

# ========================
# UPDATE SERVICE
# ========================
echo "Updating ECS service to use new task definition..."
aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --task-definition "$NEW_TASK_ARN" \
    --region "$REGION"

# ========================
# WAIT FOR TASK TO RUN
# ========================
echo "Waiting for task to reach RUNNING state..."
MAX_WAIT=300
SLEEP_INTERVAL=10
TIME_WAITED=0

while [ $TIME_WAITED -lt $MAX_WAIT ]; do
    RUNNING_TASKS=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$SERVICE_NAME" \
        --desired-status RUNNING \
        --region "$REGION" \
        --query "taskArns" \
        --output text)
    if [ -n "$RUNNING_TASKS" ]; then
        echo "Tasks are running: $RUNNING_TASKS"
        break
    else
        echo "Waiting for tasks to start..."
        sleep $SLEEP_INTERVAL
        TIME_WAITED=$((TIME_WAITED+SLEEP_INTERVAL))
    fi
done

if [ -z "$RUNNING_TASKS" ]; then
    echo "No tasks started after $MAX_WAIT seconds. Check CloudWatch logs for errors."
else
    echo "Deployment complete. Check CloudWatch logs: $LOG_GROUP"
fi
