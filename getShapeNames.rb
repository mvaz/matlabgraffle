#!/usr/bin/env ruby
#
#  Created by Miguel Vaz on 2007-10-14.
#  Copyright (c) 2007. All rights reserved.

require 'MatlabGraffle2'

if $0 == __FILE__
  with_pleasant_exceptions do
    
    file = 'testInputOrder.graffle'
    doc  = Graffle.parse_file(file)
    graphics = doc.first_sheet.graphics
    
    # graphics.select{ |g| g.behaves_like?(Graffle::ShapedGraphic)}.compact
    variables = graphics.select { |g| g.is_variable? }
    components = graphics.select { |g| g.is_component? }
    vcomponents = graphics.select { |g| g.is_virtual_component? }
    codes = graphics.select { |g| g.is_code_block? }
    
    lines = graphics.select { |l| l.behaves_like?(Graffle::LineGraphic)}
    puts lines[0]
    # puts "Number of variables:  " + variables.length.to_s
    # puts "Number of components: " + components.length.to_s
    # puts "Number of vcomponents: " + vcomponents.length.to_s
    # puts "Number of codes blocks: " + codes.length.to_s

    # puts components[0].clean_name.class
    # puts components[0].clean_notes.class
    puts components[0]
    
    puts variables[0]
    puts variables[0].clean_name
  end
end