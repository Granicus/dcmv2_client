DCM v2 API Client
======================
This is a client for interacting with the DCM v2 API.

Installation
------------
### Using Bundler
```ruby
gem 'dcmv2_client'
```

### Standalone
```
$ gem install dcmv2_client
```

Configuring standalone
------------------
This client requires a private key for an account. Once the key has
been obtained, it can be added as the environment variable DCMV2_API_KEY.
For convenience this value can also be assigned in a .env file.
See .env.example for how to set the value.

```ruby
DCMV2_API_KEY = 'my-sekret-api-key'
```

Running standalone
------------------
Once the API key and account ID have been setup, an IRB console with the gem
loaded can be accessed by running from the root directory of the gem:

```
$ rake console
```

Configuring within a project
----------------------------
Within a project, e.g. in a Rails app, the environment variable can be
bypassed and the API key can be assigned directly to the DCMv2 module.
It is recommended to add this value in an initializers file.

*config/initializers/dcmv2.rb*
```ruby
DCMv2.api_key = 'my-sekret-api-key'
```

Navigation
==========
All navigation can be handled by a client. Create one by calling

```ruby
client = DCMv2::Client.new
```

With the client, a user can determine what resources are immediately available
by calling

```ruby
client.available_resources # => ['reports', 'self']
```

To follow one of the listed resources, e.g. 'reports', call

```ruby
client.go_to!('reports')
```

Calling Client#go_to! with an exclamation will redirect the client.
The client is now pointing at the 'reports' resource. The URL of which can
viewed by calling `Client#current_path`. Another call to Client#available_resources
will return a new set of resources that can be accessed from this point.

Back
----
To return to the previous resource, call `client.back!`.

Up
--
To go up a step in the API tree, call `client.up!`

e.g. This will take a user from

```
/api/v2/accounts/1234/reports/performance
```

to

```
/api/v2/accounts/1234/reports
```

Jump to a known resource
------------------------
When the path for a desired resource is known, it's possible to jump directly
to the resource by calling

```ruby
client.jump_to!('/api/v2/accounts/1234/reports')
```

Reading data
============
While parts of the API are simply for navigating the different available
resources, some resources have data associated with them. This can be seen
by calling `client.data`.

Parts of the API may included embedded resources. This is information that may not
be directly tied to the current resource, but is related to it. View this data
by calling `client.embedded_data`

Each resource can contain its own set of data or embedded resources. To
follow an _embedded_ resource, rather than a normal resource, find its name by
calling `client.available_embedded_resources`. Just like `Client#available_resources`
this will return a list of embedded resource paths.

```ruby
client.available_embedded_resources # => ['subscribers/0/prev', 'subscribers/1/prev', ...]
```

These embedded resources can be followed by calling `client.go_to_embedded!`, passing
in one of the provided embedded paths.

Templated links
===============
Each resource has a list of links available to it, which is how the client
knows which resources are available at any given time. Some of these links
are templated, which means the link requires extra information for determining
how to get the next resource. When this is the case, Client#go_to! takes in
a Hash that defines what these values should be. e.g. when the client is
viewing the subscriptions performance report page, the 'find' link can
be used after a year and month are specified.

```ruby
client.current_path        # => /api/v2/accounts/1234/reports/performance/subscriptions
client.available_resources # => ['self', 'prev', 'find']
client.go_to!('find', { year: 2014, month: 5 })
client.current_path        # => /api/v2/accounts/1234/reports/performance/subscriptions/2014/5
```

Example
=======
Many of the resources available from the API include "prev" links which are only present
when previous information is actually available. Using this knowledge, we can build code
that gathers all of the previous subscription sources.

```ruby
client = DCMv2::Client.new
client.jump_to!('/api/v2/accounts/1234/reports/performance/subscriptions')
# Get the latest year's worth of data
client.go_to!('latest_year')
sources = {}
client_data = client.embedded_data
while client_data
  client_data['monthly_reports'].each do |month|
    sources[month['year'].to_s + '/' + month['month'].to_s] = month['sources']
  end
  if client.available_resources.include?('prev')
    client.go_to!('prev')
    client_data = client.embedded_data
  else
    client_data = nil
  end
end
```

After running this code, `sources` will be a Hash where all of the months are the keys, and the
values are embedded hashes with data about how many subscriptions were added by which source each
month.

License
-------
Copyright (c) 2014, GovDelivery, Inc.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
* Neither the name of GovDelivery nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

