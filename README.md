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

### Custom Response Handling

For applications with specific exit code requirements (like Puppet), you can provide custom response handling logic:

```puppet
$puppet_response_handler = @(RUBY)
  case exit_status
  when 0  # No changes needed
    status 200
    "Puppet run succeeded - no changes needed"
  when 2  # Changes applied successfully
    status 200  
    "Puppet run succeeded - changes applied"
  when 4  # Some failures but run completed
    status 207  # Multi-status
    "Puppet run completed with some failures"
  when 6  # Both changes and failures
    status 207
    "Puppet run completed with changes and failures"
  when 1  # Run failed
    status 500
    "Puppet run failed"
  else
    status 500
    "Puppet run failed with unexpected exit code: #{exit_status}"
  end
  | RUBY

http::listener { 'puppet-webhook':
  port                    => 6969,
  custom_response_handler => $puppet_response_handler,
  routes => {
    'run_puppet' => {
      'method'  => 'get',
      'command' => '/opt/puppetlabs/bin/puppet agent -t'
    }
  }
}
```

The custom handler receives the `exit_status` variable and should set HTTP status codes using `status <code>` and return a response string.

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
| `custom_response_handler` | Optional[String] | `undef` | Custom Ruby code for handling command exit codes |

#### Systemd Security Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `systemd_user` | Optional[String] | `undef` | User to run service as |
| `systemd_group` | Optional[String] | `undef` | Group to run service as |
| `systemd_protect_system` | Optional[Variant[Boolean, Enum['full', 'strict']]] | `undef` | Make file system read-only |
| `systemd_protect_home` | Optional[Boolean] | `undef` | Make /home, /root, /run/user inaccessible |
| `systemd_private_tmp` | Optional[Boolean] | `undef` | Use private /tmp and /var/tmp |
| `systemd_no_new_privileges` | Optional[Boolean] | `undef` | Prevent gaining new privileges |
| `systemd_read_write_paths` | Optional[Array] | `undef` | Paths that should be writable |
| `systemd_read_only_paths` | Optional[Array] | `undef` | Paths that should be read-only |
| `systemd_inaccessible_paths` | Optional[Array] | `undef` | Paths that should be inaccessible |
| `systemd_dynamic_user` | Optional[String] | `undef` | Allocate dynamic user/group |
| `systemd_capability_bounding_set` | Optional[Array] | `undef` | Limit capabilities |
| `systemd_private_devices` | Optional[Enum] | `undef` | Make devices inaccessible |
| `systemd_restrict_address_families` | Optional[Boolean] | `undef` | Restrict to IPv4/IPv6/Unix |
| `systemd_restrict_namespaces` | Optional[Boolean] | `undef` | Restrict namespace access |
| `systemd_lock_personality` | Optional[Boolean] | `undef` | Lock personality(2) |
| `systemd_protect_kernel_tunables` | Optional[Enum] | `undef` | Protect kernel tunables |
| `systemd_protect_kernel_modules` | Optional[Boolean] | `undef` | Prevent kernel module loading |
| `systemd_protect_control_groups` | Optional[Boolean] | `undef` | Protect control group hierarchies |

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

### Default Generic Behavior
By default, the webhook listener returns simple HTTP status codes:

| Command Exit Code | HTTP Status | Response Message |
|------------------|-------------|------------------|
| 0 | 200 OK | "Command succeeded" |
| Non-zero | 500 Internal Server Error | "Command failed with exit code: X" |

### Custom Response Handlers
You can override the default behavior by providing a `custom_response_handler` parameter with Ruby code that maps exit codes to specific HTTP responses. This is particularly useful for applications like Puppet that have meaningful exit codes:

| Puppet Exit Code | HTTP Status | Response Message |
|------------------|-------------|------------------|
| 0 | 200 OK | "Puppet run succeeded - no changes needed" |
| 2 | 200 OK | "Puppet run succeeded - changes applied" |
| 4 | 207 Multi-Status | "Puppet run completed with some failures" |
| 6 | 207 Multi-Status | "Puppet run completed with changes and failures" |
| 1 | 500 Internal Server Error | "Puppet run failed" |
| Other | 500 Internal Server Error | "Puppet run failed with unexpected exit code: X" |

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

### Systemd Security Examples

For webhooks that don't need full system access, enable security restrictions:

#### Basic Security (Recommended for most webhooks)
```puppet
http::listener { 'app-webhook':
  port                          => 8080,
  systemd_user                  => 'webhook',
  systemd_group                 => 'webhook',
  systemd_protect_system        => true,
  systemd_protect_home          => true,
  systemd_private_tmp           => true,
  systemd_no_new_privileges     => true,
  systemd_read_write_paths      => ['/var/lib/myapp', '/var/log/myapp'],
  routes                        => {
    'deploy' => {
      'method'  => 'post',
      'command' => '/usr/local/bin/deploy.sh'
    }
  }
}
```

#### Strict Security (For read-only operations)
```puppet
http::listener { 'status-webhook':
  port                          => 8081,
  systemd_dynamic_user          => true,
  systemd_protect_system        => 'strict',
  systemd_protect_home          => true,
  systemd_private_tmp           => true,
  systemd_private_devices       => 'yes',
  systemd_no_new_privileges     => true,
  systemd_protect_kernel_modules => true,
  systemd_protect_kernel_tunables => 'yes',
  systemd_restrict_namespaces   => true,
  systemd_lock_personality      => true,
  systemd_restrict_address_families => true,
  routes                        => {
    'status' => {
      'method'  => 'get',
      'command' => '/usr/local/bin/check-status.sh'
    }
  }
}
```

#### No Security (Required for system management tasks like Puppet)
```puppet
http::listener { 'puppet-webhook':
  port                          => 6969,
  # No security restrictions - needed for puppet agent
  routes                        => {
    'run_puppet' => {
      'method'  => 'get',
      'command' => '/opt/puppetlabs/bin/puppet agent -t'
    }
  }
}
```

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