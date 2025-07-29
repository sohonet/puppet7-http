class http {
    
    package { ['sinatra','rack','webrick']:
        ensure      => present,
        provider    => 'gem', 
    }

}
