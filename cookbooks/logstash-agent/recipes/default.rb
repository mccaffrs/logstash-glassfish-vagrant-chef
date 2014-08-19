# logstash agent

# requires Java runtime environment

# run apt-get update

execute "apt-get update" do
  command "apt-get update"
  ignore_failure true
  action :run
end

# install Oracle java 7

include_recipe "java::default"


# create users
user "logstash" do
  home "/opt/logstash-#{node[:logstash][:version]}/"
  shell "/bin/bash"
end

group "adm" do
  action :modify
  members "logstash"
  append true
end

# create directories

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

directory "/var/log/logstash-agent/" do
  user 'logstash'
  group 'logstash'
  mode '0755'
end

# install logstash package

bash 'install logstash' do
  not_if {File.exists?("/opt/logstash-#{node[:logstash][:version]}/bin/logstash.bat")} #maintain idempotency if files already exists
  user "root"
  cwd "/opt/"
  code <<-EOH
    wget https://download.elasticsearch.org/logstash/logstash/logstash-#{node[:logstash][:version]}.tar.gz
    tar -zxf logstash-#{node[:logstash][:version]}.tar.gz
    mv logstash-#{node[:logstash][:version]}.tar.gz /tmp/
	chown -R logstash.logstash /opt/logstash-#{node[:logstash][:version]}/
  EOH
end

# install additional application server packages to test

# apache

#package "apache2" do
#  action :install
#end

package "unzip" do
  action :install
end

# Glassfish

# add install of glassfish here

bash 'install glassfish' do
  not_if {File.exists?("/opt/glassfish4/glassfish/domains/domain1/logs/server.log")} #maintain idempotency if files already exists
  user "root"
  cwd "/opt/"
  code <<-EOH
    wget http://download.java.net/glassfish/4.0/release/glassfish-4.0.zip
    unzip glassfish-4.0.zip -d /opt
    export PATH=/opt/glassfish4/bin:$PATH
	chmod a+w /opt/glassfish4/
	asadmin start-domain
  EOH
end


# configuration files

# Logstash agent config

template "/etc/logstash-#{node[:logstash][:version]}/agent.conf" do
  user 'logstash'
  group 'logstash'
  mode '0644'
  #notifies :restart, 'service[logstash]'   #(this tells service to restart if config changes)
end

# upstart init script
template "logstash-agent.conf" do
  path "/etc/init/logstash-agent.conf"
  source "upstart-logstash-agent.conf.erb"
  owner "root"
  group "root"
  mode "0644"
end

# service starts

# use upstart on Ubuntu to start logstash agent
service "logstash-agent" do
  case node["platform"]
  when "ubuntu"
    if node["platform_version"].to_f >= 9.10
      provider Chef::Provider::Service::Upstart
    end
  end
  action [:enable, :start]
end
