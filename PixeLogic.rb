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

end

class PixeLogic
  attr_reader :w, :h
  attr_accessor :field

  PIX_SPC = 0
  PIX_DOT = 1

  def initialize(data)
    @w = data[:w]
    @h = data[:h]
    @field = Array.new(@w * @h, nil)
  end


  def solve

  end

  def show

  end

  def self.getCandidates(width, pix)
    candidates = []

    return [] if width == 0 || pix == nil || pix.length == 0

    # width = 5, ary = [1]に対して、以下の配列を返す
    # [[1,0,0,0,0],
    #  [0,1,0,0,0],
    #  [0,0,1,0,0],
    #  [0,0,0,1,0],
    #  [0,0,0,0,1]]

    # spcsの条件
    # * 要素の数は aryの個数と同じ
    # * 書く要素は整数。最初の要素は 0以上、それ以外は1以上
    # * 要素の合計は (width - ary.length)以下
    spcs = Array.new(pix.length, 1)
    spcs[0] = 0
    def spcs.sum
      total = 0
      self.each do |v|
        total += v
      end
      total
    end

    ary = []
    self.gc_f0(ary, width, 0, spcs, pix)

    ary.each do |spc|
      line = Array.new(width, 0)
      idx = 0

      (spc.length).times do |n|

        spc[n].times do
          line[idx] = 0
          idx += 1
        end

        pix[n].times do
          line[idx] = 1
          idx += 1
        end

      end

      candidates << line
    end

    candidates
  end

  def self.gc_f0(result, width, n, spcs, pix)
    return if spcs.length-1 < n

    # 空白の数上限
    total = width
    pix.each do |v|
      total -= v
    end

    spcs.each_with_index do |v, x|
      next if x==n
      total -= v
    end

    (spcs[n]..total).each do |v|
      v_old = spcs[n]
      spcs[n] = v
      temp = spcs.dup
      result << temp unless result.include? temp
      if 0 < total
        self.gc_f0(result, width, n+1, spcs, pix)
      end
      spcs[n] = v_old
    end
  end


  def self.getLineProduct(lines)
    length = lines[0].length

    result = Array.new(length, 1)

    length.times do |n|
      lines.each do |line|
        result[n] &= line[n]
      end
    end

    return result
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
  end


  class PixeLogicTest < Test::Unit::TestCase
    # TODO DSLで確定したドット情報も渡せるようにする

    def testInit0
      logic = PixeLogic.new({:w => 5,
                             :h => 10
                            })

      assert_equal(logic.w, 5)
      assert_equal(logic.h, 10)
    end

    def testGetCandidates

pp "getCandidates(5, [1,2]"
      candidates = PixeLogic.getCandidates(5, [1,2])
pp candidates
      assert_equal(3, candidates.count)
      # [1,0,1,1,0]
      # [1,0,0,1,1]
      # [0,1,0,1,1]

pp "getCandidates(5, [1])"
      candidates = PixeLogic.getCandidates(5, [1])
pp candidates
      assert_equal(5, candidates.count)
      # [1,0,0,0,0]
      # [0,1,0,0,0]
      # [0,0,1,0,0]
      # [0,0,0,1,0]
      # [0,0,0,0,1]

pp "getCandidates(5, [1,1])"
      candidates = PixeLogic.getCandidates(5, [1,1])
pp candidates
      assert_equal(6, candidates.count)
      # [1,0,1,0,0]
      # [1,0,0,1,0]
      # [0,1,0,1,0]
      # [0,1,0,1,0]
      # [0,1,0,0,1]
      # [0,0,1,0,1]

pp "getCandidates(5, [3])"
      candidates = PixeLogic.getCandidates(5, [3])
pp candidates
      assert_equal(3, candidates.count)
      # [1,1,1,0,0]
      # [0,1,1,1,0]
      # [0,0,1,1,1]

pp "getCandidates(5, [1,3])"
      candidates = PixeLogic.getCandidates(5, [1,3])
pp candidates
      assert_equal(1, candidates.count)
      # [1,0,1,1,1]

      logic = PixeLogic.new({:w => 5,
                             :h => 5,
                             :hint_h => [[1], [1,1], [3],   [1,1,1], [5]],
                             :hint_v => [[2], [2,1], [1,3], [2,1],   [2]]
                            })

      assert_equal(logic.w, 5)
      assert_equal(logic.h, 5)
    end

    def testGetProduct
      ###
      line = PixeLogic.getLineProduct([ [1,0,1,1,0],
                                        [1,0,0,1,1],
                                        [0,1,0,1,1]])
      assert_equal([0,0,0,1,0], line)

      ###
      line = PixeLogic.getLineProduct([ [1,0,0,0,0],
                                        [0,1,0,0,0],
                                        [0,0,1,0,0],
                                        [0,0,0,1,0],
                                        [0,0,0,0,1]])
      assert_equal([0,0,0,0,0], line)


      ###
      line = PixeLogic.getLineProduct([ [1,0,1,0,0],
                                        [1,0,0,1,0],
                                        [0,1,0,1,0],
                                        [0,1,0,1,0],
                                        [0,1,0,0,1],
                                        [0,0,1,0,1]])
      assert_equal([0,0,0,0,0], line)

      ###
      line = PixeLogic.getLineProduct([ [1,1,1,0,0],
                                        [0,1,1,1,0],
                                        [0,0,1,1,1]])
      assert_equal([0,0,1,0,0], line)

      ###
      line = PixeLogic.getLineProduct([[1,0,1,1,1]])
      assert_equal([1,0,1,1,1], line)



    end


  end



end

=begin

5x5のサンプル

      2 2 1 2 2
        1 3 1
1     □□■□□
1,1   □■□■□
3     □■■■□
1,1,1 ■□■□■
5     ■■■■■

=end


