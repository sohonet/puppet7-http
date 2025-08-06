class http {

  package { 'ruby-dev':
    ensure => installed,
  }

  package { ['sinatra','rack','webrick', 'rackup', 'puma']:
    ensure   => present,
    provider => 'gem',
    require  => Package['ruby-dev'],
  }

}
