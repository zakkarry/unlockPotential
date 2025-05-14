#!/bin/bash

# Enhanced script to toggle RPC services (rpcbind and portmap)
# Created: April 30, 2025

# Check if script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo or as root"
  exit 1
fi

# Prompt user for action
echo "=========================================="
echo "      Enhanced RPC Services Manager       "
echo "=========================================="
echo ""
read -p "Would you like to enable or disable RPC services? (enable/disable): " action

# Convert input to lowercase
action=$(echo "$action" | tr '[:upper:]' '[:lower:]')

# Function to handle command execution with error checking
run_command() {
  command="$1"
  # Use 2>/dev/null to suppress error output
  if eval "$command" 2>/dev/null; then
    echo "✓ Success: $command"
  else
    echo "- Skipped: $command (not applicable for this system)"
  fi
}

# Process based on user choice
case "$action" in
  "disable")
    echo ""
    echo "Disabling RPC services..."
    echo "=========================================="
    
    # Try to identify which init system is in use
    echo "Detecting init system..."
    if pidof systemd > /dev/null; then
      echo "Detected systemd init system"
      init_system="systemd"
    elif [ -f /usr/sbin/update-rc.d ]; then
      echo "Detected Debian-style init system"
      init_system="debian"
    elif [ -f /sbin/chkconfig ]; then
      echo "Detected RedHat-style init system"
      init_system="redhat"
    else
      echo "Could not determine init system, will try all methods"
      init_system="unknown"
    fi
    
    # Stop and disable services based on detected init system
    if [ "$init_system" = "systemd" ]; then
      # First try to mask the services in systemd
      echo "Masking services in systemd..."
      run_command "systemctl stop rpcbind.socket"
      run_command "systemctl disable rpcbind.socket"
      run_command "systemctl mask rpcbind.socket"
      run_command "systemctl stop rpcbind.service"
      run_command "systemctl disable rpcbind.service"
      run_command "systemctl mask rpcbind.service"
      run_command "systemctl stop portmap.service"
      run_command "systemctl disable portmap.service"
      run_command "systemctl mask portmap.service"
    elif [ "$init_system" = "debian" ]; then  
      run_command "service rpcbind stop"
      run_command "update-rc.d rpcbind disable"
      run_command "service portmap stop"
      run_command "update-rc.d portmap disable"
    elif [ "$init_system" = "redhat" ]; then
      run_command "service rpcbind stop"
      run_command "chkconfig rpcbind off"
      run_command "service portmap stop"
      run_command "chkconfig portmap off"
    else
      # Try everything if init system is unknown
      # systemd commands
      run_command "systemctl stop rpcbind.socket"
      run_command "systemctl disable rpcbind.socket"
      run_command "systemctl mask rpcbind.socket"
      run_command "systemctl stop rpcbind.service"
      run_command "systemctl disable rpcbind.service"
      run_command "systemctl mask rpcbind.service"
      run_command "systemctl stop portmap"
      run_command "systemctl disable portmap"
      run_command "systemctl mask portmap"
      
      # SysV init commands
      run_command "service rpcbind stop"
      run_command "/etc/init.d/rpcbind stop"
      run_command "update-rc.d rpcbind disable"
      run_command "chkconfig rpcbind off"
      run_command "service portmap stop"
      run_command "/etc/init.d/portmap stop"
      run_command "update-rc.d portmap disable"
      run_command "chkconfig portmap off"
    fi
    
    # Additional methods since init is listening on port 111
    echo ""
    echo "Applying additional measures to ensure services are disabled..."
    
    # Check if xinetd is in use (sometimes runs rpcbind)
    if command -v xinetd >/dev/null; then
      echo "Checking for xinetd configuration..."
      if [ -f /etc/xinetd.d/rpcbind ]; then
        echo "Disabling rpcbind in xinetd..."
        echo "disable = yes" >> /etc/xinetd.d/rpcbind
        run_command "service xinetd restart"
      fi
    fi
    
    # Last resort: Kill processes directly
    echo "Killing any remaining rpcbind processes..."
    run_command "pkill -9 rpcbind"
    run_command "pkill -9 portmap"
    
    # Create a firewall rule to block port 111
    echo "Creating firewall rules to block port 111..."
    if command -v ufw >/dev/null; then
      # Ubuntu/Debian firewall
      run_command "ufw deny 111/tcp"
      run_command "ufw deny 111/udp"
    elif command -v firewall-cmd >/dev/null; then
      # CentOS/RHEL firewall
      run_command "firewall-cmd --permanent --add-rich-rule='rule family=\"ipv4\" port port=\"111\" protocol=\"tcp\" reject'"
      run_command "firewall-cmd --permanent --add-rich-rule='rule family=\"ipv4\" port port=\"111\" protocol=\"udp\" reject'"
      run_command "firewall-cmd --reload"
    elif command -v iptables >/dev/null; then
      # Basic iptables
      run_command "iptables -A INPUT -p tcp --dport 111 -j DROP"
      run_command "iptables -A INPUT -p udp --dport 111 -j DROP"
      # Try to save iptables rules if possible
      if [ -f /etc/debian_version ]; then
        run_command "iptables-save > /etc/iptables/rules.v4"
      elif [ -f /etc/redhat-release ]; then
        run_command "service iptables save"
      fi
    fi
    
    echo ""
    echo "RPC services have been disabled."
    ;;
    
  "enable")
    echo ""
    echo "Enabling RPC services..."
    echo "=========================================="
    
    # Remove any firewall rules blocking port 111
    echo "Removing firewall rules..."
    if command -v ufw >/dev/null; then
      run_command "ufw delete deny 111/tcp"
      run_command "ufw delete deny 111/udp"
    elif command -v firewall-cmd >/dev/null; then
      run_command "firewall-cmd --permanent --remove-rich-rule='rule family=\"ipv4\" port port=\"111\" protocol=\"tcp\" reject'"
      run_command "firewall-cmd --permanent --remove-rich-rule='rule family=\"ipv4\" port port=\"111\" protocol=\"udp\" reject'"
      run_command "firewall-cmd --reload"
    elif command -v iptables >/dev/null; then
      run_command "iptables -D INPUT -p tcp --dport 111 -j DROP"
      run_command "iptables -D INPUT -p udp --dport 111 -j DROP"
      # Try to save iptables rules if possible
      if [ -f /etc/debian_version ]; then
        run_command "iptables-save > /etc/iptables/rules.v4"
      elif [ -f /etc/redhat-release ]; then
        run_command "service iptables save"
      fi
    fi
    
    # Try to identify which init system is in use
    echo "Detecting init system..."
    if pidof systemd > /dev/null; then
      echo "Detected systemd init system"
      init_system="systemd"
    elif [ -f /usr/sbin/update-rc.d ]; then
      echo "Detected Debian-style init system"
      init_system="debian"
    elif [ -f /sbin/chkconfig ]; then
      echo "Detected RedHat-style init system"
      init_system="redhat"
    else
      echo "Could not determine init system, will try all methods"
      init_system="unknown"
    fi
    
    # Enable services based on detected init system
    if [ "$init_system" = "systemd" ]; then
      echo "Unmasking and enabling services in systemd..."
      run_command "systemctl unmask rpcbind.socket"
      run_command "systemctl enable rpcbind.socket"
      run_command "systemctl start rpcbind.socket"
      run_command "systemctl unmask rpcbind.service"
      run_command "systemctl enable rpcbind.service"
      run_command "systemctl start rpcbind.service"
      run_command "systemctl unmask portmap.service"
      run_command "systemctl enable portmap.service"
      run_command "systemctl start portmap.service"
    elif [ "$init_system" = "debian" ]; then
      run_command "update-rc.d rpcbind enable"
      run_command "service rpcbind start"
      run_command "update-rc.d portmap enable"
      run_command "service portmap start"
    elif [ "$init_system" = "redhat" ]; then
      run_command "chkconfig rpcbind on"
      run_command "service rpcbind start"
      run_command "chkconfig portmap on"
      run_command "service portmap start"
    else
      # Try everything if init system is unknown
      # systemd commands
      run_command "systemctl unmask rpcbind.socket"
      run_command "systemctl enable rpcbind.socket"
      run_command "systemctl start rpcbind.socket"
      run_command "systemctl unmask rpcbind.service"
      run_command "systemctl enable rpcbind.service"
      run_command "systemctl start rpcbind.service"
      run_command "systemctl unmask portmap.service"
      run_command "systemctl enable portmap.service"
      run_command "systemctl start portmap.service"
      
      # SysV init commands
      run_command "update-rc.d rpcbind enable"
      run_command "chkconfig rpcbind on"
      run_command "service rpcbind start"
      run_command "/etc/init.d/rpcbind start"
      run_command "update-rc.d portmap enable"
      run_command "chkconfig portmap on"
      run_command "service portmap start"
      run_command "/etc/init.d/portmap start"
    fi
    
    # Check if xinetd is in use
    if command -v xinetd >/dev/null; then
      echo "Checking for xinetd configuration..."
      if [ -f /etc/xinetd.d/rpcbind ]; then
        echo "Enabling rpcbind in xinetd..."
        sed -i 's/disable = yes/disable = no/g' /etc/xinetd.d/rpcbind
        run_command "service xinetd restart"
      fi
    fi
    
    echo ""
    echo "RPC services have been enabled."
    ;;
    
  *)
    echo "Invalid option. Please run the script again and enter 'enable' or 'disable'"
    exit 1
    ;;
esac

# Verify the current status
echo ""
echo "Verifying current status of port 111..."
if netstat -tulpn 2>/dev/null | grep 111 || ss -tulpn 2>/dev/null | grep 111; then
  echo "Port 111 is OPEN - RPC services are running"
else
  echo "Port 111 is CLOSED - RPC services are not running"
fi

echo ""
echo "=========================================="
echo "Operation completed!"
echo "=========================================="