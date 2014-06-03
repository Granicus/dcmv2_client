class DCMv2::Resource
  attr_reader :path

  def initialize(connection, path = '/api/v2')
    @connection = connection
    @path       = path
  end

  def links
    available_resources.keys
  end

  def follow(resource_name, templated_options = {})
    return self if resource_name == 'self'
    self.class.new(connection, href_for(resource_name, templated_options))
  end

  def href_for(resource_name, templated_options = {})
    link = available_resources.fetch(resource_name)
    href = link['href']
    if link['templated']
      confirm_substitutions!(href = substitute_options(href, templated_options))
    end

    return href
  end

  def confirm_substitutions!(href)
    keys = href.scan(/\{([^}]+)\}/).flatten
    unless keys.empty?
      raise ArgumentError, "Missing replacement values for #{keys.join(', ')}. Fix this by passing in the values as a hash. e.g. { #{keys.collect {|f| "'#{f}' => 'some value'" }.join(', ')} }"
    end
  end

  def data
    resource_data.except('_links', '_embedded')
  end

  def embedded_resources
    return @embedded_resources if @embedded_resources || embedded_data.nil? || embedded_data.empty?

    @embedded_resources = {}
    embedded_data.each do |key, embedded|
      is_array = embedded.nil?
      embedded = key if is_array

      [embedded].flatten.each do |data|
        if data.has_key?('_links')
          resource = DCMv2::Resource.new(connection, data['_links']['self']['href'])
          resource.resource_data = data
          if is_array
            @embedded_resources ||= []
            @embedded_resources << resource
          else
            @embedded_resources[key] ||= []
            @embedded_resources[key] << resource
          end
        end
      end
    end

    return @embedded_resources
  end

  def available_resources
    resource_data['_links']
  end

  def embedded_data
    resource_data['_embedded']
  end

  def inspect
    %{#<#{self.class}:0x#{self.__id__.to_s(16)} path="#{self.path}">}
  end

  protected

  def resource_data=(data)
    @resource_data = data
  end

  private

  def substitute_options(link, options)
    new_link = link
    options.each do |name, value|
      new_link.gsub!("{#{name}}", value.to_s)
    end

    return new_link
  end

  def resource_data
    @resource_data ||= JSON.parse(raw_response)
  end

  def raw_response
    @raw_data ||= connection.make_request(self.path)
  end

  def connection
    @connection
  end
end

