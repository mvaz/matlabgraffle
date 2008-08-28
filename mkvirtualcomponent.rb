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
    code = mg.make_virtual_component( sheet['SheetTitle'] )

    puts code

  end
end
