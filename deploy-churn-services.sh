#!/bin/zsh

# Variables
AWS_REGION="us-east-1"
CLUSTER_NAME="churn-cluster"
SERVICE_NAME="churn-api-service"
TASK_FAMILY="churn-api-task"
EXECUTION_ROLE_ARN="arn:aws:iam::001393350085:role/ecsTaskExecutionRole"
TASK_ROLE_ARN="arn:aws:iam::001393350085:role/ecsTaskRole"
DOCKER_IMAGE="74ba432f3904"
LOG_GROUP="/ecs/churn-api"

# 1️⃣ Create CloudWatch log group if it doesn't exist
aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP --region $AWS_REGION | grep $LOG_GROUP > /dev/null
if [ $? -ne 0 ]; then
    echo "Creating CloudWatch log group: $LOG_GROUP"
    aws logs create-log-group --log-group-name $LOG_GROUP --region $AWS_REGION
else
    echo "CloudWatch log group already exists: $LOG_GROUP"
fi

# 2️⃣ Create updated task definition JSON
TASK_DEF_JSON=$(cat <<EOF
{
  "family": "$TASK_FAMILY",
  "networkMode": "awsvpc",
  "executionRoleArn": "$EXECUTION_ROLE_ARN",
  "taskRoleArn": "$TASK_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "churn-api",
      "image": "$DOCKER_IMAGE",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "memory": 512,
      "cpu": 256,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "$LOG_GROUP",
          "awslogs-region": "$AWS_REGION",
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

# 3️⃣ Register the new task definition
echo "Registering new task definition..."
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json "$TASK_DEF_JSON" \
    --region $AWS_REGION \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "New task definition ARN: $NEW_TASK_DEF_ARN"

# 4️⃣ Update ECS service to use new task definition
echo "Updating ECS service..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --task-definition $NEW_TASK_DEF_ARN \
    --region $AWS_REGION

# 5️⃣ Wait a few seconds and check running tasks
sleep 10
echo "Listing running tasks..."
aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION
