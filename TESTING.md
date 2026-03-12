# Red Team Engagement Testing Guide

## Quick Start Testing

### Prerequisites
- Cloud CLI credentials configured (AWS/Azure/GCP)
- SSH key pair created and uploaded
- Domain names ready for SSL certificates
- Project files in `multi-cloud-redteam/` directory

### Test on AWS (Recommended First)

```bash
cd multi-cloud-redteam

# Start test engagement
./engagement-manager.sh start

# Follow prompts:
# Engagement name: test-aws-001
# Client name: test-client
# Duration: 1
# Cloud provider: aws
# Stealth level: high
# Deployment mode: primary
```

### Test on Azure

```bash
cd multi-cloud-redteam

# Start Azure test
./engagement-manager.sh start

# Follow prompts:
# Engagement name: test-azure-001
# Client name: test-client
# Duration: 1
# Cloud provider: azure
# Stealth level: high
# Deployment mode: primary
```

### Test Multi-Cloud Failover

```bash
cd multi-cloud-redteam

# Test multi-cloud deployment
./engagement-manager.sh start

# Follow prompts:
# Engagement name: test-multicloud-001
# Cloud provider: all (deploys to AWS primary, Azure/GCP backup)
```

## Verification Steps

### 1. Infrastructure Deployment
```bash
# Check deployment status
./engagement-manager.sh --status

# Verify outputs
cat engagements/test-aws-001/deployment.json

# Check access information
cat engagements/test-aws-001/access.json
```

### 2. SSL Certificate Setup
```bash
# Setup SSL certificates
./setup-ssl.sh engagements/test-aws-001/deployment.json high

# Follow domain prompts:
# Base domain: example.com
# Select obfuscated domains from generated list
```

### 3. Service Verification
```bash
# Test Mythic C2
curl -k https://c2-example.com:7443

# Test GoPhish
curl -k https://phish-example.com

# Test Evilginx
curl -k http://proxy-example.com:8080

# Test Pwndrop
curl -k http://files-example.com:8080
```

### 4. Monitoring Check
```bash
# Check monitoring configuration
cat monitoring/stealth-monitor.yaml

# Verify stealth level
grep "stealth_level" monitoring/stealth-monitor.yaml
```

## Test Scenarios

### Scenario 1: Basic AWS Test
**Objective**: Verify single-cloud deployment works

**Steps**:
1. Start engagement on AWS
2. Verify all services deployed
3. Check SSL certificates
4. Test service accessibility
5. Verify stealth configuration

**Expected Results**:
- 4 VMs deployed (Mythic, GoPhish, Evilginx, Pwndrop)
- SSL certificates installed
- High stealth configuration
- Minimal monitoring footprint

### Scenario 2: Azure Test
**Objective**: Verify Azure deployment works

**Steps**:
1. Start engagement on Azure
2. Compare deployment time vs AWS
3. Verify service functionality
4. Check Azure-specific configurations

**Expected Results**:
- Similar functionality to AWS
- Potential deployment time differences
- Azure networking correctly configured

### Scenario 3: Multi-Cloud Test
**Objective**: Verify multi-cloud deployment and failover

**Steps**:
1. Start multi-cloud engagement
2. Verify AWS primary deployment
3. Verify Azure backup deployment
4. Verify GCP backup deployment
5. Test DNS failover configuration

**Expected Results**:
- Primary infrastructure on AWS
- Backup infrastructure on Azure and GCP
- DNS failover ready
- Cross-cloud monitoring configured

### Scenario 4: Stealth Level Test
**Objective**: Test different stealth configurations

**Steps**:
1. Start engagement with HIGH stealth
2. Verify minimal monitoring
3. Stop engagement
4. Start engagement with MEDIUM stealth
5. Compare monitoring footprints
6. Test LOW stealth (not recommended)

**Expected Results**:
- HIGH: Minimal monitoring, manual checks
- MEDIUM: Basic health checks
- LOW: Full monitoring (high visibility)

### Scenario 5: Engagement Lifecycle Test
**Objective**: Test complete engagement lifecycle

**Steps**:
1. Start new engagement
2. Verify all services working
3. Run for short duration (1-2 hours)
4. Stop engagement
5. Verify data backup
6. Verify infrastructure teardown

**Expected Results**:
- Clean deployment
- All services functional
- Complete data backup
- Full infrastructure cleanup
- No orphaned resources

## Troubleshooting

### Common Issues

#### Deployment Fails
```bash
# Check cloud credentials
aws sts get-caller-identity    # AWS
az account show               # Azure
gcloud auth list              # GCP

# Check Terraform state
ls -la cloud-configs/aws/terraform/
cat cloud-configs/aws/terraform/terraform.tfstate

# Check logs
tail -f logs/deployment_*.log
```

#### SSL Certificate Issues
```bash
# Check certbot installation
ssh ubuntu@<IP> "certbot --version"

# Check certificate status
ssh ubuntu@<IP> "certbot certificates"

# Check nginx configuration
ssh ubuntu@<IP> "nginx -t"
```

#### Service Access Issues
```bash
# Check service status
./engagement-manager.sh --status

# Test connectivity
nmap -p 443,7443,8080 <IP>

# Check logs
ssh ubuntu@<IP> "docker logs <container_name>"
```

## Success Criteria

### Deployment Success
- [ ] All VMs deployed and accessible
- [ ] SSL certificates installed and valid
- [ ] Services responding on expected ports
- [ ] Stealth configuration applied
- [ ] Access information generated

### Engagement Success
- [ ] Can start new engagement
- [ ] Can check engagement status
- [ ] Can stop engagement cleanly
- [ ] Data backed up before teardown
- [ ] Infrastructure completely destroyed on stop

### Multi-Cloud Success
- [ ] Primary deployment works
- [ ] Backup deployments work
- [ ] DNS failover configured
- [ ] Cross-cloud monitoring functional

## Performance Benchmarks

### Deployment Times
- **AWS**: 15-25 minutes
- **Azure**: 20-30 minutes
- **GCP**: 18-28 minutes
- **Multi-Cloud**: 45-60 minutes

### Resource Usage
- **Mythic VM**: 2-4 GB RAM, 2 vCPU
- **GoPhish VM**: 1-2 GB RAM, 1 vCPU
- **Evilginx VM**: 1-2 GB RAM, 1 vCPU
- **Pwndrop VM**: 0.5-1 GB RAM, 1 vCPU

## Next Steps After Testing

1. **Production Deployment**
   - Use verified configurations
   - Deploy with real domains
   - Set up monitoring alerts

2. **Operator Training**
   - Train team on engagement lifecycle
   - Practice emergency procedures
   - Document lessons learned

3. **Documentation Updates**
   - Update SOPs based on test results
   - Create troubleshooting guides
   - Document performance benchmarks

---

**Ready for Testing**: The multi-cloud red team infrastructure is now ready for testing on AWS, Azure, and GCP with full engagement lifecycle management.
