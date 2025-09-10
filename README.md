# ECS Task Failure Monitoring with Google Chat

ECS 태스크가 비정상 종료될 때 Google Chat으로 실시간 알림을 보내는 모니터링 시스템입니다.

## 🎯 주요 기능

- ECS 태스크 실패 실시간 감지
- Google Chat으로 즉시 알림 발송
- 실패 원인 및 컨테이너 종료 코드 포함
- AWS Console 직접 링크 제공

## 📦 구성 요소

- **EventBridge Rule**: ECS 태스크 상태 변경 이벤트 캡처
- **SNS Topic**: 이벤트 라우팅
- **Lambda Function**: Google Chat 메시지 포맷팅 및 전송
- **IAM Roles**: 필요한 권한 관리

## 🚀 배포 방법

### 1. Google Chat Webhook URL 준비

1. Google Chat 스페이스에서 Webhook 생성
2. URL 복사 (형식: `https://chat.googleapis.com/v1/spaces/XXX/messages?key=YYY&token=ZZZ`)

### 2. CloudFormation 스택 배포

```bash
# 기본 배포 (dev-an2d 환경, 모든 ECS 클러스터 모니터링)
./deploy.sh <WEBHOOK_URL>

# 다른 환경 지정 (예: stg-an2s, prd-an2p)
./deploy.sh <WEBHOOK_URL> stg-an2s
./deploy.sh <WEBHOOK_URL> prd-an2p

# 커스텀 스택 이름까지 지정
./deploy.sh <WEBHOOK_URL> dev-an2d my-custom-stack

# AWS CLI 직접 사용
aws cloudformation deploy \
  --template-file ecs-task-failure-monitoring.yaml \
  --stack-name dev-an2d-ecs-monitoring-stack \
  --parameter-overrides \
    GoogleChatWebhookUrl=<WEBHOOK_URL> \
    EnvironmentPrefix=dev-an2d \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-2
```

## 📊 모니터링 대상 이벤트

다음 종료 코드를 가진 ECS 태스크 실패를 감지합니다:

- `TaskFailed` - 태스크 실행 실패
- `EssentialContainerExited` - 필수 컨테이너 종료
- `CannotPullContainerError` - 컨테이너 이미지 풀 실패
- `OutOfMemoryError` - 메모리 부족
- `CannotStartContainerError` - 컨테이너 시작 실패
- `InternalError` - 내부 오류
- `ResourceInitializationError` - 리소스 초기화 실패

## 📨 알림 메시지 예시

```
🚨 ECS Task Failed in DEV

Cluster: dev-an2d-ecs
Service: my-api-service
Task ID: a1b2c3d4e5f6...
Stop Code: EssentialContainerExited
Reason: Essential container in task exited
Failed Containers: app (exit: 1)
Time: 2025-01-20T10:30:45Z
Region: ap-northeast-2

[View in Console](링크)
```

## 🔧 파라미터

| 파라미터 | 설명 | 기본값 |
|---------|------|--------|
| GoogleChatWebhookUrl | Google Chat Webhook URL | (필수) |
| EnvironmentPrefix | 환경 접두사 (예: dev-an2d, stg-an2s, prd-an2p) | dev-an2d |

## 📁 파일 구조

```
.
├── ecs-task-failure-monitoring.yaml  # CloudFormation 템플릿
├── deploy.sh                         # 배포 스크립트
└── README.md                          # 이 문서
```

## 🧪 테스트 방법

1. 의도적으로 실패하는 태스크 배포:
```bash
# exit 1로 즉시 종료되는 컨테이너 실행
aws ecs run-task \
  --cluster dev-an2d-ecs \
  --task-definition <task-def> \
  --overrides '{"containerOverrides":[{"name":"container-name","command":["sh","-c","exit 1"]}]}'
```

2. SNS 토픽에 테스트 메시지 전송:
```bash
aws sns publish \
  --topic-arn <SNS_TOPIC_ARN> \
  --message '{"detail":{"clusterArn":"arn:aws:ecs:ap-northeast-2:123456789012:cluster/dev-an2d-ecs","taskArn":"arn:aws:ecs:ap-northeast-2:123456789012:task/dev-an2d-ecs/test123","group":"service:test-service","stopCode":"TaskFailed","stoppedReason":"Test failure"}}'
```

## 🗑️ 삭제 방법

```bash
aws cloudformation delete-stack \
  --stack-name dev-an2d-ecs-monitoring-stack \
  --region ap-northeast-2
```

## 📝 주의사항

- Google Chat Webhook URL은 안전하게 관리하세요
- Lambda 함수는 Python 3.11 런타임을 사용합니다
- 알림이 너무 많이 발생하면 Lambda 동시 실행 제한을 고려하세요

## 🔍 문제 해결

### 알림이 오지 않는 경우

1. CloudWatch Logs에서 Lambda 함수 로그 확인
2. EventBridge Rule이 ENABLED 상태인지 확인
3. Google Chat Webhook URL이 유효한지 확인

### 너무 많은 알림이 오는 경우

1. EventBridge Rule의 EventPattern 수정으로 필터링 강화
2. Lambda 함수에 중복 제거 로직 추가 고려
3. SNS Topic에 메시지 필터링 정책 적용

## 📚 관련 문서

- [ECS Task State Change Events](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_task_events.html)
- [EventBridge Event Patterns](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html)
- [Google Chat Webhooks](https://developers.google.com/chat/how-tos/webhooks)