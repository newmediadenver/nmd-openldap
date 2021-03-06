#
# Cookbook Name:: nmd-openldap
# Recipe File:: ppolicy
#
# Copyright 2013, Christophe Arguel <christophe.arguel@free.fr>
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

class Chef::Recipe
  include CAOpenldap
end

#configure module
openldap_module "ppolicy" do
  action :run
end

my_root_dn = build_rootdn()
ldap_config = Chef::Recipe::LDAPConfigUtils.new
ldap = Chef::Recipe::LDAPUtils.new(node.nmd_openldap.ldap_server, node.nmd_openldap.ldap_port, my_root_dn, node.nmd_openldap.rootpassword)


tmp_ppolicy_overlay_ldif = "/tmp/ppolicy_overlay.ldif"

# temporary LDIF files
file "#{tmp_ppolicy_overlay_ldif}" do
  action :nothing
end

# Create the ppolicy overlay definition LDIF
template "#{tmp_ppolicy_overlay_ldif}" do
  source "overlay/ppolicy_overlay.ldif"
  backup false
  mode 0600
  owner "root"
  group "root"
  notifies :run, "execute[ppolicy_overlay]", :immediately
  notifies :delete, "file[#{tmp_ppolicy_overlay_ldif}]"
  not_if {ldap_config.contains?(base: "cn=config", filter: "olcOverlay=ppolicy")}
end

# Add the overlay definition into the On Line Configuration
execute "ppolicy_overlay" do
  command "ldapadd -Y EXTERNAL -H ldapi:/// -D cn=admin,cn=config < #{tmp_ppolicy_overlay_ldif}"
  action :nothing
end

# Add the ppolicy default config into the On Line Configuration
ruby_block "ppolicy_config" do
  block do
    attrs = {
      objectClass: ["pwdPolicy", "person", "top"],
      sn: "PPolicy default config"
    }.merge(node.nmd_openldap.ppolicy_default_config)

    ppolicy_default_config_dn = [node.nmd_openldap.ppolicy_default_config_dn, node.nmd_openldap.basedn].join(",")
    ldap.add_or_update_entry(ppolicy_default_config_dn, attrs)
  end
  action :create
end
