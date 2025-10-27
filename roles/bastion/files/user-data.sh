#!/bin/bash
yum update -y
yum install -y aws-cli
yum install -y htop tree vim wget curl

# Install additional security tools
yum install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# Configure SSH hardening
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/' /etc/ssh/sshd_config
systemctl restart sshd

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create a user for operations team
useradd -m -s /bin/bash opsuser
mkdir -p /home/opsuser/.ssh
cp /home/ec2-user/.ssh/authorized_keys /home/opsuser/.ssh/
chown -R opsuser:opsuser /home/opsuser/.ssh
chmod 700 /home/opsuser/.ssh
chmod 600 /home/opsuser/.ssh/authorized_keys

# Add opsuser to sudoers
echo "opsuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/opsuser

# Install session manager plugin for better security
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
yum install -y session-manager-plugin.rpm

# Log the completion
echo "Bastion host setup completed at $(date)" >> /var/log/bastion-setup.log