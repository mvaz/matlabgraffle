#!/usr/bin/env ruby
#
#  Created by Miguel Vaz on 2007-10-14.
#  Copyright (c) 2007. All rights reserved.

require 'MatlabGraffle2'

if $0 == __FILE__
  with_pleasant_exceptions do
    
    file = 'graphs/testInputOrder.graffle'
    doc  = Graffle.parse_file(file)
    sheet = doc.first_sheet
    sheet = doc.sheets.select { |s| s['SheetTitle'] == 'computeSpeechParameters' }[0]
    graphics = sheet.graphics

     # a = graphics.select { |g| g['Class'] == 'TableGroup' }
     
     # a[0]['Graphics'].each { |g| puts g }
     
     # graphics.each { |g| puts g['Shape']}
     # Handle the other sheets, containing sub programs
     # puts "create MatlabGraffle"
     mg = MatlabGraffle.new
     mg.init_from_sheet( sheet )
     # notes = graphics.select { |g| g.is_code_block? }.compact
     # puts notes[0].values[1].as_lines[-1]


    # puts "make code"
     code = mg.make_script#( sheet['SheetTitle'] ? sheet['SheetTitle'] : 'test'  )
    # puts "code is done"
    # puts code
     # puts code
     # TODO maybe use the name of the sheet to name the file
     # make a composite document
     # make a function to spit out a "virtual component"

     # fout = File.open("/Users/miguel/matlab/M-FILES/CopySynthesis/init" + doc.sheets[1]['SheetTitle']  + ".m", "w+")
     # fout.puts code
     # fout.close
     puts code
  end
end