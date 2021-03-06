require 'open3'
require 'vcloud/fog'

require 'vcloud/core/version'

require 'vcloud/core/config_loader'
require 'vcloud/core/config_validator'
require 'vcloud/core/entity'
require 'vcloud/core/metadata_helper'
require 'vcloud/core/compute_metadata'
require 'vcloud/core/vdc'
require 'vcloud/core/edge_gateway'
require 'vcloud/core/edge_gateway_interface'
require 'vcloud/core/vm'
require 'vcloud/core/vapp'
require 'vcloud/core/vapp_template'
require 'vcloud/core/org_vdc_network'
require 'vcloud/core/query'

module Vcloud
  module Core

    def self.logger
      @logger ||=Logger.new(STDOUT)
    end

  end
end
