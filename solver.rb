#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require './PixeLogic.rb'

# TODO オプションを色々
#  * 途中経過を表示するか
#  * 時間を表示
#  * ループ間のウェイト時間設定


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

