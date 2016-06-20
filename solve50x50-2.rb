#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require './PixeLogic.rb'

if __FILE__ == $0
  logic = PixeLogic.load("ex50x50.rb")

  Signal.trap(:USR1) {
    logic.dump
   }

  def logic.loop_start
#    puts "----"
#    puts "# #{@loop_count}:"
#    show
  end

#  def logic.loop_end
#    dump
#  end

  begin
    logic.solve
  rescue => e
    p e.message
    logic.dump
  end

  puts ""
  logic.dump
  puts ""
  logic.show("■", "　")
end
