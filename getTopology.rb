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
    
    # graphics.select
    components = graphics.select { |g| g.is_component? }
    variables  = graphics.select { |g| g.is_variable?  }
    notes      = graphics.select { |g| g.is_code_block? }
    
    lines  = graphics.select { |g| g.behaves_like?(Graffle::LineGraphic) }.compact

    # init hashes
    connect   = Hash.new
    comps     = Hash.new
    vars      = Hash.new
    var_names = Hash.new
    # h         = Hash.new


    variables.each do |g|
      v = Variable.new
      v.init_from_graphics(g)

      var_names[ v.get_id ] = v.get_name
      vars[ v.get_id ] = v
      connect[ v.get_id ] = []
      
    end

    # go through components
    components.each do |g|
      c = Component.new
      
      ins = lines.select {|l| l['Head']['ID'] == g['ID']}
      ins.sort! {|a,b| a.points[-1].x <=> b.points[-1].x}
      ins.map! { |l| vars[ l['Tail']['ID'] ] }

      outs = lines.select {|l| l['Tail']['ID'] == g['ID']}
      outs.sort! {|a,b| a.points[0].x <=> b.points[0].x}
      outs.map! { |l| vars[ l['Head']['ID'] ] }

      c.init_from_graphics( g, ins, outs)
      
      connect[ c.get_id ] = []
      comps[   c.get_id ] = c
    end
    

    
    # Line.new
    
    lines.each do |l|
    
         # this is a big source of problems...
         # maybe throw an exception, here?
         head = l['Head']['ID']
         tail = l['Tail']['ID']
    
         from_id = comps.select { |id,g| g.get_id == tail }
         from_id = from_id.flatten[0]
         if from_id == nil
           from_id = tail
         end
    
         to_id = comps.select { |id,g| g.get_id == head  }
         to_id = to_id.flatten[0]
         if to_id == nil
           to_id = head
         end
    
    
         if connect[from_id] == nil
           connect[from_id] = [to_id]
         else
           connect[from_id].push(to_id)
         end
    
    end
    # puts comps
    # puts vars
    
    ordered = connect.tsort.reverse
    
    
    # puts ordered
    ordered.each do |c|
      if comps[c]
        puts comps[c].get_initialization

        puts comps[c].get_compute     
      elsif vars[c]
        puts vars[c].get_code
      end
    end
  end
end