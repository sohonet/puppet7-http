class http {

  package { ['sinatra','rack','webrick', 'rackup', 'puma']:
    ensure   => present,
    provider => 'gem',
  }

}
