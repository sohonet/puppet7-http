define http::listener (
    Hash $routes = {},
    Boolean $ssl_enable = false,
    Optional[Stdlib::Port] $port = undef,
    Optional[Stdlib::Absolutepath] $cert_path = undef,
    Optional[Stdlib::Absolutepath] $key_path = undef,
    Enum['development', 'production', 'test'] $rack_env = 'production',
    Stdlib::IP::Address $bind_address = '0.0.0.0',
) {
    # Parameter validation
    if $ssl_enable and ($cert_path == undef or $key_path == undef) {
        fail('SSL enabled but cert_path or key_path not provided')
    }
    
    if $port == undef {
        fail('Port parameter is required')
    }

    File {
        mode  => '0750',
        group => 'root',
        owner => 'root',
    }

    file {"/usr/local/bin/webhook_${name}":
        ensure => directory,
    }

    file {"/usr/local/bin/webhook_${name}/lib/":
        ensure => directory,
    }

    file {"webhook_${name}.rb":
        path    => "/usr/local/bin/webhook_${name}/lib/webhook_${name}.rb",
        ensure  => file,
        content => template('http/simple_webhook.rb.erb'),
        mode    => '0640',
        notify  => Service["webhook_${name}"],
    }

    file {"/usr/local/bin/webhook_${name}/logs":
        ensure => directory,
    }

    file {"/usr/local/bin/webhook_${name}/bin":
        ensure => directory,
    }

    file {"/usr/local/bin/webhook_${name}/bin/run":
        ensure  => file,
        content => template('http/run.erb'),
    }

    systemd::unit_file { "webhook_${name}.service":
      content => template('http/systemd.service.erb'),
      notify  => Service["webhook_${name}"],
    }

    service {"webhook_${name}":
        ensure     => running,
        enable     => true,
        require    => [Package['sinatra'],File["/usr/local/bin/webhook_${name}/bin/run", "webhook_${name}.rb"]],
    }
}

