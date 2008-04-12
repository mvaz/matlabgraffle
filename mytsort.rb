#!/usr/bin/env ruby
#
#  Created by Miguel Vaz on 2007-09-13.
#  Copyright (c) 2007. All rights reserved.

require 'tsort'

class Hash
  include TSort
  alias tsort_each_node each_key
  def tsort_each_child(node,&block)
    fetch(node).each(&block)
  end
end

sorted = {1=>[2,3], 2=>[3], 3=>[], 4=>[]}.tsort

sorted = {1=>[2], 13=>[1], 2=>[]}.tsort

puts sorted