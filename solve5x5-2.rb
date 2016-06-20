#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require './PixeLogic.rb'


if __FILE__ == $0
  logic = PixeLogic.new({ :width  => 5,
                          :height => 5,
                          :hint_h => [
                            [1,1],
                            [1],
                            [1,1],
                            [2,1],
                            [1,1]
                          ],
                          :hint_v => [
                            [1],
                            [2],
                            [2],
                            [2],
                            [1,2]
                          ]
                        })

  Signal.trap(:USR1) {
    logic.dump
   }

  def logic.loop_start
    dump
  end

  begin
    logic.solve
  rescue => e
    p e.message
    logic.dump
  end

  puts ""
  logic.dump
  puts ""
  logic.show("■", "　", "？")
end
