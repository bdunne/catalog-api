=begin
Insights Service Catalog API

This is a API to fetch and order catalog items from different cloud sources

OpenAPI spec version: 1.0.0
Contact: you@your-company.com
Generated by: https://github.com/swagger-api/swagger-codegen.git

=end

require 'rest_client'
require 'json'

class Provider < ApplicationRecord
  validates_presence_of :name
  validates_presence_of :url
  validates_presence_of :token
  after_initialize :set_defaults, unless: :persisted?
  USER_ATTRIBUTES = %w(name url token userid verify_ssl)

  def to_hash
    attributes.slice(*USER_ATTRIBUTES).merge(:id => id.to_s)
  end

  def fetch_catalog_items(catalog_id = nil)
    response = get_response(catalog_url)
    parsed_data = JSON.parse(response.body)
    parsed_data['items'].each.collect do |item|
      next if catalog_id && catalog_id != item['metadata']['name']
      external = item['spec']['externalMetadata'] || {}
      {
         :catalog_id  => item['metadata']['name'],
         :name        => external['displayName'] || "Not provided",
         :description => external['longDescription'] || "Not provided",
         :provider_id => id,
         :imageUrl    => imageUrl(external)
      }
    end.compact
  end

  def imageUrl(metadata)
    iconClass = metadata['console.openshift.io/iconClass']
    if iconClass
      icon = iconClass.split('icon-').last
      URI.join(url, "console/images/logos/#{icon}.svg").to_s
    end
  end

  def fetch_catalog_plans(catalog_id)
    response = get_response(plan_url)
    parsed_data = JSON.parse(response.body)
    parsed_data['items'].each.collect do |item|
      next if catalog_id && catalog_id != item['spec']['clusterServiceClassRef']['name']
      {
         :plan_id     => item['metadata']['name'],
         :catalog_id  => catalog_id,
         :name        => item['spec']['externalName'],
         :description => item['spec']['description'],
         :provider_id => "#{id}"
      }
    end.compact
  end

  def fetch_catalog_plan_parameters(catalog_id, plan_id)
    response = get_response(plan_url)
    parsed_data = JSON.parse(response.body)
    result = parsed_data['items'].each.detect { |item| item['spec']['clusterServiceClassRef']['name'] == catalog_id }
    return [] unless result
    collect_plan_parameters(result['spec']['instanceCreateParameterSchema'])
  end

  def collect_plan_parameters(parameters)
    attributes = %w(default description title type enum format)
    keys = parameters['properties'].keys
    keys.each.collect do |key|
      item = parameters['properties'][key]
      {'name' => key } .tap do |hash|
        attributes.each do |attr|
          hash[attr] = item[attr] if item.key?(attr)
        end
      end
    end
  end

  def order_catalog(catalog_id, plan_id, parameters)
    "#{id}_ref1"
  end

  def get_response(url)
    headers = { :Authorization => "Bearer #{token}" }
    RestClient::Request.new(:method     => :get,
                            :url        => url,
                            :headers    => headers,
                            :verify_ssl => verify_ssl).execute
  end


  def catalog_url
    URI.join(url, "apis/servicecatalog.k8s.io/v1beta1/clusterserviceclasses").to_s
  end

  def plan_url
    URI.join(url, "apis/servicecatalog.k8s.io/v1beta1/clusterserviceplans").to_s
  end

  def set_defaults
    self.verify_ssl = true if self.verify_ssl.nil?
  end
end
