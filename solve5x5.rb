#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require './PixeLogic.rb'


if __FILE__ == $0
  logic = PixeLogic.new({ :width  => 5,
                          :height => 5,
                          :hint_h => [[1], [1,1], [3],   [1,1,1], [5]],
                          :hint_v => [[2], [2,1], [1,3], [2,1],   [2]]
                        })

  def logic.show_step
    puts @loop_count
    show
  end

  def logic.show
    @height.times do |y|
      @width.times do |x|
        if @field[Point.new(x,y)] == 0
          print "✕"
        elsif @field[Point.new(x,y)] == 1
          print "■"
        else
          print "  "
        end
      end
      print "\n"
    end
  end

  logic.solve
  puts ""
  logic.show
end
