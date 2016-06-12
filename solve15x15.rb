#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require './PixeLogic.rb'


if __FILE__ == $0
  logic = PixeLogic.new({ :width  => 15,
                          :height => 15,
                          :hint_h => [
                            [7],
                            [9],
                            [2,3,2],
                            [1,4,4,1],
                            [1,9,2],
                            [1,7,1],
                            [3,5,3],
                            [4,3,2],
                            [3,2,1,1],
                            [1,1,1,1,2],
                            [1,1,1,1],
                            [2,1,1,2],
                            [2,2,1,2],
                            [2,2,1,2],
                            [2,3]],
                          :hint_v => [
                            [4,2,1],
                            [1,1,2],
                            [1,1,2,1],
                            [4,1,2,1],
                            [6,1,1,1],
                            [2,6,2],
                            [13],
                            [3,3],
                            [15],
                            [2,5,1],
                            [6,3,1],
                            [4,1,3],
                            [2,2],
                            [1,2,2],
                            [2,1,1]]
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
