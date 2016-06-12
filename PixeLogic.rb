#!/Usr/bin/env ruby
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

class PixeLogic
  attr_reader   :width
  attr_reader   :height
  attr_accessor :field
  attr_reader   :candidates_v
  attr_reader   :candidates_h

  attr_reader   :loop_count

  def initialize(data)
    @width  = data[:width]
    @height = data[:height]
    @hint_h = data[:hint_h]
    @hint_v = data[:hint_v]

    @candidates_h = []
    @candidates_v = []

    @hint_total = 0
    @field_total = 0

    # フィールド情報
    @field = {}

    #  確定している空白
    if data[:blank]
      data[:blank].each do |pt|
        @field[pt] = 0
      end
    end

    #  確定しているドット
    if data[:dot]
      data[:dot].each do |pt|
        @field[pt] = 1
        @field_total += 1
      end
    end

    # ヒントから候補を作成
    if @hint_h

      @hint_h.each do |hint|
        @candidates_h << PixeLogic.getCandidates(@width, hint)
      end

      @hint_h.each do |hint|
        hint.each do |v|
          @hint_total += v
        end
      end
    end

    if @hint_v
      @hint_v.each do |hint|
        @candidates_v << PixeLogic.getCandidates(@height, hint)
      end
    end

    # 初期走査対象の初期化
    @scan_stack = []

    @width.times do |n|
      @scan_stack.push(["v", n])
    end

    @height.times do |n|
      @scan_stack.push(["h", n])
    end

  end

  #
  # @fieldの配列を得る
  # dir:: "v"または "h"
  # n:: 行、または列番号
  def getLine(dir, n)
    ary = []
    if dir == "v"
      x = n
      @height.times do |y|
        ary << @field[Point.new(x, y)]
      end
    else
      y = n
      @width.times do |x|
        ary << @field[Point.new(x, y)]
      end
    end
    return ary
  end

  #
  # 指定ラインの候補の配列を得る
  # dir:: "v"または "h"
  # n:: 行、または列番号
  def getCandidatesOfLine(dir, n)
    if dir == "v"
      return @candidates_v[n]
    else
      return @candidates_h[n]
    end
  end

  #
  # フィールドの1行、または1列のスキャン
  #
  def scan_line(dir, n)
    updated = false
    dir_next = (dir == "h")? "v" : "h"
    x, y = n, n

# puts "scan_line #{dir}, #{n}"

    line_old   = getLine(dir, n)
    line       = line_old.dup
    candidates = getCandidatesOfLine(dir, n)
# pp candidates

    if candidates.length == 1
      # puts "候補が一つしかない場合は探索の必要はない"
      line = candidates[0]

      # 新規に確定したピクセルに対してスキャンを登録する (ドット、空白ともに)
      line.each_with_index do |p, idx|
        next if line_old[idx] != nil

        @scan_stack.push([dir_next, idx])

        if dir == "v"
          y = idx
        else
          x = idx
        end

        @field[Point.new(x,y)] = p
        @field_total += p
      end

    else
      # puts "不要な候補を取り除く"
      new_candidates = PixeLogic.eliminateCandidates(line, candidates)

      if dir == "v"
        @candidates_v[n] = new_candidates
      else
        @candidates_h[n] = new_candidates
      end

      # 論理積を取って確定ドットの領域を得る
      line = PixeLogic.getLineProduct(new_candidates)

      # ドットが確定したところに再スキャン要求を出す
      line.each_with_index do |p, idx|
        next if line_old[idx] == 1

        if p == 1
          @scan_stack.push([dir_next, idx])

        if dir == "v"
          y = idx
        else
          x = idx
        end

          @field[Point.new(x,y)] = p
          @field_total += 1
        end
      end
    end

    updated
  end

  def scan_line_v(n)
    scan_line("v", n)
  end

  def scan_line_h(n)
    scan_line("h", n)
  end

  def show_step
  end

  def show
  end

  def solve_completed?
    return @hint_total == @field_total
  end

  def solve
    @loop_count = 0
    while 0 < @scan_stack.length
      ary = @scan_stack.pop
      break until ary
      dir = ary[0]
      n   = ary[1]
      updated = scan_line(dir, n)

      show_step
      @loop_count += 1

      break if solve_completed?
    end
  end

  #
  # 候補の算出
  #
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

  # getCandidatesの補助関数。再帰的に探索を行う
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

  #
  # 候補の論理積
  #
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

  #
  # 候補のふるい落とし
  # line::配列 (要素は nil, 0, 1のいずれか)
  # candidates::候補
  # 返り値::lineの条件にマッチする候補の配列
  def self.eliminateCandidates(line, candidates)
    ary_matched = []

    candidates.each do |candidate|

      matched = true
      length = line.length

      length.times do |n|
        next if (line[n] == nil) # 未確定の要素は比較対象外

        if candidate[n] != line[n]
          matched = false
        end

        break unless matched
      end

      ary_matched << candidate if matched
    end

    ary_matched
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

    def testHash
      h = {}
      a = Point.new(0,0)
      b = Point.new(0,0)
      c = Point.new(0,0)

      h[a] = 0
      h[b] = 0
      assert_equal(true,  h[a] == h[b])
#      assert_not_equal(h[a], h[c])
    end
end

  class PixeLogicTest < Test::Unit::TestCase
    def testInit0
      logic = PixeLogic.new({:width => 5,
                             :height => 10
                            })

      assert_equal(logic.width, 5)
      assert_equal(logic.height, 10)
    end

    def testGetCandidates
      # TODO 解の比較

      candidates = PixeLogic.getCandidates(5, [1,2])
      assert_equal(3, candidates.count)
      # [1,0,1,1,0]
      # [1,0,0,1,1]
      # [0,1,0,1,1]

      candidates = PixeLogic.getCandidates(5, [1])
      assert_equal(5, candidates.count)
      # [1,0,0,0,0]
      # [0,1,0,0,0]
      # [0,0,1,0,0]
      # [0,0,0,1,0]
      # [0,0,0,0,1]

      candidates = PixeLogic.getCandidates(5, [1,1])
      assert_equal(6, candidates.count)
      # [1,0,1,0,0]
      # [1,0,0,1,0]
      # [0,1,0,1,0]
      # [0,1,0,1,0]
      # [0,1,0,0,1]
      # [0,0,1,0,1]

      candidates = PixeLogic.getCandidates(5, [3])
      assert_equal(3, candidates.count)
      # [1,1,1,0,0]
      # [0,1,1,1,0]
      # [0,0,1,1,1]

      candidates = PixeLogic.getCandidates(5, [1,3])
      assert_equal(1, candidates.count)
      # [1,0,1,1,1]

      logic = PixeLogic.new({:width => 5,
                             :height => 5,
                             :hint_h => [[1], [1,1], [3],   [1,1,1], [5]],
                             :hint_v => [[2], [2,1], [1,3], [2,1],   [2]]
                            })

      assert_equal(logic.width, 5)
      assert_equal(logic.height, 5)
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

    def testEliminateCandidates
      candidates = [
        [1,0,1,1,0],
        [1,0,0,1,1],
        [0,1,0,1,1]]
      line = [1,nil,nil,nil,nil]
      new_candidates = PixeLogic.eliminateCandidates(line, candidates)
#pp new_candidates
      #  [1,0,1,1,0], [1,0,0,1,1]

      assert_equal(2, new_candidates.length)

      candidates = [
        [1,0,1,1,0],
        [1,0,0,1,1],
        [0,1,0,1,1]]
      line = [0,nil,nil,nil,nil]
      new_candidates = PixeLogic.eliminateCandidates(line, candidates)
#pp new_candidates
      assert_equal(1, new_candidates.length)
      # [0,1,0,1,1]
    end

    def testGetLine
      logic = PixeLogic.new({ :width  => 5,
                              :height => 5,
                              :hint_h => [[1], [1,1], [3],   [1,1,1], [5]],
                              :hint_v => [[2], [2,1], [1,3], [2,1],   [2]],
                              :blank  => [Point.new(4, 3)],
                              :dot    => [Point.new(3, 2)]
                            })

      line = logic.getLine("v", 4)
      assert_equal([nil,nil,nil,0,nil], line)

      line = logic.getLine("h", 3)
      assert_equal([nil,nil,nil,nil,0], line)

      line = logic.getLine("v", 3)
      assert_equal([nil,nil,1,nil,nil], line)

      line = logic.getLine("h", 2)
      assert_equal([nil,nil,nil,1,nil], line)
    end

    def testSolve5x5
      logic = PixeLogic.new({ :width  => 5,
                              :height => 5,
                              :hint_h => [[1], [1,1], [3],   [1,1,1], [5]],
                              :hint_v => [[2], [2,1], [1,3], [2,1],   [2]]
                            })

      logic.solve
      puts logic.loop_count
      # TODO 解の比較
    end

    def testSolve10x10
      # http://www.minicgi.net/logic/logic.html?num=30313 「がんばれ熊本」
      logic = PixeLogic.new({ :width  => 10,
                              :height => 10,
                              :hint_h => [
                                [4],
                                [1,1],
                                [6,1],
                                [9],
                                [4,3],
                                [4,1,3],
                                [4,3],
                                [10],
                                [6],
                                [1,2,1]
                              ],
                              :hint_v => [
                                [6,1],
                                [6],
                                [6],
                                [6],
                                [2,2],
                                [4,1,3],
                                [1,1,3],
                                [1,6],
                                [9],
                                [6]
                              ]
                            })
      logic.solve
      puts logic.loop_count
      # TODO 解の比較
    end

    def testSolve15x15
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

      logic.solve
      puts logic.loop_count
      # TODO 解の比較
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
