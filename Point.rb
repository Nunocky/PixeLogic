#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'test/unit'
require 'pp'

class Point
  attr_accessor :x, :y

  def initialize(x=0, y=0)
    @x = x
    @y = y
  end

  def ==(v)
    return @x == v.x && @y == v.y
  end

  def eql?(other)
    @x == other.x && @y == other.y
  end

  def hash
    [@x, @y].hash
  end
end






if __FILE__ == $0
    class PointTest < Test::Unit::TestCase
    def testInit0
      p0 = Point.new
      assert_equal(p0.x, 0)
      assert_equal(p0.y, 0)
    end

    def testInit1
      p1 = Point.new(1, -2)
      assert_equal(p1.x,  1)
      assert_equal(p1.y, -2)
    end

    def testEqual
      p0 = Point.new
      p1 = Point.new(0,0)
      p2 = Point.new(1,2)
      assert_equal(p0, p1)
      assert_not_equal(p0, p2)
    end

#    def testHash
#      h = {}
#      a = Point.new(0,0)
#      b = Point.new(0,0)
#      c = Point.new(0,0)
#
#      h[a] = 0
#      h[b] = 0
#      assert_equal(true,  h[a] == h[b])
##      assert_not_equal(h[a], h[c])
#    end
end

end
