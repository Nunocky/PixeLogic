#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'pp'
require './Point.rb'

class PixeLogic
  attr_reader   :width, :height
  attr_accessor :field
  attr_reader   :hint_v ,:hint_h
  attr_reader   :candidates_v, :candidates_h
  attr_reader    :scan_priority
  attr_reader   :loop_count

  def initialize(data)
    @width  = data[:width]
    @height = data[:height]
    @hint_h = data[:hint_h]
    @hint_v = data[:hint_v]

    # フィールド情報
    @field = {}
    @field_total = 0

    @candidates_v = Array.new(@width)
    @candidates_h = Array.new(@height)

    #  確定している空白
    if data[:blank]
      data[:blank].each do |pt|
        setPixel(pt, 0)
      end
    end

    #  確定しているドット
    if data[:dot]
      data[:dot].each do |pt|
        setPixel(pt, 1)
      end
    end

    @field_bak = @field.dup
    @field_total_bak = @field_total
  end

  def setPixel(pt, v)
    f_old = @field[pt]
    @field[pt] = v

    throw "override" if f_old != nil

    if    v == 1 && f_old != 1
      @field_total += 1
    elsif v == 0 && f_old == 1
      @field_total -= 1
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
    ary = nil

    if dir == "v"
      ary = @candidates_v[n]
      if ary == nil
        ary = @candidates_v[n] = PixeLogic.getCandidates(@height, @hint_v[n])
      end
    else
      ary = @candidates_h[n]
      if ary == nil
        ary = @candidates_h[n] = PixeLogic.getCandidates(@width, @hint_h[n])
      end
    end

    return ary
  end

  #
  # フィールドの1行、または1列のスキャン
  #
  def scan_line(dir, n)

puts "scan_line(#{dir},#{n})"

    updated = false
    dir_next = (dir == "h")? "v" : "h"
    x, y = n, n

    line_old   = getLine(dir, n)
    line       = line_old.dup
    candidates = getCandidatesOfLine(dir, n)

    if candidates.length == 1

puts "候補が一つだけ"
      line = candidates[0]

      # 新規に確定したピクセルに対してスキャンを登録する (ドット、空白ともに)
      line.each_with_index do |p, idx|
        next if line_old[idx] != nil

        puts "新しい探索対象 #{dir_next},#{idx}"
        @scan_stack.unshift([dir_next, idx]) # unless @scan_stack.include?([dir_next, idx])

        if dir == "v"
          y = idx
        else
          x = idx
        end

        setPixel(Point.new(x,y), p)
      end

    else

      puts "不要な候補を取り除く"
      new_candidates = PixeLogic.eliminateCandidates(line, candidates)

      puts "OLD #{candidates.to_s}"
      puts "NEW #{new_candidates.to_s}"
      puts "#{candidates.length} -> #{new_candidates.length}"
      if dir == "v"
        @candidates_v[n] = new_candidates
      else
        @candidates_h[n] = new_candidates
      end

      if new_candidates.length == 1
        # 確定
        # @fileldの該当する位置が nullなら、その位置を確定して新規スキャン対象を追加する

        line.each_with_index do |p, idx|
          next if p != nil

          if dir == "v"
            y = idx
          else
            x = idx
          end

          setPixel(Point.new(x, y), p)

          puts "新しい探索対象 #{dir_next},#{idx}"
          @scan_stack.unshift([dir_next, idx]) # unless @scan_stack.include?([dir_next, idx])
        end

      else
        # 候補が複数残っている
        #   → 論理積を取って確定ドットの領域を得る
        #   → 1のところは確定。新規スキャン対象を追加
        line = PixeLogic.getLineProduct(new_candidates)
        line.each_with_index do |p, idx|
          # ドットが確定したところに再スキャン要求を出す
          next if line_old[idx] == 1
          next if p != 1
          if dir == "v"
            y = idx
          else
            x = idx
          end

          setPixel(Point.new(x,y), 1)

          puts "新しい探索対象 #{dir_next},#{idx}"
          @scan_stack.unshift([dir_next, idx]) # unless @scan_stack.include?([dir_next, idx])
        end

        # TODO 論理和をとり、 0のところは空白で確定する
        line = PixeLogic.getLineSum(new_candidates)
        line.each_with_index do |p, idx|
          next if line_old[idx] == 0
          next if p != 0

          if dir == "v"
            y = idx
          else
            x = idx
          end

          setPixel(Point.new(x,y), 0)
          puts "新しい探索対象 #{dir_next},#{idx}"
          @scan_stack.unshift([dir_next, idx]) # unless @scan_stack.include?([dir_next, idx])
        end
      end

    end

    updated
  end

  def solve_completed?
    # 条件1 : 全部の候補が1だった
    matched = true
    @width.times do |n|
      v = @candidates_v[n]
      if v == nil || v.count != 1
        matched = false
        break
      end
    end

    @height.times do |n|
      v = @candidates_h[n]
      if v == nil || v.count != 1
        matched = false
        break
      end
    end
    return true if matched

    false
  end

  def setup
    @candidates_h = []
    @candidates_v = []

    @field       = @field_bak.dup
    @field_total = @field_total_bak

    # ヒントから候補を作成
    if @hint_h
      @hint_h.each do |hint|
        @candidates_h << PixeLogic.getCandidates(@width, hint)
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

  def setup2
    # 占有率の最も高いところを見つけて配列にする
    # -> 計算して配列 @scan_priorityへ
    # @scan_priority[0] = ["v", 3] とか

    h = {}

    @hint_h.each_with_index do |hint, n|
      r = PixeLogic.calcOccupancy(hint, @width)
      h[["h",n]] = r
    end

    @hint_v.each_with_index do |hint, n|
      r = PixeLogic.calcOccupancy(hint, @height)
      h[["v",n]] = r
    end

    # sort
    @scan_priority = h.sort  {|(k1, v1), (k2, v2)| v2 <=> v1 }

  end

  def solve2

    setup2

    puts "scan_priority"
    @scan_priority.each do |v|
      puts v.to_s
    end

    @scan_stack = [] unless @scan_stack
    @loop_count = 0

    # TODO 有力そうな候補を先に登録
    @scan_priority.each do |ary|
        @scan_stack.push ary[0] if ary[0]
    end

    public_send_if_defined(:solve_start)

    while 0 < @scan_stack.length
      public_send_if_defined(:loop_start)

      @current_dir, @current_n = @scan_stack.shift

      break if @current_dir == nil

      scan_line(@current_dir, @current_n)

      public_send_if_defined(:loop_end)
      break if solve_completed?
      @loop_count += 1
    end

    public_send_if_defined(:solve_end)
  end

  def solve0
    setup

    @loop_count = 0

    public_send_if_defined(:solve_start)
    while 0 < @scan_stack.length

      public_send_if_defined(:loop_start)
      ary = @scan_stack.pop
      break until ary

      @current_dir, @current_n = ary

      updated = scan_line(@current_dir, @current_n)

      public_send_if_defined(:loop_end)

      @loop_count += 1
      break if solve_completed?
    end

    public_send_if_defined(:solve_end)
  end

  alias_method :solve, :solve2

  def public_send_if_defined(sym)
    public_send(sym) if respond_to?(sym)
  end

  def show(d="O", s=" ", u=".")
    @height.times do |y|
      @width.times do |x|
        v = @field[Point.new(x,y)]
        print u if v == nil
        print s if v == 0
        print d if v == 1
      end
      print "\n"
    end
  end


  def dump(p="O", s=" ", u=".")

    # 内部状態を出力する
    puts "--------------------------------------------------------------------------------"
    puts "loop_count=#{@loop_count}"
    puts "width=#{@width}"
    puts "height=#{@height}"

    if @candidates_h
      puts "candidates_h"
      @candidates_h.each_with_index do |c, n|
        puts "h#{n}  #{c.to_s}"
      end
    end

    if @candidates_v
      puts "candidates_v"
      @candidates_v.each_with_index do |c,n|
        puts "v#{n}  #{c.to_s}"
      end
    end

    show(p,s,u)

#    puts "scan = #{@current_dir},#{@current_n}"
  end

  #
  # 候補の算出
  #
  def self.getCandidates(width, pix)
    candidates = []

    return [] if width == 0 || pix == nil

    if pix.length == 0 || (pix.length==1 && pix[0] == 0)
      return [ Array.new(width, 0) ]
    end

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
    count = length

    length.times do |n|
      lines.each do |line|
        count -= 1 if result[n] ==1 && line[n] == 0
        result[n] &= line[n]

        # 全部0になったらループ中断
        return result if count == 0

      end
    end

    return result
  end

  #
  # 候補の論理和
  #
  def self.getLineSum(lines)
    length = lines[0].length

    result = Array.new(length, 0)

    length.times do |n|
      lines.each do |line|
        result[n] |= line[n]
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

#puts "eliminateCandidates"
#puts "#{line.to_s}"
    candidates.each do |candidate|
#puts "#{candidate.to_s}"

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

  #
  # ライン上におけるドットの占有率
  # 占有率=1ならばそのラインで取りうる配置は確定している
  # TODO 占有率の高いラインを優先的にスキャンするように改善する
  def self.calcOccupancy(hint, width)
    sum = 0.0
    hint.each do |v|
      sum += v
    end
    sum += hint.length - 1

    return sum/width
  end

end


if __FILE__ == $0
  class PixeLogicTest < Test::Unit::TestCase
    def testInit0
      logic = PixeLogic.new({:width => 5,
                             :height => 10
                            })

      assert_equal(logic.width, 5)
      assert_equal(logic.height, 10)
    end

    def testGetCandidates
      candidates = PixeLogic.getCandidates(5, [1,2])
      assert_equal([ [1,0,1,1,0],
                     [1,0,0,1,1],
                     [0,1,0,1,1] ], candidates)

      candidates = PixeLogic.getCandidates(5, [1])
      assert_equal([ [1,0,0,0,0],
                     [0,1,0,0,0],
                     [0,0,1,0,0],
                     [0,0,0,1,0],
                     [0,0,0,0,1]], candidates)

      candidates = PixeLogic.getCandidates(5, [1,1])
      assert_equal([ [1,0,1,0,0],
                     [1,0,0,1,0],
                     [1,0,0,0,1],
                     [0,1,0,1,0],
                     [0,1,0,0,1],
                     [0,0,1,0,1]], candidates)

      candidates = PixeLogic.getCandidates(5, [3])
      assert_equal([ [1,1,1,0,0],
                     [0,1,1,1,0],
                     [0,0,1,1,1] ], candidates)

      candidates = PixeLogic.getCandidates(5, [1,3])
      assert_equal([[1,0,1,1,1]], candidates)

      candidates = PixeLogic.getCandidates(5, [])
      assert_equal([[0,0,0,0,0]], candidates)

      candidates = PixeLogic.getCandidates(5, [0])
      assert_equal([[0,0,0,0,0]], candidates)
    end

    def testGetProduct
      line = PixeLogic.getLineProduct([ [0,0,1,1],
                                        [0,1,0,1]])
      assert_equal([0,0,0,1], line)

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


    def testGetSum
      line = PixeLogic.getLineSum([ [0,0,1,1],
                                    [0,1,0,1]])
      assert_equal([0,1,1,1], line)
    end

    def testEliminateCandidates
      candidates = [
        [1,0,1,1,0],
        [1,0,0,1,1],
        [0,1,0,1,1]]
      line = [1,nil,nil,nil,nil]
      new_candidates = PixeLogic.eliminateCandidates(line, candidates)
      assert_equal(2, new_candidates.length)
      assert_equal([[1,0,1,1,0], [1,0,0,1,1]], new_candidates)

      candidates = [
        [1,0,1,1,0],
        [1,0,0,1,1],
        [0,1,0,1,1]]
      line = [0,nil,nil,nil,nil]
      new_candidates = PixeLogic.eliminateCandidates(line, candidates)
      assert_equal(1, new_candidates.length)
      assert_equal([[0,1,0,1,1]], new_candidates)
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

    def testOccupancy
      r = PixeLogic.calcOccupancy([1,1,1], 5)
      assert_equal(1.0, r)

      r = PixeLogic.calcOccupancy([3,1], 5)
      assert_equal(1.0, r)

      r = PixeLogic.calcOccupancy([1, 3], 5)
      assert_equal(1.0, r)

      r = PixeLogic.calcOccupancy([0], 5)
      assert_equal(0, r)

      r = PixeLogic.calcOccupancy([3], 5)
      assert_equal(3/5.0, r)
    end

    def testOccupancy2
      logic = PixeLogic.new({ :width  => 5,
                              :height => 5,
                              :hint_h => [[1], [1,1], [3],   [1,1,1], [5]],
                              :hint_v => [[2], [2,1], [1,3], [2,1],   [2]],
                              :blank  => [Point.new(4, 3)],
                              :dot    => [Point.new(3, 2)]
                            })

      logic.hint_h.each_with_index do |hint, n|
        r = PixeLogic.calcOccupancy(hint, logic.width)
        puts "H#{n} : #{r}"
      end

      puts ""

      logic.hint_v.each_with_index do |hint, n|
        r = PixeLogic.calcOccupancy(hint, logic.height)
        puts "V#{n} : #{r}"
      end

    end


    def testSolve5x5
      logic = PixeLogic.new({ :width  => 5,
                              :height => 5,
                              :hint_h => [[1], [1,1], [3],   [1,1,1], [5]],
                              :hint_v => [[2], [2,1], [1,3], [2,1],   [2]]
                            })

      logic.solve
      # TODO 解の比較
    end

    def testSetup2
      logic = PixeLogic.new({ :width  => 5,
                              :height => 5,
                              :hint_h => [[1], [1,1], [3],   [1,1,1], [5]],
                              :hint_v => [[2], [2,1], [1,3], [2,1],   [2]]
                            })

      logic.setup2
      ary = logic.scan_priority
      assert_equal(logic.width + logic.height, ary.length)
      puts ""
      ary.each do |el|
        k, v = el
        puts "#{k.to_s} : #{v}"
      end
    end


  end



end

=begin

5x5のサンプル

      2 2 1 2 2
        1 3 1
1     □□■□□
1 1   □■□■□
3     □■■■□
1 1 1 ■□■□■
5     ■■■■■


## TODO 

 * 枝切。 必要のなくなった探索を行わない
  * ピクセルの論理積。すべて0になった時点で終了していい
  * 探索ラインをスタックに積む際、重複したものを除く
 * 論理的に置けない場所に xを付ける





=end
