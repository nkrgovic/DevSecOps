class rocky_setup {

  # Set the hostname
  exec { 'set_hostname':
    command => 'hostnamectl set-hostname myhost.mydomain.tld',
    unless  => "[ \"$(hostname)\" = \"myhost.mydomain.tld\" ]",
  }

  # Ensure required packages are installed
  package { [ 'firewalld', 'nginx', 'certbot' ]:
    ensure => installed,
  }

  # Start and enable firewalld
  service { 'firewalld':
    ensure => running,
    enable => true,
    require => Package['firewalld'],
  }

  # Configure FirewallD rules
  exec { 'allow_http':
    command => 'firewall-cmd --permanent --add-service=http',
    unless  => 'firewall-cmd --list-services | grep http',
    require => Service['firewalld'],
  }

  exec { 'allow_https':
    command => 'firewall-cmd --permanent --add-service=https',
    unless  => 'firewall-cmd --list-services | grep https',
    require => Service['firewalld'],
  }

  exec { 'allow_ssh_specific':
    command => 'firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=1.2.3.4 service name=ssh accept"',
    unless  => 'firewall-cmd --list-rich-rules | grep 1.2.3.4',
    require => Service['firewalld'],
  }

  exec { 'reload_firewalld':
    command => 'firewall-cmd --reload',
    require => [ Exec['allow_http'], Exec['allow_https'], Exec['allow_ssh_specific'] ],
  }

  # Ensure Nginx service is running
  service { 'nginx':
    ensure => running,
    enable => true,
    require => Package['nginx'],
  }

  # Create Nginx vhost configuration
  file { '/etc/nginx/conf.d/myhost.mydomain.tld.conf':
    ensure  => file,
    content => """
      server {
          listen 80;
          server_name myhost.mydomain.tld;
          root /var/www/myhost;
          index index.html;

          location / {
              try_files $uri $uri/ =404;
          }
      }
    """,
    require => Package['nginx'],
  }

  # Create web root directory
  file { '/var/www/myhost':
    ensure  => directory,
    owner   => 'nginx',
    group   => 'nginx',
    mode    => '0755',
    require => Package['nginx'],
  }

  # Create index.html file
  file { '/var/www/myhost/index.html':
    ensure  => file,
    content => '<h1>Welcome to myhost.mydomain.tld</h1>',
    owner   => 'nginx',
    group   => 'nginx',
    mode    => '0644',
    require => File['/var/www/myhost'],
  }
}
