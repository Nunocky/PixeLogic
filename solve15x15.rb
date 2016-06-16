#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require './PixeLogic.rb'

# http://tonakai.aki.gs/picturelogic/play/index.php?PNum=1074

if __FILE__ == $0
  logic = PixeLogic.new({ :width  => 15,
                          :height => 15,
                          :hint_h => [
                            [7],
                            [9],
                            [9],
                            [5,5],
                            [4,4],

                            [4,1,1,4],
                            [3,3],
                            [2,3,3,2],
                            [1,2,2,1],
                            [1,1],

                            [1,2,2,1],
                            [1,2,2,1],
                            [2,3,2],
                            [3,3],
                            [9]
                          ],

                          :hint_v => [
                            [7],
                            [3,2],
                            [4,2,1],
                            [5,1,2,2],
                            [6,2,1],

                            [5,1,1],
                            [4,1,1,1,1],
                            [3,1,1],
                            [4,1,1,1,1],
                            [5,1,1],

                            [6,2,1],
                            [5,1,2,2],
                            [4,2,1],
                            [3,2],
                            [7]
                          ]
                        })

  Signal.trap(:USR1) {
    logic.dump
   }

  def logic.loop_end
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
