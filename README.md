# puppet7-http

A Puppet module for HTTP operations and webhook listeners, updated for Ruby 3 and Puppet 7+ compatibility.

## Overview

This module provides two main capabilities:
1. **HTTP Provider**: Make HTTP GET/POST requests from Puppet manifests
2. **Webhook Listener**: Create systemd-managed webhook services that can execute commands via HTTP endpoints

## Requirements

- Puppet 7.0+
- Ruby 3.0+
- systemd (for webhook listeners)
- Required gems: `sinatra`, `webrick`, `rack` (automatically installed)

## HTTP Provider

Execute HTTP requests from within Puppet manifests.

### GET Request Example
```puppet
http { 'health_check':
  ensure => get,
  port   => '8080',
  fqdn   => 'api.example.com',
}
```

### POST Request Example
```puppet
http { 'notify_deployment':
  ensure => post,
  port   => '3000',
  fqdn   => 'webhook.example.com',
  data   => {
    'hostname'    => $facts['networking']['fqdn'],
    'environment' => $environment,
    'status'      => 'deployed'
  }
}
```

## Webhook Listener

Create HTTP webhook endpoints that execute system commands.

### Basic Usage
```puppet
include http

http::listener { 'puppet-webhook':
  port   => 6969,
  routes => {
    'run_puppet' => {
      'method'  => 'get',
      'command' => '/opt/puppetlabs/bin/puppet agent -t'
    },
    'restart_service' => {
      'method'  => 'post', 
      'command' => '/bin/systemctl restart myapp'
    }
  }
}
```

### SSL Configuration
```puppet
http::listener { 'secure-webhook':
  port        => 8443,
  ssl_enable  => true,
  cert_path   => '/etc/ssl/certs/webhook.crt',
  key_path    => '/etc/ssl/private/webhook.key',
  routes      => {
    'deploy' => {
      'method'  => 'post',
      'command' => '/usr/local/bin/deploy.sh'
    }
  }
}
```

## Parameters

### http::listener Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `routes` | Hash | `{}` | Hash of route definitions (see Routes section) |
| `port` | Stdlib::Port | **required** | Port to listen on |
| `ssl_enable` | Boolean | `false` | Enable SSL/TLS |
| `cert_path` | Optional[Stdlib::Absolutepath] | `undef` | SSL certificate path |
| `key_path` | Optional[Stdlib::Absolutepath] | `undef` | SSL private key path |
| `rack_env` | Enum['development', 'production', 'test'] | `'production'` | Rack environment |
| `bind_address` | Stdlib::IP::Address | `'0.0.0.0'` | Address to bind to |

### Route Definition

Each route in the `routes` hash must contain:
- `method`: HTTP method (`'get'` or `'post'`)
- `command`: Shell command to execute

```puppet
routes => {
  'route_name' => {
    'method'  => 'get',
    'command' => '/path/to/command'
  }
}
```

## HTTP Response Codes

The webhook listener returns appropriate HTTP status codes based on command execution:

### Puppet Agent Integration
When using `/opt/puppetlabs/bin/puppet agent -t`:

| Puppet Exit Code | HTTP Status | Response Message |
|------------------|-------------|------------------|
| 0 | 200 OK | "Puppet run succeeded - no changes needed" |
| 2 | 200 OK | "Puppet run succeeded - changes applied" |
| 4 | 207 Multi-Status | "Puppet run completed with some failures" |
| 6 | 207 Multi-Status | "Puppet run completed with changes and failures" |
| 1 | 500 Internal Server Error | "Puppet run failed" |
| Other | 500 Internal Server Error | "Puppet run failed with unexpected exit code: X" |

### General Command Execution
For other commands, standard HTTP status codes apply based on exit status.

## Security Recommendations

### Network Security (nftables/iptables)
**CRITICAL**: Always restrict webhook access to trusted sources.

Example nftables rules:
```puppet
profiles::nftables::simple_rules:
  "puppet_webhook":
    chain: "INPUT"
    protocol: "tcp"
    destination_port: 6969
    source:
      - "10.0.0.0/8"           # Internal network
      - "192.168.1.100/32"     # Specific CI server
    action: "accept"
    comment: "Allow Puppet webhook from trusted sources"
```

### SSL/TLS
For production deployments, always enable SSL:
- Use proper CA-signed certificates
- Restrict cipher suites appropriately
- Consider client certificate authentication for enhanced security

### Command Security
- Use absolute paths for commands
- Validate command inputs if processing user data
- Run webhook service with minimal required privileges
- Use systemd security features where appropriate

## Architecture

### Service Management
- Uses systemd for service management
- Automatic restart on failure
- Proper signal handling for graceful shutdown
- Logging to `/usr/local/bin/webhook_<name>/logs/`

### Logging
- **Server log**: `/usr/local/bin/webhook_<name>/logs/server.log`
- **Session log**: `/usr/local/bin/webhook_<name>/logs/session.log`
- All command execution and output logged for debugging

### Process Model
- Single-threaded Sinatra application
- WEBrick HTTP server
- Command execution via `IO.popen`
- Comprehensive error handling and logging

## Troubleshooting

### Common Issues

**Webhook not responding**:
- Check systemd service status: `systemctl status webhook_<name>`
- Review logs in `/usr/local/bin/webhook_<name>/logs/`
- Verify firewall rules allow connections

**Commands failing with permission errors**:
- Ensure webhook service runs with appropriate privileges
- Check systemd service configuration
- Verify command paths and permissions

**SSL certificate errors**:
- Validate certificate and key file paths
- Check certificate validity and chain
- Ensure proper file permissions on certificate files

### Debugging

Enable debug logging by setting `rack_env => 'development'` and reviewing the session log for detailed command execution traces.

## Migration from puppet-http

This module is an updated version of the original `malnick-http` module with:
- Ruby 3 compatibility
- Puppet 7+ support  
- systemd service management
- Enhanced error handling
- Modern security practices
- Improved logging and debugging

## License

Apache-2.0

## Contributing

Issues and pull requests welcome at the module repository.