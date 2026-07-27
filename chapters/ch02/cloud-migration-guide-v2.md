# Cloud Migration Guide — Node.js Web App (~20K Requests/Day)

## Cloud Provider

Any of the big three (AWS, GCP, Azure) will serve you well at this scale. AWS has the largest ecosystem and hiring pool. GCP tends to have the simplest developer experience. Azure makes sense if you're already in the Microsoft ecosystem. For a straightforward Node app, AWS or GCP are the strongest choices because of community resources and documentation density for Node workloads.

## Services to Plan For

### Compute

You have two main paths. A container-based approach (AWS ECS/Fargate, GCP Cloud Run, or Azure Container Apps) is the modern default: you Dockerize your app, push it, and let the platform handle scaling. Cloud Run in particular is a great fit for a Node app at this traffic level because it scales to zero and you pay per request. The alternative is a simple VM (EC2, Compute Engine) if your app has stateful needs or you want something closer to what you're running today.

### Database

Whatever you're using now (Postgres, MySQL, MongoDB) has a managed equivalent: RDS/Cloud SQL for relational, Atlas or DocumentDB for Mongo. Managed databases remove the backup/patching burden and are worth the premium.

### CDN & Static Assets

Put static files in object storage (S3, Cloud Storage) fronted by a CDN (CloudFront, Cloud CDN). This offloads a surprising amount of traffic from your compute tier.

### DNS & Load Balancing

Route 53 or Cloud DNS, plus the platform's load balancer if you're running multiple instances.

### Logging & Monitoring

CloudWatch, Cloud Logging, or a third-party like Datadog. Don't skip this; it's how you'll debug production issues post-migration.

### CI/CD

GitHub Actions, Cloud Build, or CodePipeline to automate deployments.

### Secrets Management

AWS Secrets Manager, GCP Secret Manager, or similar for API keys and DB credentials.

## Budget Estimate

At 20K requests/day you're in the low-traffic tier. Rough monthly costs:

| Service             | Estimated Monthly Cost |
| ------------------- | ---------------------- |
| Compute             | $15–80                 |
| Database (managed)  | $15–50                 |
| Storage & CDN       | $5–15                  |
| DNS, logging, misc  | $5–20                  |
| **Total**           | **$50–150**            |

Double this if you want a proper staging environment. Add ~$20–40/mo if you layer on Datadog or a similar observability tool. At this scale, many services fall within free-tier territory for the first year, so real costs may be even lower initially.

## Timeline

For a typical Node web app with a single database:

| Phase       | Tasks                                                                 | Duration   |
| ----------- | --------------------------------------------------------------------- | ---------- |
| Setup       | Dockerize app, cloud account, IAM, networking, infrastructure-as-code | Weeks 1–2  |
| Data        | Provision managed database, migrate data, secrets management          | Week 3     |
| Pipeline    | CI/CD pipeline, staging environment, smoke testing                    | Week 4     |
| Hardening   | Load testing, DNS cutover planning, monitoring & alerting             | Weeks 5–6  |
| Go-Live     | Production cutover, monitoring bake-in period                         | Weeks 6–8  |

**Realistic estimate: 4–8 weeks** with one or two engineers. The biggest variables are data migration complexity and how many external integrations or environment-specific configurations exist. If the app has no database or uses a SaaS database already, this can shrink to 2–3 weeks.

## Recommendation

If you don't have strong opinions and want the fastest path, start with **GCP Cloud Run + Cloud SQL + Cloud CDN**. It's the least operational overhead for a Node app at this scale, and you can always migrate to Kubernetes later if you outgrow it.
