#!/usr/bin/env ruby
#
#  Created by Miguel Vaz on 2007-10-14.
#  Copyright (c) 2007. All rights reserved.

require 'MatlabGraffle2'

if $0 == __FILE__
  with_pleasant_exceptions do
    
    file = 'testInputOrder.graffle'
    doc  = Graffle.parse_file(file)
    sheet = doc.first_sheet
    graphics = sheet.graphics

     # a = graphics.select { |g| g['Class'] == 'TableGroup' }
     
     # a[0]['Graphics'].each { |g| puts g }
     
     # graphics.each { |g| puts g['Shape']}
     # Handle the other sheets, containing sub programs
     # puts "create MatlabGraffle"
     mg = MatlabGraffle.new
# 
    # puts "init MatlabGraffle"
     mg.init_from_sheet( sheet )
     # h = mg.walk_through

    # puts "make code"
     code = mg.make_virtual_component( sheet['SheetTitle'] ? sheet['SheetTitle'] : 'test'  )
    # puts "code is done"
    puts code
     # puts code
     # TODO maybe use the name of the sheet to name the file
     # make a composite document
     # make a function to spit out a "virtual component"

     # fout = File.open("/Users/miguel/matlab/M-FILES/CopySynthesis/init" + doc.sheets[1]['SheetTitle']  + ".m", "w+")
     # fout.puts code
     # fout.close
     # puts code
  end
end