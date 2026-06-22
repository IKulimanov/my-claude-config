# GitLab CI Pipeline Reference

## Pipeline Skeleton for Java/Spring Service

```yaml
default:
  image: eclipse-temurin:21-jdk
  interruptible: true

stages:
  - build
  - test
  - package
  - docker
  - deploy

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository"
  IMAGE_TAG: "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA"

cache:
  key:
    files: [pom.xml]
  paths: [.m2/repository]

# ── Build ─────────────────────────────────────────────────────────────────────

compile:
  stage: build
  script: mvn compile -B -q

# ── Test ──────────────────────────────────────────────────────────────────────

unit-test:
  stage: test
  script: mvn verify -B
  artifacts:
    when: always
    reports:
      junit: target/surefire-reports/TEST-*.xml
      coverage_report:
        coverage_format: jacoco
        path: target/site/jacoco/jacoco.xml

# ── Package ───────────────────────────────────────────────────────────────────

package:
  stage: package
  script: mvn package -DskipTests -B
  artifacts:
    paths: [target/*.jar]
    expire_in: 1 day
  needs: [unit-test]

# ── Docker ────────────────────────────────────────────────────────────────────

docker-build:
  stage: docker
  image: docker:24
  services: [docker:24-dind]
  before_script:
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
  script:
    - docker build -t "$IMAGE_TAG" .
    - docker push "$IMAGE_TAG"
  needs: [package]
  rules:
    - if: $CI_COMMIT_BRANCH == "master"
    - if: $CI_COMMIT_BRANCH == "staging"

# ── Deploy ────────────────────────────────────────────────────────────────────

deploy-staging:
  stage: deploy
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - ./scripts/deploy.sh staging "$IMAGE_TAG"
  rules:
    - if: $CI_COMMIT_BRANCH == "staging"
  needs: [docker-build]

deploy-prod:
  stage: deploy
  environment:
    name: production
    url: https://app.example.com
  script:
    - ./scripts/deploy.sh production "$IMAGE_TAG"
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "master"
  needs: [docker-build]
```

---

## Rules vs Only/Except

Use `rules:` — it is composable and explicit:

```yaml
rules:
  - if: $CI_PIPELINE_SOURCE == "merge_request_event"   # MR pipelines
  - if: $CI_COMMIT_BRANCH == "master"                   # push to master
  - if: $CI_COMMIT_TAG                                  # tag push
    when: manual
  - when: never                                          # default: skip
```

---

## Caching Maven Dependencies

```yaml
cache:
  key:
    files: [pom.xml]          # cache busts when pom.xml changes
  paths:
    - .m2/repository
  policy: pull-push           # pull on start, push on success (default)
```

For read-only jobs (tests that don't install new deps):
```yaml
cache:
  policy: pull
```

---

## Artifacts

```yaml
artifacts:
  paths:
    - target/*.jar            # keep the JAR for downstream jobs
  expire_in: 1 day            # do not keep indefinitely
  when: always                # reports even on failure
  reports:
    junit: target/surefire-reports/TEST-*.xml
```

---

## Environments and Deployment Gates

```yaml
environment:
  name: production
  url: https://app.example.com
  deployment_tier: production   # used for analytics/access control
```

Protect the environment in GitLab → Settings → CI/CD → Environments:
- Set "Required approvals" for production
- Limit who can run manual jobs

---

## Reusable Job Templates

```yaml
# Define once
.java-base: &java-base
  image: eclipse-temurin:21-jdk
  before_script:
    - export JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70"

# Reuse
unit-test:
  <<: *java-base
  stage: test
  script: mvn verify -B
```

Or with `extends:`:
```yaml
.java-base:
  image: eclipse-temurin:21-jdk

unit-test:
  extends: .java-base
  stage: test
  script: mvn verify -B
```

---

## Variables and Secrets

- Masked variables: visible in logs if printed, but masked by GitLab's log masker.
- Protected variables: only available on protected branches/tags.
- Secret variables (file type): written to a temp file; pass the file path, not the value.

Never:
```yaml
variables:
  DB_PASSWORD: "mypassword"   # visible in repo history
```

Always:
- Add secrets in GitLab → Settings → CI/CD → Variables
- Mark as **Masked** and **Protected**
