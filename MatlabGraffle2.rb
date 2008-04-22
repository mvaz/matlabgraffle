#!/usr/bin/env ruby
#
#  Created by Miguel Vaz on 2007-09-13.
#  Copyright (c) 2007. All rights reserved.

### The following adjusts the load path so that the correct version of
### a library is found, no matter where the script is run from.
require 'rubygems'
require 'pathname'

require 's4t-utils'
include S4tUtils

require 'graffle'
require 'tsort'
require 'date'


# amplify class Hash, so that it is possible
# to make a topological sort on it
class Hash
  include TSort
  alias tsort_each_node each_key
  def tsort_each_child(node,&block)
    fetch(node).each(&block)
  end
end

# introduction of some functionality to the classes Group and AbstractGraphic
module Graffle
  
  module Group

    def get_graphics_by_shape( shape )
      self["Graphics"].select { |g| g["Shape"] == shape }
    end

    def get_name
      self["Graphics"].each do |g|
        return g["Text"].as_lines[1] unless g["Shape"] == "Circle"
      end
    end

    def get_main_zbr
      self["Graphics"].select { |g| g["Shape"] != "Circle" }
    end

    def get_notes; return self.notes.as_plain_text; end
    def get_graphics_id; return self["Graphics"].map { |k| k['ID'] }; end

  end

  module AbstractGraphic
    def is_variable?
      return self.behaves_like?(Graffle::ShapedGraphic) && self['Shape'] == 'Circle'
    end

    def is_comment?
      return self.behaves_like?(Graffle::ShapedGraphic) && self['Shape'] == 'Cloud'
    end

    def is_code_block?
      return self.behaves_like?(Graffle::ShapedGraphic) && self['Shape'] == 'NoteShape' #&& 
    end

    def is_component?
      return self.behaves_like?(Graffle::ShapedGraphic) && ( self['Shape'] == 'Rectangle' || self['Shape'] == 'VerticalTriangle' || self['Shape'] == 'RoundRect')
    end
    
    def clean_notes
      txt = self['Notes'] ? self['Notes'].as_lines : []
      txt = txt.map { |l| l.gsub /\\([\{\}])/, '\1' }
      return txt
    end
    
    def clean_name
      txt = self['Text'] ? self['Text'].as_lines[-1] : []
      txt = txt.map { |l| l.gsub /\\([\{\}])/, '\1' }
      return txt.join('\n')
    end

  end

end
  


# TODO at the moment, the distinction between input and output is made 
# through its position: input is above the middle point of the component,
# output is below the same point.
# the relative order is given by the x position 

class Component
  attr_reader :name, :inputs, :outputs, :initialization, :object, :type

  def init(name, inputs = [], outputs = [], initialization = [], object = [], type = 'Normal')
    @name    = name
    @inputs  = inputs
    @outputs = outputs
    @initialization = initialization
    @object  = object
    @type    = type
  end

  def init_from_object( g, inputs = [], outputs = [] )
    name  = g.clean_name

    initialization = g.clean_notes
    object  = g['ID']

    case g['Shape']
    when 'Rectangle'
      type = 'Normal'
    when 'VerticalTriangle'
      type = 'Source'
    when 'RoundRect'
      type = 'Virtual'
    end

    init( name, inputs, outputs, initialization, g, type)
  end

  def to_s
    return ["name" => @name, "init" => @initialization, "inputs" => @inputs, "ouputs" => @outputs].to_s
  end

  def get_id; return @object['ID']; end
  def get_type; return @type; end
  def get_inputs; return @inputs; end
  def get_outputs; return @outputs; end
  def get_name; return @name; end

  def get_initialization
    zbr = @initialization.map { |c| c.gsub /%name%/, self.get_name  }  
    return zbr.join("\n") 
  end
  
  def get_compute

    in_names  = @inputs.map { |i| i.get_name }
    in_names  = [ self.get_name ].concat( in_names )

    out_names = @outputs.map { |o| o.get_name }

    case @type
    when 'Normal', 'Source'
      out_names = [ self.get_name ].concat( out_names )
      txt = "[ " + out_names.join(" ") + "] = compute(" + in_names.join(", ")+ ");"
    when 'Virtual'
      txt = "[ " + out_names.join(" ") + "] = feval(" + in_names.join(", ")+ ");"
    end 

    return txt
  end 
end

class Variable
  attr_reader :name, :code, :object
  def init(name, code = [], object = [] )
    @name = name
    @code = code
    @object = object
  end
  
  def init_from_object(g)
    self.init( g.clean_name, g.clean_notes, g)
  end
    
  def get_id; return @object['ID']; end
  def get_name; return @name; end
  def get_code
    zbr = @code.map { |c| c.gsub /%name%/, self.get_name }
    return zbr.join("\n")
  end
end

class Comment
  attr_reader :object
  def init(object)
    @object  = object
  end

  def get_id; return @object['ID']; end
  
  def get_name; return @object['Text'].as_plain_text; end

  def get_text
    txt = @object['Notes'].as_lines
    txt.map! { |l| l.gsub "^", "% "}
    return txt.join("\n")
  end
end


# define the object that will contain chunks of initialization and end code
class CodeBlock
  attr_reader :name, :object

  def init( name, object = [] )
    @name = name
    @object  = object
  end

  def init_from_object( object )
    @name = object['Text'].as_lines[-1]
    @object = object
  end
  def get_id; return @object['ID']; end
  def get_notes
    txt = @object['Notes'].as_lines
    return txt.join("\n")
  end
end

class MatlabGraffle
  attr_reader :components, :variables, :connections, :code, :boxes, :comments
  def init( comps, vars, connect, code, boxes, comments)
    @components  = comps
    @variables   = vars
    @connections = connect
    @code        = code
    @boxes       = boxes
    @comments    = comments
  end
  
  def init_from_sheet( sheet )
    @components  = Hash.new
    @variables   = Hash.new
    @connections = Hash.new
    @code        = Hash.new
    @boxes       = Hash.new
    @comments    = Hash.new


    # build the variables first, then the components first,
    # and then use the lines to update the components
    # and the connection scheme
    graphics = sheet.graphics

    lines    = graphics.select { |g| g.behaves_like?(Graffle::LineGraphic) }.compact
    comps    = graphics.select { |g| g.is_component? }.compact

    vars     = graphics.select { |g| g.is_variable?  }.compact
    notes    = graphics.select { |g| g.is_code_block? }.compact
    clouds   = graphics.select { |g| g.is_comment? }.compact

    # iterate through the variables
    vars.each do |g|
      v = Variable.new
      v.init_from_object(g)

      @variables[ v.get_id ] = v
      @connections[ v.get_id ] = []
    end

    # iterate throught the components
    comps.each do |g|
      c = Component.new
      
      # process inputs
      ins = lines.select {|l| l['Head']['ID'] == g['ID']}
      ins.sort! {|a,b| a.points[-1].x <=> b.points[-1].x}
      ins.map! { |l| @variables[ l['Tail']['ID'] ] }

      # process outputs
      outs = lines.select {|l| l['Tail']['ID'] == g['ID']}
      outs.sort! {|a,b| a.points[0].x <=> b.points[0].x}
      outs.map! { |l| @variables[ l['Head']['ID'] ] }    

      c.init_from_object( g, ins, outs)
      
      @connections[ c.get_id ] = []
      @components[  c.get_id ] = c
    end

    # parse the lines, in order to get the topological order working
    lines.each do |l|

      # this is a big source of problems...make the exception call a bit more informative
      # puts l
      head = l['Head']['ID']
      # puts head
      tail = l['Tail']['ID']
      # puts tail
      # raise "Line not fully connected" if ( head.empty? or tail.empty? )
 
      from_id = @components.select { |id,g| g.get_id == tail }
      from_id = from_id.flatten[0]
      if from_id == nil
        from_id = tail
      end
 
      to_id = @components.select { |id,g| g.get_id == head  }
      to_id = to_id.flatten[0]
      if to_id == nil
        to_id = head
      end


      if @connections[from_id] == nil
        @connections[from_id] = [to_id]
      else
        @connections[from_id].push(to_id)
      end

    end

    notes.each do |n|
      c = CodeBlock.new
      c.init_from_object( n )
      @code[ c.get_id ] = c
    end
    
    clouds.each do |cl|
      c = Comment.new
      c.init( cl )
      @comments[c.get_id] = c
    end

    #
    # self.init( comps, var_names, connect, vars, [], [], [], [])
  end

  def walk_through
    ordered = @connections.tsort.reverse
    
    compute = []
    init    = []
    initSrc = []
    output  = Hash.new

    ordered.each do |c|
      if @components[c]
        case @components[c].type
        when 'Source'
          initSrc.push('')
          initSrc.push("%% initialization of " + @components[c].get_name)
          initSrc.push( @components[c].get_initialization )
        when 'Normal', 'Virtual'
          init.push('')
          init.push("%% initialization of " + @components[c].get_name)
          init.push( @components[c].get_initialization )
        end
        compute.push( @components[c].get_compute )
        compute.push("\n")

      elsif @variables[c]
        compute.push( @variables[c].get_code )
      end
    end

    output['Compute'] = compute
    output['Init']    = init
    output['InitSrc'] = initSrc
    return output
  end

  def make_script

    program_parts = self.walk_through

    compute = program_parts['Compute']
    init    = program_parts['Init']
    initSrc = program_parts['InitSrc']

    # sort the components and variables
    ordered = @connections.tsort.reverse


    # Select the code blocks
    after    = @code.values.select { |b| b.name == "end" }.flatten[0]
    preamble = @code.values.select { |b| b.name == "init" }.flatten[0]

    # FIXME doesnt seem to work with the values
    sources  = @components.values.select { |c| c.get_type == 'Source'}
    # puts @components.values.map { |c| c.get_type + " " + c.get_name }

    program = []

    unless preamble.nil?
      program.push( "%% preamble")
      program.push( preamble.get_notes).flatten
    end

    unless init.nil? || init.empty?
      program.push("\r")
      program.concat(init)
      program.push("display('initialization finished')")
    end

    unless initSrc.nil? || initSrc.empty?
      program.push('')
      program.concat(initSrc)
      program.push("display('initialization of sources finished')")
    end

    program.push( '% the loop')
    program.push( 'tic') 
    program.push( "while " + sources.map { |s| s.get_name + "HasJuice(" + s.get_name + ")"  }.join( " & ") )
    program.concat( compute.compact.map { |s| "    " + s} )
    program.push( "end" + "\n\n" )
    program.push( 'toc')

    unless after.nil?
      program.push( after.get_notes ).flatten
    end

    return program
  end

  def make_virtual_component( component_name )

    program_parts = self.walk_through
    

    compute = program_parts['Compute']
    init    = program_parts['Init']

    # sort the components and variables
    ordered = @connections.tsort.reverse


    # variables
    program = []
    input_variables  = []
    output_variables = []
    variable_declarations = []
    outputs = []
    inputs  = []
    after   = []
    before  = []
    sources = []

    #detect the input variables
    input_variables = @variables.keys - @connections.values.flatten
    # sort them geometrically
    input_variables.sort! { |a,b| @variables[a].object.bounds.x <=> @variables[b].object.bounds.x}


    #detect the output variables
    output_variables = @variables.keys.select {|k| @connections[k].empty? }.flatten
    # sort them geometrically
    output_variables.sort! { |a,b| @variables[a].object.bounds.x <=> @variables[b].object.bounds.x }

    # leave those whose name is discard out
    output_variables.reject! {|v| @variables[v].get_name =~ /^\s*discard\s*$/ }

    # declare the variables local to the function
    variable_declarations = []
    vs = ( @variables.values - input_variables.map {|v|@variables[v]} ).uniq
    variable_declarations = vs.map { |v| v.get_name + " = [];"}


    # Select the code blocks
    after    = @code.values.select { |b| b.name == "end" }.flatten[0]
    preamble = @code.values.select { |b| b.name == "init" }.flatten[0]


    # Get the inputs to the initialization function...
    inputs   = @code.values.select { |b| b.name != "init" && b.name != "end"}
    # ... and sort them by height
    inputs.sort! { |a,b| a.object.bounds.y <=> b.object.bounds.y }
    # TODO use the default values
    # input_default = inputs.map { |i| i['Notes'].as_plain_text }


    # FIXME doesn't seem to work with the values
    sources  = @components.values.select { |c| c.get_type == 'Source'}

    begin
      program.push('function varargout = init' + component_name + '( '+  inputs.map { |i| i.name }.join(', ') + ' )' )
      program.push('% init' + component_name + ' function')
      @comments.each do |i,c|
        program.push('% ' + c.get_name)
      end 
    rescue
    end
    program.push('%')
    program.push('%   Date: ' + Date.today.to_s)
    program.push('%   Author: Miguel Vaz')
    program.push('%')

    unless preamble.nil? or preamble.empty?
      program.push( "%% preamble")
      program.push( preamble['Notes'].as_plain_text).flatten
    end

    unless init.nil? or init.empty?
      program.push('')
      program.concat(init)
    end

    unless initSrc.nil? || initSrc.empty?
      program.push('')
      program.concat(initSrc)
    end

    program.push('')
    program.push("varargout{1} = @%s;" % component_name)
    program.push("if exist('latency','var')")
    program.push("    varargout{2} = latency;")
    program.push("end")
    program.push('')
    program.push( '%% the function') 
    program.push( "function [" + output_variables.map{|s| @variables[s].get_name}.join( ", ") +"] = "+component_name+"( " + input_variables.map{|s| @variables[s].get_name}.join(", ") + " )" )
    program.concat( variable_declarations.map { |s| "    " + s} )
    program.concat( compute.map { |s| "    " + s} )
    program.push( "end" + "\n\n" )

    unless after.nil? || after.empty?
      program.push( after['Notes'].as_plain_text ).flatten
    end
    
    program.push('end')
    
    return program
  end

end
