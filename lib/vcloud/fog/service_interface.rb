require 'forwardable'

module Vcloud
  module Fog
    class ServiceInterface
      extend Forwardable

      def_delegators :@fog, :get_vapp, :organizations, :org_name, :delete_vapp, :vcloud_token, :end_point,
                     :get_execute_query, :get_vapp_metadata, :power_off_vapp, :shutdown_vapp, :session,
                     :post_instantiate_vapp_template, :put_memory, :put_cpu, :power_on_vapp, :put_vapp_metadata_value,
                     :put_vm, :get_edge_gateway, :get_network, :delete_network, :post_create_org_vdc_network,
                     :post_configure_edge_gateway_services

      #########################
      # FogFacade Inner class to represent a logic free facade over our interactions with Fog

      class FogFacade
        def initialize
          @vcloud = ::Fog::Compute::VcloudDirector.new
        end

        def get_vdc(name)
          @vcloud.get_vdc(name).body
        end

        def get_organization (name)
          @vcloud.get_organization(name).body
        end

        def session
          @vcloud.get_current_session.body
        end

        def get_vapps_in_lease_from_query(options)
          @vcloud.get_vapps_in_lease_from_query(options).body
        end

        def get_catalog_item(id)
          @vcloud.get_catalog_item(id).body
        end

        def post_instantiate_vapp_template(vdc, template, name, params)
          Vcloud::Core.logger.info("instantiating #{name} vapp in #{vdc[:name]}")
          vapp = @vcloud.post_instantiate_vapp_template(extract_id(vdc), template, name, params).body
          @vcloud.process_task(vapp[:Tasks][:Task])
          @vcloud.get_vapp(extract_id(vapp)).body
        end

        def put_memory(vm_id, memory)
          Vcloud::Core.logger.info("putting #{memory}MB memory into VM #{vm_id}")
          task = @vcloud.put_memory(vm_id, memory).body
          @vcloud.process_task(task)
        end

        def get_vapp(id)
          @vcloud.get_vapp(id).body
        end

        def put_network_connection_system_section_vapp(vm_id, section)
          task = @vcloud.put_network_connection_system_section_vapp(vm_id, section).body
          @vcloud.process_task(task)
        end

        def put_cpu(vm_id, cpu)
          Vcloud::Core.logger.info("putting #{cpu} CPU(s) into VM #{vm_id}")
          task = @vcloud.put_cpu(vm_id, cpu).body
          @vcloud.process_task(task)
        end

        def put_vm(id, name, options={})
          Vcloud::Core.logger.info("updating name : #{name}, :options => #{options} in vm : #{id}")
          task = @vcloud.put_vm(id, name, options).body
          @vcloud.process_task(task)
        end

        def vcloud_token
          @vcloud.vcloud_token
        end

        def end_point
          @vcloud.end_point
        end

        def put_guest_customization_section_vapp(vm_id, customization_req)
          task = @vcloud.put_guest_customization_section_vapp(vm_id, customization_req).body
          @vcloud.process_task(task)
        end

        def get_execute_query(type=nil, options={})
          @vcloud.get_execute_query(type, options).body
        end

        def get_vapp_metadata(id)
          @vcloud.get_vapp_metadata(id).body
        end


        def organizations
          @vcloud.organizations
        end

        def org_name
          @vcloud.org_name
        end

        def delete_vapp(vapp_id)
          task = @vcloud.delete_vapp(vapp_id).body
          @vcloud.process_task(task)
        end

        def get_network(id)
          @vcloud.get_network(id).body
        end

        def delete_network(id)
          task = @vcloud.delete_network(id).body
          @vcloud.process_task(task)
        end

        def post_create_org_vdc_network(vdc_id, name, options)
          Vcloud::Core.logger.info("creating #{options[:fence_mode]} OrgVdcNetwork #{name} in vDC #{vdc_id}")
          attrs = @vcloud.post_create_org_vdc_network(vdc_id, name, options).body
          @vcloud.process_task(attrs[:Tasks][:Task])
          get_network(extract_id(attrs))
        end

        def post_configure_edge_gateway_services(edgegw_id, config)
          Vcloud::Core.logger.info("Updating EdgeGateway #{edgegw_id}")
          begin
            task = @vcloud.post_configure_edge_gateway_services(edgegw_id, config).body
            @vcloud.process_task(task)
          rescue Exception => ex
            Vcloud::Core.logger.error("Could not update EdgeGateway #{edgegw_id} : #{ex}")
            raise
          end
        end

        def power_off_vapp(vapp_id)
          task = @vcloud.post_power_off_vapp(vapp_id).body
          @vcloud.process_task(task)
        end

        def power_on_vapp(vapp_id)
          Vcloud::Core.logger.info("Powering on vApp #{vapp_id}")
          task = @vcloud.post_power_on_vapp(vapp_id).body
          @vcloud.process_task(task)
        end

        def shutdown_vapp(vapp_id)
          task = @vcloud.post_shutdown_vapp(vapp_id).body
          @vcloud.process_task(task)
        end

        def get_catalog(id)
          @vcloud.get_catalog(id).body
        end

        def put_vapp_metadata_value(id, k, v)
          Vcloud::Core.logger.info("putting metadata pair '#{k}'=>'#{v}' to #{id}")
          # need to convert key to_s since Fog 0.17 borks on symbol key
          task = @vcloud.put_vapp_metadata_item_metadata(id, k.to_s, v).body
          @vcloud.process_task(task)
        end

        def get_edge_gateway(id)
          @vcloud.get_edge_gateway(id).body
        end

        private
        def extract_id(link)
          link[:href].split('/').last
        end
      end
      #
      #########################



      def initialize (fog = FogFacade.new)
        @fog = fog
      end

      def org
        link = session[:Link].select { |l| l[:rel] == RELATION::CHILD }.detect do |l|
          l[:type] == ContentTypes::ORG
        end
        @fog.get_organization(link[:href].split('/').last)
      end

      def get_vapp_by_name_and_vdc_name name, vdc_name
        response_body = @fog.get_vapps_in_lease_from_query({:filter => "name==#{name}"})
        response_body[:VAppRecord].detect { |record| record[:vdcName] == vdc_name }
      end

      def vdc(name)
        link = org[:Link].select { |l| l[:rel] == RELATION::CHILD }.detect do |l|
          l[:type] == ContentTypes::VDC && l[:name] == name
        end
        raise "vdc #{name} cannot be found" unless link
        @fog.get_vdc(link[:href].split('/').last)

      end

      def put_network_connection_system_section_vapp(vm_id, section)
        begin
          Vcloud::Core.logger.info("adding NIC into VM #{vm_id}")
          @fog.put_network_connection_system_section_vapp(vm_id, section)
        rescue
          Vcloud::Core.logger.info("failed to put_network_connection_system_section_vapp for vm : #{vm_id} ")
          Vcloud::Core.logger.info("requested network section : #{section.inspect}")
          raise
        end
      end

      def find_networks(network_names, vdc_name)
        network_names.collect do |network|
          vdc(vdc_name)[:AvailableNetworks][:Network].detect do |l|
            l[:type] == ContentTypes::NETWORK && l[:name] == network
          end
        end
      end

      def put_guest_customization_section(vm_id, vm_name, script)
        begin
          Vcloud::Core.logger.info("configuring guest customization section for vm : #{vm_id}")
          customization_req = {
            :Enabled             => true,
            :CustomizationScript => script,
            :ComputerName        => vm_name
          }
          @fog.put_guest_customization_section_vapp(vm_id, customization_req)
        rescue
          Vcloud::Core.logger.info("=== interpolated preamble:")
          Vcloud::Core.logger.info(script)
          raise
        end
      end

      private
      def extract_id(link)
        link[:href].split('/').last
      end

    end

  end
end

