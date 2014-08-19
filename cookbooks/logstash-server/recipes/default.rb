# requires Java runtime environment

# run apt-get update

execute "apt-get update" do
  command "apt-get update"
  ignore_failure true
  action :run
end

# install java
package "openjdk-7-jre" do
  action :install
end

# create users
user "logstash" do
  home "/opt/logstash-#{node[:logstash][:version]}/"
  shell "/bin/bash"
end

user "elasticsearch" do
  home "/opt/elasticsearch-#{node[:elasticsearch][:version]}/"
  shell "/bin/bash"
end

# create directories

directory "/opt/elasticsearch-#{node[:elasticsearch][:version]}/" do
  user 'elasticsearch'
  group 'elasticsearch'
  mode '0755'
end

directory "/etc/elasticsearch" do
  user 'elasticsearch'
  group 'elasticsearch'
  mode '0755'
end

directory "/opt/logstash-#{node[:logstash][:version]}/" do
  user 'logstash'
  group 'logstash'
  mode '0755'
end

directory "/etc/logstash-#{node[:logstash][:version]}/" do
  user 'logstash'
  group 'logstash'
  mode '0755'
end

directory "/var/log/logstash-server/" do
  user 'logstash'
  group 'logstash'
  mode '0755'
end

directory "/etc/redis" do
  user 'redis'
  group 'redis'
  mode '0755'
end

directory "/var/www/" do
  user 'www-data'
  group 'www-data'
  mode '0755'
end

directory "/var/www/kibana" do
  user 'www-data'
  group 'www-data'
  mode '0755'
end

# install packages

bash 'install elasticsearch' do
  not_if "/opt/elasticsearch-#{node[:elasticsearch][:version]}/elasticsearch --version | grep -q '#{node[:elasticsearch][:version]}'" #maintain idempotency if package already exists
  user "root"
  cwd "/opt/elasticsearch-#{node[:elasticsearch][:version]}/"
  code <<-EOH
    wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-#{node[:elasticsearch][:version]}.deb
    dpkg -i elasticsearch-#{node[:elasticsearch][:version]}.deb
    mv elasticsearch-#{node[:elasticsearch][:version]}.deb /var/cache/apt/archives
  EOH
end

bash 'install logstash' do
  not_if {File.exists?("/opt/logstash-#{node[:logstash][:version]}/bin/logstash.bat")} #maintain idempotency if files already exists
  user "root"
  cwd "/opt/"
  code <<-EOH
    wget https://download.elasticsearch.org/logstash/logstash/logstash-#{node[:logstash][:version]}.tar.gz
    tar -zxf logstash-#{node[:logstash][:version]}.tar.gz
    mv logstash-#{node[:logstash][:version]}.tar.gz /tmp/
  EOH
end

bash 'Kibana' do
  not_if {File.exists?("/opt/kibana-#{node[:kibana][:version]}/build.txt")} #maintain idempotency if files already exists
  user "root"
#  cwd "/opt/kibana-#{node[:kibana][:version]}/"
  cwd "/opt/"
  code <<-EOH
    wget https://download.elasticsearch.org/kibana/kibana/kibana-#{node[:kibana][:version]}.tar.gz
    tar -zxf kibana-#{node[:kibana][:version]}.tar.gz
    mv kibana-#{node[:kibana][:version]}.tar.gz /tmp/
    cp -R /opt/kibana-#{node[:kibana][:version]}/* /var/www/kibana/
	chown -R www-data.www-data /var/www/kibana/
  EOH
end

package 'redis-server' do
  action :install
end

# redis kernel config
execute "sysctl" do
  command "sysctl vm.overcommit_memory=1"
  ignore_failure true
  action :run
end

package 'nginx' do
  action :install
end

# configuration files

# elasticsearch configs

template '/etc/default/elasticsearch' do
  user 'elasticsearch'
  group 'elasticsearch'
  mode '0644'
  #notifies :restart, 'service[elasticsearch]'   #(this tells service to restart if config changes)
end

template '/etc/elasticsearch/elasticsearch.yml' do
  user 'elasticsearch'
  group 'elasticsearch'
  mode '0644'
  #notifies :restart, 'service[elasticsearch]'   #(this tells service to restart if config changes)
end

# redis config 

template '/etc/redis/redis.conf' do
  user 'redis'
  group 'redis'
  mode '0644'
  #notifies :restart, 'service[redis-server]'   #(this tells service to restart if config changes)
end

# Logstash config

template "/etc/logstash-#{node[:logstash][:version]}/server.conf" do
  user 'logstash'
  group 'logstash'
  mode '0644'
  #notifies :restart, 'service[logstash]'   #(this tells service to restart if config changes)
end

template '/etc/nginx/sites-available/default' do
  user 'root'
  group 'root'
  mode '0644'
  #notifies :restart, 'service[redis-server]'   #(this tells service to restart if config changes)
end

# service starts

# upstart init script for logstash-server
template "logstash-server.conf" do
  path "/etc/init/logstash-server.conf"
  source "upstart-logstash-server.conf.erb"
  owner "root"
  group "root"
  mode "0644"
end

# use upstart on Ubuntu to start logstash
service "logstash-server" do
  case node["platform"]
  when "ubuntu"
    if node["platform_version"].to_f >= 9.10
      provider Chef::Provider::Service::Upstart
    end
  end
  action [:enable, :start]
end

# disable the default init.d script for redis:
execute "update-rc.d" do
  command "update-rc.d redis-server disable"
  ignore_failure true
  action :run
end

# upstart init script for redis-server
template "redis-server.conf" do
  path "/etc/init/redis-server.conf"
  source "upstart-redis-server.conf.erb"
  owner "root"
  group "root"
  mode "0644"
end

# use upstart on Ubuntu to start redis-server
service "redis-server" do
  case node["platform"]
  when "ubuntu"
    if node["platform_version"].to_f >= 9.10
      provider Chef::Provider::Service::Upstart
    end
  end
  action [:enable, :start]
end

service "nginx" do
  action [:enable, :start]
end

service "elasticsearch" do
  action [:enable, :start]
end
