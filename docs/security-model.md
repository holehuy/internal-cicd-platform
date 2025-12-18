# Security Model & Best Practices

## Tổng quan

Document này mô tả security model của Internal CI/CD Platform và các best practices cần tuân thủ.

---

## 🔐 Security Layers

### 1. Network Security

```
Internet
   │
   ├─→ Firewall
   │     │
   │     └─→ Nginx (SSL/TLS Termination)
   │           │
   │           └─→ Internal Network (Docker Bridge)
   │                 │
   │                 ├─→ Jenkins (8080)
   │                 ├─→ SonarQube (9000)
   │                 └─→ PostgreSQL (5432 - internal only)
```

**Security Controls:**
- Firewall rules cho inbound traffic
- SSL/TLS encryption cho external access
- Internal Docker network isolation
- PostgreSQL không exposed ra ngoài

### 2. Authentication & Authorization

#### Jenkins Security

**Authentication Methods:**
1. **Local User Database** (Default)
2. **LDAP/Active Directory** (Optional)
3. **SAML SSO** (Optional)

**Authorization Strategy:**
```
Matrix-based Security:
├── Admin Role
│   ├── Overall/Administer
│   ├── Overall/Read
│   └── All permissions
│
├── Developer Role
│   ├── Job/Build
│   ├── Job/Cancel
│   ├── Job/Read
│   └── View/Read
│
└── Viewer Role
    ├── Job/Read
    └── View/Read
```

**Folder-level Security:**
```
Team-Frontend/
├── Permissions:
│   ├── Frontend Team: Build, Configure, Read
│   ├── Team Lead: All permissions
│   └── Others: Read only
```

#### SonarQube Security

**Authentication:**
- Built-in user database
- LDAP integration (optional)
- Token-based API access

**Permissions:**
```
Global Level:
├── Administer
├── Quality Gate: Administer
└── Quality Profile: Administer

Project Level:
├── Admin
├── Issue Admin
├── Security Hotspot Admin
├── Browse
└── Execute Analysis
```

### 3. Secrets Management

#### Jenkins Credentials Store

**Credential Types:**
```
Global Credentials:
├── Username/Password
│   └── Git, Docker Registry
│
├── Secret Text
│   └── API Tokens, SonarQube tokens
│
├── SSH Keys
│   └── Deployment keys
│
└── Certificates
    └── SSL/TLS certs
```

**Access Control:**
- Credentials scoped to specific folders
- Usage tracking và audit logs
- Encrypted at rest (AES-128)

**Example:**
```groovy
// In Jenkinsfile - credentials are never exposed
withCredentials([
    string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')
]) {
    // Use ${SONAR_TOKEN} here
}
```

#### Environment Variables

**Secure Storage:**
```bash
# env/platform.env
JENKINS_ADMIN_PASSWORD=<strong-password>  # Never commit to git
POSTGRES_PASSWORD=<strong-password>       # Encrypted at rest
```

**Best Practices:**
- ✅ Use `.gitignore` cho env files
- ✅ Rotate passwords định kỳ
- ✅ Use password managers
- ❌ Never hardcode secrets trong code
- ❌ Never log sensitive information

### 4. API Security

#### Jenkins API

**Authentication:**
```bash
# Using API Token
curl -u username:api-token http://jenkins/api/json

# Using crumb for CSRF protection
CRUMB=$(curl -u username:token 'http://jenkins/crumbIssuer/api/json' | jq -r .crumb)
curl -u username:token -H "Jenkins-Crumb:$CRUMB" -X POST http://jenkins/job/test/build
```

**API Token Management:**
1. Jenkins → User → Configure → API Token
2. Generate token với descriptive name
3. Store securely (không log, không commit)
4. Revoke khi không dùng nữa

#### SonarQube API

**Token Types:**
```
User Token:
- Scope: All projects user có quyền
- Expiration: Configurable
- Use case: Personal scripts, CI/CD

Project Analysis Token:
- Scope: Specific project
- Expiration: Configurable  
- Use case: Jenkins pipelines
```

**Example:**
```bash
curl -u token: http://sonarqube/api/projects/search
```

---

## 🛡️ Security Best Practices

### 1. Password Policy

**Requirements:**
```
Minimum length: 12 characters
Must contain:
  ✓ Uppercase letters
  ✓ Lowercase letters
  ✓ Numbers
  ✓ Special characters
  
Rotation: Every 90 days
History: Cannot reuse last 5 passwords
```

**Default Password Changes:**
```bash
# Jenkins
1. Login với admin/changeme123!
2. Immediate change: Manage Jenkins → Configure Global Security → Security Realm

# SonarQube
1. Login với admin/changeme123!
2. Immediate change: Administration → Security → Users → Change password
```

### 2. Access Control

**Principle of Least Privilege:**
```
User Levels:
1. Admin
   - Full system access
   - Production deployments
   - Security configurations

2. Developer
   - Build/deploy dev/staging
   - View logs
   - Configure own projects

3. Viewer
   - View builds
   - View reports
   - No configuration changes
```

**Implementation:**
```groovy
// jenkins.yaml
authorizationStrategy:
  globalMatrix:
    permissions:
      - "Overall/Administer:admin"
      - "Overall/Read:developers"
      - "Job/Build:developers"
      - "Job/Read:viewers"
```

### 3. Audit Logging

#### Jenkins Audit Trail

**Enable:**
```
Manage Jenkins → Configure System → Audit Trail
- Log file: /var/jenkins_home/logs/audit.log
- Log rotation: 30 days
```

**Logged Events:**
- User login/logout
- Job configuration changes
- Credential access
- Build triggers
- Plugin installations

#### SonarQube Audit

**Enable:**
```
Administration → Configuration → General → Audit Logs
```

**Logged Events:**
- User authentication
- Permission changes
- Quality gate modifications
- Project deletions

### 4. Secure Pipeline Practices

#### Input Validation

```groovy
// ❌ DANGEROUS - Command injection
sh "echo ${params.USER_INPUT}"

// ✅ SAFE - Proper escaping
sh "echo '${params.USER_INPUT.replaceAll("'", "'\\''")}'"
```

#### Secrets in Pipelines

```groovy
// ❌ NEVER DO THIS
env.DB_PASSWORD = 'hardcoded_password'
sh "mysql -p${env.DB_PASSWORD}"

// ✅ DO THIS
withCredentials([string(credentialsId: 'db-password', variable: 'DB_PASSWORD')]) {
    sh 'mysql -p"$DB_PASSWORD"'
}
```

#### Docker Security

```groovy
// ✅ Use specific image versions
docker.image('node:18.19.0-alpine')

// ❌ Avoid 'latest' tag
docker.image('node:latest')

// ✅ Scan images for vulnerabilities
stage('Security Scan') {
    steps {
        sh 'docker scan myapp:${VERSION}'
    }
}
```

### 5. SSL/TLS Configuration

#### Generate Self-Signed Certificate

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout nginx/ssl/key.pem \
    -out nginx/ssl/cert.pem \
    -subj "/C=VN/ST=DaNang/L=DaNang/O=Company/CN=cicd.company.com"
```

#### Nginx SSL Configuration

```nginx
server {
    listen 443 ssl http2;
    server_name jenkins.company.com;
    
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    location / {
        proxy_pass http://jenkins:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 6. Backup Security

**Encryption:**
```bash
# Encrypt backup
./scripts/backup.sh
gpg --symmetric --cipher-algo AES256 backup_*.tar.gz

# Decrypt backup
gpg --decrypt backup_*.tar.gz.gpg > backup.tar.gz
```

**Storage:**
```bash
# Store backups off-site
rsync -avz --delete \
    /backup/cicd-platform/ \
    backup-server:/backup/cicd/

# Or use cloud storage
aws s3 sync /backup/cicd-platform/ s3://company-backups/cicd/
```

**Access Control:**
```bash
# Restrict backup directory
chmod 700 /backup/cicd-platform
chown root:root /backup/cicd-platform
```

---

## 🚨 Security Incidents

### Incident Response Plan

**1. Detection:**
- Monitor audit logs
- Alert on suspicious activities
- Regular security scans

**2. Containment:**
```bash
# Immediately stop services
docker-compose stop

# Isolate affected systems
# Review logs
docker-compose logs > incident_logs.txt

# Disable compromised accounts
# In Jenkins: Manage Users → Disable user
```

**3. Recovery:**
```bash
# Restore from known good backup
./scripts/restore.sh /backup/last_good_backup.tar.gz

# Reset all passwords
# Rotate all tokens
# Update security rules
```

**4. Post-Incident:**
- Document incident
- Update security policies
- Implement preventive measures
- Training for team

### Common Security Issues

#### 1. Exposed Credentials

**Detection:**
```bash
# Scan git history for secrets
git log -p | grep -i "password\|token\|secret"

# Use tools
trufflehog --regex --entropy=False https://github.com/your-org/repo
```

**Remediation:**
```bash
# Remove from git history
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch path/to/file' \
  --prune-empty --tag-name-filter cat -- --all

# Rotate all exposed credentials immediately
```

#### 2. Weak Passwords

**Detection:**
```bash
# Password audit script
# Check against common password lists
```

**Enforcement:**
```groovy
// jenkins.yaml
securityRealm:
  local:
    allowsSignup: false
    enableCaptcha: true
    passwordPolicy:
      minimumLength: 12
      requiresUppercase: true
      requiresLowercase: true
      requiresNumber: true
      requiresSpecialChar: true
```

#### 3. Unauthorized Access

**Detection:**
```bash
# Review Jenkins audit logs
grep "login failed" /var/jenkins_home/logs/audit.log

# Review SonarQube logs
docker logs internal-sonarqube | grep "authentication"
```

**Prevention:**
- Enable MFA (if available)
- IP whitelisting
- VPN requirement
- Rate limiting

---

## 📋 Security Checklist

### Initial Setup
- [ ] Change all default passwords
- [ ] Configure firewall rules
- [ ] Enable SSL/TLS
- [ ] Setup audit logging
- [ ] Configure backup encryption
- [ ] Document security procedures

### Regular Maintenance (Monthly)
- [ ] Review access permissions
- [ ] Check for software updates
- [ ] Review audit logs
- [ ] Test backup restoration
- [ ] Scan for vulnerabilities
- [ ] Review credential usage

### Incident Response
- [ ] Incident response plan documented
- [ ] Contact list updated
- [ ] Backup locations verified
- [ ] Recovery procedures tested

---

## 🔗 Security Resources

### Tools
- **OWASP Dependency Check**: Vulnerability scanning
- **Trivy**: Container security scanning
- **Git Secrets**: Prevent committing secrets
- **Vault**: Secrets management (advanced)

### Documentation
- [Jenkins Security](https://www.jenkins.io/doc/book/security/)
- [SonarQube Security](https://docs.sonarqube.org/latest/instance-administration/security/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

## 📞 Security Contacts

**Security Team:**
- Email: security@company.com
- Emergency: [phone]
- Slack: #security-incidents

**Platform Admins:**
- Primary: admin1@company.com
- Secondary: admin2@company.com

---

## 📝 Security Policy Updates

This document should be reviewed and updated:
- Quarterly (minimum)
- After security incidents
- When new features are added
- When vulnerabilities are discovered

**Last Updated**: December 2025
**Next Review**: March 2026