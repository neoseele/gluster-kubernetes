#!/usr/bin/env ruby

require 'json'
require 'pp'

input = File.open(ARGV[0]).map do |node|
  node.strip.split(' ')
end

clusters = []
nodes = []

input.each_with_index do |value,index|
  zone = index + 1
  hostname = value[0]
  ip = value[3]

  node = {
    'node' => {
      'hostnames' => 
          {
            'manage' => [hostname], 
            'storage' => [ip],
          },
      'zone' => zone
    },
    'devices' => ['/dev/sdb']
  }

  nodes << node
end

clusters << {'nodes' => nodes}

out = {'clusters' => clusters}
puts JSON.pretty_generate(out)
