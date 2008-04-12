#!/usr/bin/env ruby
#
#  Created by Miguel Vaz on 2007-10-08. => 
#  Copyright (c) 2007. All rights reserved.

require 'MatlabGraffle'

if $0 == __FILE__
  with_pleasant_exceptions do

    file     = ARGV[0]
    doc      = Graffle.parse_file(file)

    # Handle first sheet, which contains the main program
    if ARGV.length == 1
      sheet = doc.first_sheet
    else
      sheet = doc.sheets.select{ |s| s['SheetTitle'] == ARGV[1] }.flatten[0]
    end

    # Handle the other sheets, containing sub programs
    mg = MatlabGraffle.new

    mg.init_from_sheet(sheet)
    h = mg.zbr

    code = mg.make_virtual_component( sheet['SheetTitle'], h )

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
