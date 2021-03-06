#
# Cookbook Name:: nmd-openldap
# Recipe File:: dit
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

chef_gem 'net-ldap'

class Chef::Recipe
  include CAOpenldap
end

require 'net/ldap'

include_recipe 'nmd-openldap::default'

my_root_dn = build_rootdn()

ruby_block "Create_DIT" do
  block do

    # Get the DIT definition.
    # First check if a 'dit' data bag item exists, and return the 'dit' hash included in this data bag item.
    # Otherwise return the node attribute cg.openldap.dit data bag item.
    # Otherwise return the node attribute cg.openldap.dit.
    def get_dit_definition
      if data_bag('nmd_openldap') && data_bag('nmd_openldap').include?('dit')
        Chef::Log.info 'load dit data bag'
        if node.nmd_openldap.use_encrypted_databags == :yes
          Chef::EncryptedDataBagItem.load('nmd_openldap', 'dit')["dit"]
        else
          Chef::DataBagItem.load('nmd_openldap', 'dit')["dit"]
        end
      else
        node.nmd_openldap.dit
      end
    end

    lu = LDAPUtils.new(node.nmd_openldap.ldap_server, node.nmd_openldap.ldap_port, my_root_dn, node.nmd_openldap.rootpassword)

    # The parse method is defined dynamically in order to have access to the lu variable.
    # This is a recursive method.
    self.define_singleton_method(:parse) do |branch, context= nil|
      branch.each do |dn, entry|
        dn += ",#{context}" if context
        attrs = entry["attrs"].merge(LDAPUtils.first_item(dn))
        lu.add_entry dn, attrs
        parse(entry["children"], dn) if entry.has_key? "children"
      end
    end

    dit = get_dit_definition
    parse dit
  end
end
