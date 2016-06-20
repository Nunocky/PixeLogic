#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require './PixeLogic.rb'


if __FILE__ == $0

  # http://tonakai.aki.gs/picturelogic/play/index.php?PNum=1074
  logic = PixeLogic.load("ex15x15.rb")

  Signal.trap(:USR1) {
    logic.dump
   }

  def logic.loop_end
#    dump
  end

  begin
    logic.solve
  rescue => e
    p e.message
    logic.dump
  end

  puts ""
  logic.show("■", "　", "？")
end
