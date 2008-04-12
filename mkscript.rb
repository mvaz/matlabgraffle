#!/usr/bin/env ruby
#
#  Created by Miguel Vaz on 2007-10-08. => 
#  Copyright (c) 2007. All rights reserved.

require 'MatlabGraffle'

if $0 == __FILE__
  with_pleasant_exceptions do

    # define the object to
    # testfile = File.dirname(__FILE__) + '/test2.graffle'
    testfile = ARGV[0]
    doc      = Graffle.parse_file(testfile)


    # Handle first sheet, which contains the main program
    if ARGV.length > 1
      sheet = doc.sheets.select { |s| s['SheetTitle'] == ARGV[1] }[0]
    else
      sheet = doc.first_sheet
    end
    mg    = MatlabGraffle.new
    mg.init_from_sheet(sheet)

    h = mg.zbr
    program = mg.make_normal_flow( h )
    # fout = File.open("/Users/miguel/matlab/M-FILES/CopySynthesis/"+ sheet['SheetTitle']+ ".m", "w+")
    # fout = File.open( sheet['SheetTitle']+ ".m", "w+")
    # fout.puts program
    # fout.close
    
    puts program
    
    # Handle the other sheets, containing sub programs
    # mg1 = MatlabGraffle.new
    # mg1.init_from_sheet(doc.sheets[1])
    # h = mg1.zbr
    # code = mg1.make_virtual_component( doc.sheets[1]['SheetTitle'], h )
    # puts code
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