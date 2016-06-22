#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require './PixeLogic.rb'

if ARGV.length == 0
  puts "usage: ./solver.rb <filename>"
  exit
end

filename = ARGV[0]

logic = PixeLogic.load(filename)

def logic.loop_start
  puts "\e[H\e[2J"
  puts "# #{@loop_count}:"
  show("　", "■", "？")
#  sleep 0.1
end

begin
  logic.solve

  puts "\e[H\e[2J"
  puts "done."
  logic.show("　", "■", "？")

rescue => e
  p e.message
  logic.dump
end

