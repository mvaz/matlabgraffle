#!/usr/bin/env ruby
#
#  Created by Miguel Vaz on 2007-10-14.
#  Copyright (c) 2007. All rights reserved.

require 'MatlabGraffle'

if $0 == __FILE__
  with_pleasant_exceptions do
    file = 'testInputOrder.graffle'
    doc  = Graffle.parse_file(file)
    graphics = doc.first_sheet.graphics
    
    lines  = graphics.select { |g| g.behaves_like?(Graffle::LineGraphic) }.compact
    # lines.each { |c| puts c['Text'] }
    # puts lines[0].points[1]
    # puts lines[1].to['ID']
    
    rrect  = graphics.select { |g| g.is_function? }.flatten.compact
    rrect.each { |r| puts r['Text'].as_lines[-1] }
    func = rrect[0]
    # puts func
    # puts func.graffle_id
    # ins  = lines.select {|l| l.to['ID'] == func.graffle_id}
    ins = lines.select {|l| l.to['ID'] == func['ID']}.sort {|a,b| a.points[1].x <=> b.points[1].x}
    # ins.each { |i| puts i.from['Text'].as_plain_text}
    
    outs = lines.select {|l| l.from['ID'] == func['ID']}.sort {|a,b| a.points[0].x <=> b.points[0].x}
    # outs.each { |i| puts i.to['Text'].as_plain_text}
    
    v = VirtualComponent.new('',[1, 2],[],[],[])
    puts v.inputs
    # TODO order inputs and ouputs according to this criterium in the connection
    # ins.sort.each {|i| puts l.from['Text'].as_plain_text}
    
    # puts rrect[0]
    
    circles= graphics.select { |g| g.is_variable? }.flatten.compact
    # circles.each {|c| puts c['Text'].as_lines[-1] }
  end
end