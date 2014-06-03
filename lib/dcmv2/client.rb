class DCMv2::Client
  include ::HTTParty
  attr_accessor :cache

  def initialize(connection = DCMv2::Connection.new, cache = {})
    @connection = connection
    @cache      = cache
  end

  def available_resources
    self.current_resource.links
  end

  def available_links
    self.current_resource.available_resources
  end

  def available_embedded_resources(resources = embedded_resources, prefix = '')
    if resources.is_a?(DCMv2::Resource)
      return resources.links.collect { |link| prefix + link }
    end

    resources.collect.with_index do |(key, data), index|
      path_parts = []
      unless data
        data = key
        key = index
      end
      self.available_embedded_resources(resources[key], prefix + key.to_s + '/')
    end.flatten
  end

  def data
    self.current_resource.data
  end

  def embedded_data
    self.current_resource.embedded_data
  end

  def go_to!(resource_name, link_options = {})
    update_resource(get_resource(resource_name, link_options))
    return self
  end

  def go_to(resource_name, link_options = {})
    self.class.new(connection, cache).tap do |new_client|
      new_client.current_resource = get_resource(resource_name, link_options)
    end
  end

  def go_to_embedded!(resource_path, link_options = {})
    update_resource(get_embedded_resource(resource_path, link_options))
    return self
  end

  def go_to_embedded(resource_path, link_options = {})
    self.class.new(connection, cache).tap do |new_client|
      new_client.current_resource = get_embedded_resource(resource_path, link_options)
    end
  end

  def embedded_resources
    self.current_resource.embedded_resources
  end

  def back!
    return self if history.empty?

    self.current_resource = history.pop
    return self
  end

  def up!
    return self if at_base_path?

    update_resource(get_resource_by_path(parent_path))
    return self
  end

  def up
    return self if at_base_path?

    jump_to(parent_path)
  end

  def jump_to!(resource_path)
    update_resource(get_resource_by_path(connection.path_for(resource_path)))
    return self
  end

  def jump_to(resource_path)
    self.class.new(connection, cache).tap do |new_client|
      new_client.current_resource = get_resource_by_path(connection.path_for(resource_path))
    end
  end

  def inspect
    %{#<#{self.class}:0x#{self.__id__.to_s(16)} current_path="#{self.current_path}">}
  end

  def current_path
    self.current_resource.path
  end

  def current_resource
    @current_resource ||= DCMv2::Resource.new(connection)
  end

  protected

  attr_accessor :cache
  attr_writer :current_resource

  private

  def at_base_path?
    self.current_path == connection.path_for(nil)
  end

  def parent_path
    self.current_path.split('/')[0..-2].join('/').gsub(/\/accounts$/, '')
  end

  def get_embedded_resource(resource_path, link_options)
    parsed_path = parse_resource_name(resource_path)

    get_resource(parsed_path.resource_name, link_options, traverse_parsed_path(parsed_path))
  end

  def parse_resource_name(resource_name)
    parts = resource_name.split('/')
    parts.collect! { |part| part.to_i.to_s == part ? part.to_i : part }
    OpenStruct.new(path: resource_name, resource_name: parts.pop, parts: parts)
  end

  def get_resource_by_path(path)
    self.cache[path] ||= DCMv2::Resource.new(connection, path)
  end

  def get_resource(resource_name, link_options, source_resource = self.current_resource)
    begin
      self.cache[source_resource.href_for(resource_name, link_options)] ||= source_resource.follow(resource_name, link_options)
    rescue KeyError
      invalid_resource!(resource_name)
    end
  end

  def traverse_parsed_path(parsed_path)
    current_embedded_resource = embedded_resources
    parsed_path.parts.each do |key|
      current_embedded_resource = current_embedded_resource[key] || invalid_resource!(parsed_path.resource_name)
    end
    invalid_resource!(parsed_path.resource_name) unless current_embedded_resource.is_a?(DCMv2::Resource)

    return current_embedded_resource
  end

  def update_resource(resource)
    history << self.current_resource
    self.current_resource = resource
  end

  def history
    @history ||= []
  end

  def invalid_resource!(resource_name)
    raise DCMv2::InvalidResource, "#{resource_name} is not a recognized resource."
  end

  def connection
    @connection
  end
end

