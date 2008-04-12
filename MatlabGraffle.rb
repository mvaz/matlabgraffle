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

    def is_function?
      return self.behaves_like?(Graffle::ShapedGraphic) && self['Shape'] == 'RoundRect'
    end

    def is_code_block?
      return self.behaves_like?(Graffle::ShapedGraphic) && self['Shape'] == 'Rectangle'
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

  def init_from_group( group )
    name = group.get_name
    initialization = group.get_notes

    # get inputs and outputs, which are represented by circles
    points = group.get_graphics_by_shape( 'Circle' )
    main   = group.get_graphics_by_shape('Rectangle').concat( group.get_graphics_by_shape('VerticalTriangle') )
    type   = main[0]['Shape'] == 'Rectangle' ? 'Normal' : 'Source'

    # detect the middle point of main component, important to
    # distinguish between an input and an output
    middle = main[0].bounds.y + ( main[0].bounds.height / 2)

    # identify the inputs and sort them
    inputs = points.select { |p| p.bounds.y < middle }
    inputs.sort! {|a,b| a.bounds.x <=> b.bounds.x}

    # identify the ouputs and sort them
    outputs = points.select { |p| p.bounds.y > middle }
    outputs.sort! {|a,b| a.bounds.x <=> b.bounds.x}

    init( name, inputs.map {|x| x['ID']}, 
                outputs.map {|x| x['ID']},
                initialization, group, type)
  end

  def to_s
    return ["name" => @name, "init" => @initialization, "inputs" => @inputs, "ouputs" => @outputs].to_s
  end


  def belongs?( id )
    return self.get_graphics.include?(id)
  end

  def get_graphics
    return @inputs.dup.concat(@outputs).push( @object['ID'])
  end
  
  def get_id; return @object['ID']; end
  def get_type; return @type; end
  def get_inputs; return @inputs; end
  def get_outputs; return @outputs; end
  def get_nme; return @name; end

  def get_initialization
    init = @initialization.gsub /%name%/, @name
    init = init.gsub /\\([\{\}])/, '\1'
    return init
  end
end

class VirtualComponent
  attr_reader :name, :inputs, :outputs, :initialization, :object
  def initialize(name, inputs = [], outputs = [], init = [], object = [] )
    @name = name
    @inputs = inputs
    @outputs = outputs
    @init = init
    @object = object
  end
  
  # def ini
end

class MatlabGraffle
  def init( comps, var_names, connect, vars, funcs, h, boxes, virtual=[])
    @components  = comps
    @variable_names = var_names
    @connections = connect
    @variables   = vars
    @functions   = funcs
    @ids         = h
    @boxes       = boxes
    @virtual     = virtual
  end
  
  def init_from_sheet( sheet )
    
    comps     = Hash.new
    h         = Hash.new
    var_names = Hash.new
    connect   = Hash.new
    vars      = Hash.new
    funcs     = Hash.new
    virtual   = Hash.new
    # build the components first, and then use the lines to update the components
    graphics = sheet.graphics
    
    groups = graphics.select { |g| g.behaves_like?(Graffle::Group) }.compact
    lines  = graphics.select { |g| g.behaves_like?(Graffle::LineGraphic) }.compact

    others = (graphics - groups) - lines

    boxes  = others.select { |g| g.is_code_block? }.compact
    circles= others.select { |g| g.is_variable? }.flatten.compact
    rrect  = others.select { |g| g.is_function? }.flatten.compact

    # make the components out of the groups
    groups.each do |g|
      c = Component.new
      c.init_from_group(g)
      comps[g['ID']] = c
      connect[g['ID']] = []
    end

    # make the virtual components
    rrect.each do |r|
      connect[r['ID']] = []
      funcs[r['ID']] = r

      # lines.each {|l| l['Head']['ID'] == r['ID']}
      ins = lines.select {|l| l['Head']['ID'] == r['ID']}.sort {|a,b| a.points[-1].x <=> b.points[-1].x}
      ins = ins.map { |l| l['Tail']['ID'] }
      
      outs = lines.select {|l| l['Tail']['ID'] == r['ID']}.sort {|a,b| a.points[0].x <=> b.points[0].x}
      outs = outs.map { |l| l['Head']['ID'] }
      
      init = r['Notes'] ? r.notes.as_plain_text : []
      name = r['Text'].as_lines[-1]
      
      virtual[r['ID']] = VirtualComponent.new(name, ins, outs, init, r )
      
    end

    # parse the variables, in order to get the names correctly
    # TODO the inputs and outputs must be in correct order
    circles.each do |o|
      var_names[o['ID']] = o.content.as_lines[-1]
      vars[o['ID']] = o
      connect[o['ID']] = []
    end

    # parse the lines, in order to get the topological order working
    lines.each do |l|

      head = l['Head']['ID']
      tail = l['Tail']['ID']

      if h[ tail ] 
        h[ tail ].push( head )
      else
        h[ tail ] = [ head ]
      end


      from_id = comps.select { |id,g| g.belongs?( tail ) }
      from_id = from_id.flatten[0]
      if from_id == nil
        from_id = tail
      end

      to_id = comps.select { |id,g| g.belongs?( head ) }
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

    #
    self.init( comps, var_names, connect, vars, funcs, h, boxes, virtual)
  end


  # TODO get a better name for zbr
  # TODO fix the way this functions sends its output back
  def zbr

    ordered = @connections.tsort.reverse
    compute = []
    init    = []
    initSrc = []
    output  = Hash.new
    
    ordered.each do |c|

      if @components[c] && @components[c].get_type != 'Source'
        # puts 'component'
        # build an array with the names of the inputs and the name of the component
        inp = [@components[c].get_nme]

        @components[c].get_inputs.each do |i|
          inp.push( @variable_names[ @ids.select{ |k,v| v.include?(i) }.flatten.first ] )
        end

        # build an array with the names of the outputs and the name of the component
        outp = [@components[c].get_nme]
        @components[c].get_outputs.each do |o|
          outp.push( @ids[o] ? @variable_names[ @ids[o].first] : 'discard' )
        end

        # add the compute
        compute.push('')
        compute.push("[ " + outp.join(" ") + "] = compute(" + inp.join(", ")+ ");")

        # add the initialization
        init.push('')
        init.push("%% initialization of " + @components[c].get_nme)
        init.push(@components[c].get_initialization)

      elsif @components[c]
        # puts 'source component'
        inp = [@components[c].get_nme]

        # build an array with the names of the outputs and the name of the component
        outp = [@components[c].get_nme]
        @components[c].get_outputs.each do |o|
          outp.push( @ids[o] ? @variable_names[ @ids[o].first] : 'discard' )
        end

        # add the compute
        compute.push('')
        compute.push("[ " + outp.join(" ") + "] = compute(" + inp.join(", ")+ ");")
        
        # add the initialization
        initSrc.push('')
        initSrc.push("%% initialization of " + @components[c].get_nme)
        initSrc.push(@components[c].get_initialization)

      elsif @variable_names[c]
        # puts 'variable'
        if @variables[c]['Notes']
          notes = @variables[c]['Notes'].as_plain_text.gsub /%name%/, @variable_names[c]
          compute.push(notes)
        end

      elsif @functions[c]
        # puts 'function'
        # outs = @connections[c]
        # ins  = @connections.keys.dup.select { |k| @connections[k].include?(c) }
        ins  = @virtual[c].inputs
        outs = @virtual[c].outputs
        # TODO order the inputs and outputs
        # how? good question...must be somehow based on the order of the points of the arrows
        ins  = (  ins.empty? ? [] : ins.map {|i| @variable_names[i] } )
        outs = ( outs.empty? ? '' : "[" + outs.map{|o|@variable_names[o]}.join(', ') + '] = ' )

        label = @functions[c]['Text'].as_lines[-1].gsub /\\([\{\}])/, '\1'

        compute.push('')
        compute.push(outs + 'feval( ' + ins.unshift(label).join(', ') + ');')
        
        # add the initialization
        init.push('')
        
        if @functions[c]['Notes']
          zbr = @functions[c]['Notes'].as_plain_text.gsub /%name%/, label
          zbr = zbr.gsub /\\([{}])/, '\1'
          
          init.push(zbr)
        end
      end

    end
    output['Compute'] = compute
    output['init']    = init
    output['initSrc'] = initSrc
    return output
  end



  def make_normal_flow( program_parts)
    
    compute = program_parts['Compute']
    init    = program_parts['init']
    initSrc = program_parts['initSrc']
    
    # Select the components that come before and after the part dependent on the components
    after    = @boxes.select { |b| b['Text'].as_lines[-1] == "end" }.flatten[0]
    preamble = @boxes.select { |b| b['Text'].as_lines[-1] == "init" }.flatten[0]
    
    # FIXME doesnt seem to work with the values
    sources  = @components.values.select { |c| c.get_type == 'Source'}

    program = []

    unless preamble.nil? or preamble.empty?
      program.push( "%% preamble")
      program.push( preamble['Notes'].as_plain_text).flatten
    end

    unless init.nil? or init.empty?
      program.push("\n")
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
    program.push( "while " + sources.map { |s| s.get_nme + "HasJuice(" + s.get_nme + ")"  }.join( " & ") )
    program.concat( compute.map { |s| "    " + s} )
    program.push( "end" + "\n\n" )
    program.push( 'toc') 

    unless after.nil? || after.empty?
      program.push( after['Notes'].as_plain_text ).flatten
    end

    return program
  end





  def make_virtual_component( component_name, program_parts)
    
    # TODO restrictions: 
    # every variable must be previously declared
    # whipe out every 'accumulate'
    # insert the coefficients into the GetCochlea
       # puts( 'what the fuck?')
      
    compute = program_parts['Compute']
    init    = program_parts['init']
    initSrc = program_parts['initSrc']

    # sort the components and variables
    ordered = @connections.tsort.reverse

    #detect the input variables
    input_variables = @variable_names.keys - @connections.values.flatten
    # sort them geometrically
    input_variables.sort! { |a,b| @variables[a].bounds.x <=> @variables[b].bounds.x}

    #detect the output variables
    output_variables = @variable_names.keys.select {|k| @connections[k].empty? }
    # sort them geometrically
    output_variables.sort! { |a,b| @variables[a].bounds.x <=> @variables[b].bounds.x }
    # leave those whose name is discard out
    output_variables.reject! {|v| @variable_names[v] =~ /^\s*discard\s*$/ }

    variable_declarations = []
    # puts input_variables.map {|v| @variable_names[v]}
    # puts  ( @variable_names.keys - input_variables )
    vs = ( @variable_names.values - input_variables.map {|v|@variable_names[v]} )
    vs = vs.uniq
    variable_declarations = vs.map { |v| v + " = [];"}
    # vs.each { |n| variable_declarations.push( n + " = [];" }
    # ( @variable_names.values - ( input_variables.map {|v| @variable_names[v]} )).each { |n| variable_declarations.push( n + " = [];"}
    # ( @variable_names.keys - input_variables ).each { |k| variable_declarations.push( @variable_names[k] + " = [];") }

    # Select the components that come before and after the part dependent on the components
    after    = @boxes.select { |b| b['Text'].as_lines[-1] == "end" }.flatten[0]
    preamble = @boxes.select { |b| b['Text'].as_lines[-1] == "init" }.flatten[0]

    # Get the variable which should serve as a input to the initialization function
    inputs   = (@boxes - (after.nil? ? [] : [after])) - (preamble.nil? ? []:[preamble])
    # Sort them by height
    inputs.sort! { |a,b| a.bounds.y <=> b.bounds.y }
    input_names = inputs.map { |i| i['Text'].as_lines[-1] }
    # TODO include this information (default values )
    # puts( 'what the fuck?')
    input_default = inputs.map { |i| i['Notes'].as_plain_text }



    # FIXME doesnt seem to work with the values
    sources  = @components.values.select { |c| c.get_type == 'Source'}

    program = []
    program.push('function varargout = init' + component_name + '( '+  input_names.join(', ') + ' )' )
    program.push('')

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
    program.push( "function [" + output_variables.map{|s| @variable_names[s]}.join( ", ") +"] = "+component_name+"( " + input_variables.map{|s| @variable_names[s]}.join(", ") + " )" )
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


# pi first.content.as_lines[1]
# puts first.graffle_id
# box = sorted[0]
# pi box.content.as_plain_text, "The box's content"
# pi box.note.as_plain_text, "The box's note"

# line = sorted[1]
# pi line.label.content.as_plain_text, "The line's label"
# pi line.note.as_plain_text,       "The line's note"
# pi line.label.note.as_lines, "The line's label's note as line array"
