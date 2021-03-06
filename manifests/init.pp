# == Class: pypi
#
# Install and configure a local pypi.
#
# === Requires
#
# puppetlabs-apache
#
# === Parameters
#
# [*pypi_http_password*]
#   Set the password for uploads.
#   Default: '1234'
#
# [*pypi_port*]
#   Port for apache to listen on.
#   Default: 80
#
# [*pypi_root*]
#   Directory to install pypi and keep packages.
#   Default: /var/pypi
#
# === Examples
#
#   include pypi
#
#   class { 'pypi':
#     pypi_http_password => hiera('my_secret_pypi_key'),
#     pypi_port          => '8080',
#     pypi_root          => '/srv/pypi',
#   }
#
# === Authors
#
# Thomas Van Doren
#
# === Copyright
#
# Copyright 2012 Cozi Group, Inc., unless otherwise noted
#
class pypi (
  $pypi_http_password = '1234',
  $pypi_port = '80',
  $pypi_root = '/var/pypi',
  ) {
  group { 'pypi':
    ensure => present,
  }
  user { 'pypi':
    ensure  => present,
    gid     => 'pypi',
    home    => '/home/pypi',
    require => Group['pypi'],
  }

  file { [ '/home/pypi', $pypi_root, "${pypi_root}/packages" ]:
    ensure => directory,
    owner  => 'pypi',
    group  => 'pypi',
  }
  file { 'pypiserver_wsgi.py':
    ensure  => present,
    path    => "${pypi_root}/pypiserver_wsgi.py",
    owner   => 'pypi',
    group   => 'pypi',
    mode    => '0755',
    content => template('pypi/pypiserver_wsgi.py'),
    notify  => Service['httpd'],
  }

  exec { 'create-htaccess':
    command => "/usr/bin/htpasswd -sbc ${pypi_root}/.htaccess pypiadmin ${pypi_http_password}",
    user    => 'pypi',
    group   => 'pypi',
    creates => "${pypi_root}/.htaccess",
    require => Package['httpd'],
    notify  => Service['httpd'],
  }

  include apache
  #include apache::mod::wsgi
  class {'apache::mod::wsgi':
     wsgi_socket_prefix => '/var/run/wsgi'
  }
  apache::vhost { 'pypi':
    priority      => '10',
    port          => $pypi_port,
    docroot       => $pypi_root,
    docroot_owner => 'pypi',
    docroot_group => 'pypi',
    wsgi_script_aliases => {'/' => "${pypi_root}/pypiserver_wsgi.py"},
    wsgi_process_group  => 'pypi',
    wsgi_daemon_process => 'pypi user=pypi group=pypi processes=1 threads=5 maximum-requests=500 umask=0007 display-name=wsgi-pypi inactivity-timeout=300',
#    template      => 'pypi/vhost-pypi.conf.erb',
    custom_fragment => template('pypi/vhost-pypi.conf.erb'),
  }

  package { 'python-pip':
    ensure => present,
  }
  package { ['passlib', 'pypiserver']:
    ensure   => present,
    provider => 'pip',
    notify   => Service['httpd'],
  }
}
