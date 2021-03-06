#
# Cookbook Name:: nova
# Recipe:: nova-setup
#
# Copyright 2012, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

# Allow for using a well known db password
if node["developer_mode"]
  node.set_unless["nova"]["db"]["password"] = "nova"
else
  node.set_unless["nova"]["db"]["password"] = secure_password
end

include_recipe "nova::nova-common"
if node['db']['provider'] == 'mysql'
  include_recipe "mysql::client"
  include_recipe "mysql::ruby"
end
if node['db']['provider'] == 'postgresql'
  include_recipe "postgresql::client"
  include_recipe "postgresql::ruby"
end
include_recipe "monitoring"

ks_service_endpoint = get_access_endpoint("keystone-api", "keystone","service-api")
keystone = get_settings_by_role("keystone", "keystone")
keystone_admin_user = keystone["admin_user"]
keystone_admin_password = keystone["users"][keystone_admin_user]["password"]
keystone_admin_tenant = keystone["users"][keystone_admin_user]["default_tenant"]

#creates db and user
#function defined in osops-utils/libraries
if node['db']['provider'] == 'mysql'
  create_db_and_user("mysql",
                     node["nova"]["db"]["name"],
                     node["nova"]["db"]["username"],
                     node["nova"]["db"]["password"])
end
if node['db']['provider'] == 'postgresql'
  create_db_and_user("postgresql",
                     node["nova"]["db"]["name"],
                     node["nova"]["db"]["username"],
                     node["nova"]["db"]["password"])
end

execute "nova-manage db sync" do
  command "nova-manage db sync"
  user "nova"
  group "nova"
  action :run
#  not_if "nova-manage db version && test $(nova-manage db version) -gt 0"
end

monitoring_metric "nova-plugin" do
  type "pyscript"
  script "nova_plugin.py"
  options("Username" => keystone_admin_user,
          "Password" => keystone_admin_password,
          "TenantName" => keystone_admin_tenant,
          "AuthURL" => ks_service_endpoint["uri"])
end
