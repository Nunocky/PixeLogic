#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

#TODO 時間を測る
#
require 'pp'
require './Point.rb'

class PixeLogic
  attr_reader   :width, :height
  attr_reader   :hint_v, :hint_h
  attr_accessor :field
  attr_reader   :candidates_v, :candidates_h
  attr_reader   :loop_count
  attr_reader   :scan_priority

  def self.load(filename)
    @field = {}
    @dot_count = 0

    config = File.read(filename)

    logic = PixeLogic.new
    logic.instance_eval(config)
    logic.instance_eval {

      unless @width != nil && @height != nil && @hint_v != nil && hint_h != nil
        STDERR.puts "you must set @width, @height, @hint_v, and @hint_h"
        exit
      end

      @candidates_v = Array.new(@width)
      @candidates_h = Array.new(@height)

#      #  確定している空白
#      if blank != nil
#        blank.each do |pt|
#          setPixel(pt, 0)
#        end
#      end
#
#      #  確定しているドット
#      if dot
#        dot.each do |pt|
#          setPixel(pt, 1)
#        end
#      end
      
      check_hints
    }

    return logic
  end

  #
  #
  #
  def initialize(info = nil)
    @field = {}
    @dot_count = 0

    return unless info != nil

    @width  = info[:width]
    @height = info[:height]
    @hint_h = info[:hint_h]
    @hint_v = info[:hint_v]

    @candidates_v = Array.new(@width)
    @candidates_h = Array.new(@height)

    #  確定している空白
    if info[:blank]
      info[:blank].each do |pt|
        setPixel(pt, 0)
      end
    end

    #  確定しているドット
    if info[:dot]
      info[:dot].each do |pt|
        setPixel(pt, 1)
      end
    end

    check_hints
  end

  #
  # v,h方向のヒントの総和を比較、不一致なら問題設定に間違いがあると判断
  #
  def check_hints
    return if hint_h == nil || hint_v == nil

    sum_v = 0
    sum_h = 0

    @hint_h.each do |h|
      next if h == nil
      h.each do |v|
        sum_h += v
      end
    end

    @hint_v.each do |h|
      next if h == nil
      h.each do |v|
        sum_v += v
      end
    end
    
    raise ArgumentError, "sum_v and sum_h not match" if sum_v != sum_h
  end

  #
  #
  #
  def setPixel(pt, v)
    f_old = @field[pt]
    @field[pt] = v

    STDERR.puts "WARNING : field value overriden" if f_old != nil

    if    v == 1 && f_old != 1
      @dot_count += 1
    elsif v == 0 && f_old == 1
      @dot_count -= 1
    end
  end

  # fieldの配列を得る
  # @param [String] dir "v" または "h"
  # @param [Integer] n 行、または列の番号
  # @return [Array] 対応する行、または列の field情報(nil, 0, 1の配列)
  # @todo エラーチェック
  # @todo Pointの生成コストを減らす
  def getFieldLine(dir, n)
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

  # 指定ラインの候補の配列を得る
  # @param [String] dir "v" または "h"
  # @param [Integer] n 行、または列の番号
  # @return [Array] 対応する行または列に対する解候補の配列
  # @todo エラーチェック
  def getCandidatesOfLine(dir, n)

    ary = nil
    base = getFieldLine(dir,n)

    if dir == "v"
      ary = @candidates_v[n]
      if ary == nil
        ary = @candidates_v[n] = PixeLogic.getCandidates(@height, @hint_v[n], base)
      end
    else
      ary = @candidates_h[n]
      if ary == nil
        ary = @candidates_h[n] = PixeLogic.getCandidates(@width, @hint_h[n], base)
      end
    end

    ary
  end

  # フィールドの1行、または1列のスキャン
  # @param [String] dir "v" または "h"
  # @param [Integer] n 行、または列の番号
  # @todo エラーチェック
  
  def scan_line(dir, n)

    puts "scan_line(#{dir},#{n})"

    dir_next = (dir == "h")? "v" : "h"
    x, y = n, n

    line_old   = getFieldLine(dir, n)
    line       = line_old.dup
    candidates = getCandidatesOfLine(dir, n)

    #puts "#{candidates.to_s}"

    if 1 < candidates.length
      puts "複数の配置候補"
      new_candidates = PixeLogic.eliminateCandidates(line, candidates)

      #      puts "OLD #{candidates.to_s}"
      #      puts "NEW #{new_candidates.to_s}"
      puts "candidates eliminated : #{candidates.length} -> #{new_candidates.length}"
      if dir == "v"
        @candidates_v[n] = new_candidates
      else
        @candidates_h[n] = new_candidates
      end

      candidates = new_candidates
    end

    if candidates.length == 1
      puts "配置候補が一つだけ → 確定"
      line = candidates[0]

      # 新規に確定したピクセルに対してスキャンを登録する (ドット、空白ともに)
      line.each_with_index do |p, idx|
        next if line_old[idx] != nil

        unless @scan_stack.include?([dir_next, idx])
          puts "新しい探索対象 #{dir_next},#{idx}"
          @scan_stack.push([dir_next, idx])
        end
        if dir == "v"
          y = idx
        else
          x = idx
        end

        setPixel(Point.new(x,y), p)
      end
    else
      # 候補が複数残っている
      #   → 論理積を取って確定ドットの領域を得る
      #   → 1のところは確定。新規スキャン対象を追加
      line = PixeLogic.getProductOfLine(new_candidates)
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

        unless @scan_stack.include?([dir_next, idx])
          puts "新しい探索対象 #{dir_next},#{idx}"
          @scan_stack.push([dir_next, idx])
        end
      end

      # 論理和をとり、 0のところは空白で確定する
      line = PixeLogic.getSumOfLine(new_candidates)
      line.each_with_index do |p, idx|
        next if line_old[idx] == 0
        next if p != 0

        if dir == "v"
          y = idx
        else
          x = idx
        end

        setPixel(Point.new(x,y), 0)
        unless @scan_stack.include?([dir_next, idx])
          puts "新しい探索対象 #{dir_next},#{idx}"
          @scan_stack.push([dir_next, idx])
        end
      end
    end
  end

  #
  # 条件1 : 全部の候補が1だった
  #
  def all_line_one_candidate?
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

  #
  #
  #
  def solve_completed?
    return all_line_one_candidate?
  end

  #
  #
  #
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

    # 占有率の大きなものを前に
    @scan_priority = h.sort  {|(k1, v1), (k2, v2)| v2 <=> v1 }

    # TODO 0.5以下は確定するピクセルが無いので登録しても意味が無い
  end

  #
  #
  #
  def solve2
    setup2

puts "scan_priority"
    @scan_priority.each do |v|
      puts v.to_s 
    end

    @scan_stack = [] unless @scan_stack
    @loop_count = 0

    # 有力そうな候補(占有率の高い列)を先に登録
    @scan_priority.each do |ary|
      val = ary[0]
     @scan_stack.push val if val[1] > 0.5
#      @scan_stack.push ary[0] if ary[0]
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

  #  def setup
  #    @candidates_h = []
  #    @candidates_v = []
  #
  #    # ヒントから候補を作成
  #    if @hint_h
  #      @hint_h.each do |hint|
  #        @candidates_h << PixeLogic.getCandidates(@width, hint)
  #      end
  #    end
  #
  #    if @hint_v
  #      @hint_v.each do |hint|
  #        @candidates_v << PixeLogic.getCandidates(@height, hint)
  #      end
  #    end
  #
  #    # 初期走査対象の初期化
  #    @scan_stack = []
  #
  #    @width.times do |n|
  #      @scan_stack.push(["v", n])
  #    end
  #
  #    @height.times do |n|
  #      @scan_stack.push(["h", n])
  #    end
  #  end

  #  def solve0
  #    setup
  #
  #    @loop_count = 0
  #
  #    public_send_if_defined(:solve_start)
  #    while 0 < @scan_stack.length
  #
  #      public_send_if_defined(:loop_start)
  #      ary = @scan_stack.pop
  #      break until ary
  #
  #      @current_dir, @current_n = ary
  #
  #      updated = scan_line(@current_dir, @current_n)
  #
  #      public_send_if_defined(:loop_end)
  #
  #      @loop_count += 1
  #      break if solve_completed?
  #    end
  #
  #    public_send_if_defined(:solve_end)
  #  end

  alias_method :solve, :solve2

  def public_send_if_defined(sym)
    public_send(sym) if respond_to?(sym)
  end

  #
  # 結果を表示する
  #
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


  #
  # 内部状態を出力する
  #
  def dump(p="O", s=" ", u=".")
    puts "--------------------------------------------------------------------------------"
    puts "loop_count=#{@loop_count}"
    #    puts "width=#{@width}"
    #    puts "height=#{@height}"

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
  # クラスメソッド
  #
  class << self
    # 候補の算出
    # @param Integer width 行・列の長さ
    # @param [Array] pix ヒントの数字配列
    # @param  [Array] base 確定した配置情報。 長さは width
    # @return [Array] 解候補の配列
    # @todo 高速化。baseを元に不要な探索を中断する
    # width = 5, ary = [1]に対して、以下の配列を返す
    # [[1,0,0,0,0],
    #  [0,1,0,0,0],
    #  [0,0,1,0,0],
    #  [0,0,0,1,0],
    #  [0,0,0,0,1]]
    def getCandidates(width, hint, base=nil)
      raise ArgumentError, "invalid argument"  if width == 0 || hint == nil

      return [ Array.new(width, 0) ] if hint.length == 0 || (hint.length==1 && hint[0] == 0)

      # spcの条件
      # * 要素の数は hintの個数と同じ
      # * spcの要素は、最初の要素は 0以上、それ以外は1以上の整数
      # * 要素の合計は (width - hint.length)以下
      spc = Array.new(hint.length, 1)
      spc[0] = 0

      candidates = []

      # 再帰的に候補を調べる
      self.gc_f0(width, 0, spc, hint, base) { |line|
        # 確定情報を元に追加するか否か決める
        match = true
        if base != nil
          base.each_with_index do |b, n|
            next if b == nil
            if b != line[n]
              match = false
              break
            end
          end
        end

        if match
#          unless candidates.include? line
            candidates << line
#          end
        end
      }

      candidates.uniq
    end

    # getCandidatesの補助関数。再帰的に探索を行う
    def gc_f0(width, n, spc, pix, base = nil, &block)
      raise ArgumentError, "Bad Argument" if spc == nil
      raise ArgumentError, "Bad Argument" if pix == nil

      num_elements = spc.length

      return if num_elements <= n

      # count <- 空白の数上限
      count = width
      num_elements.times do |idx|
        count -= spc[idx] if  n != idx
        count -= pix[idx]
      end
      count -= spc[n]

      # TODO : nまでの要素をbaseと比較、マッチした時だけ再帰呼び出しする
      match = compare_candidate(width, spc, pix, n, base)

      s0 = spc[n]
      while 0 <= count
        line = calcLine(spc, pix, width)
        block.call line if block_given?
        self.gc_f0(width, n+1, spc, pix, base, &block) if match

        spc[n] += 1
        count -= 1
      end
      spc[n] = s0
    end

    
    def compare_candidate(width, spc, pix, n, base = nil)
# return true
      return true if base == nil
      
      temp = []

      n.times do |i|
        spc[i].times do
          temp << 0
        end
        pix[i].times do
          temp << 1
        end
      end

      # BUG : tempの長さがwidthを超えてしまうことがある
      if width < temp.length
        puts "width: #{width}"
        puts "spc: #{spc}"
        puts "pix: #{pix}"
        puts "n: #{n}"
        puts "temp : #{temp.to_s}"

        raise ArgumentError
      end


      match = true
      temp.each_with_index do |v, idx|
        next if base[idx] == nil
        if base[idx] != v
          match = false
          break
        end
      end
#      pp "base #{base.to_s}"
#      pp "temp #{temp.to_s}"
#      pp match.to_s
      match
    end


    # TODO calclineは無駄。一々計算しなくても再帰処理の中で順次生成していけばいい

    # 空白、ドット情報から行・列の1ライン分を生成
    # @param
    # @param
    # @param
    # @return 1ライン分
    def calcLine(spc, hint, width)
      raise ArgumentError, "Bar Argument" if spc == nil
      raise ArgumentError, "Bar Argument" if hint == nil
      raise ArgumentError, "Bar Argument" if width <= 0

      line = []
      elem_length = spc.length

      elem_length.times do |n|
        spc[n].times do
          line << 0
        end

        hint[n].times do
          line << 1
        end
      end

      (width - line.length).times do
        line << 0
      end

      line
    end

    #
    # 候補の論理積
    #
    def getProductOfLine(lines)
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
    def getSumOfLine(lines)
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
    def eliminateCandidates(line, candidates)
      ary_matched = []

      # puts "eliminateCandidates"
      # puts "#{line.to_s}"
      candidates.each do |candidate|
        # puts "#{candidate.to_s}"

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
    #        0.5以下であれば確定するドットは存在しない
    def calcOccupancy(hint, width)
      sum = 0.0
      hint.each do |v|
        sum += v
      end
      sum += hint.length - 1

      return sum/width
    end
  end

end


if __FILE__ == $0
  class PixeLogicTest < Test::Unit::TestCase
    def test00_Init0
      logic = PixeLogic.new({:width => 5,
                             :height => 10
                            })

      assert_equal(5, logic.width)
      assert_equal(10, logic.height)
    end

    def test01_GetCandidates
      candidates = PixeLogic.getCandidates(5, [1,2])
      assert_equal(3, candidates.length)
      [ [1,0,1,1,0],
        [1,0,0,1,1],
        [0,1,0,1,1] ].each do |el|
        assert_true(candidates.include? el)
      end
      
      candidates = PixeLogic.getCandidates(5, [1])
      assert_equal(5, candidates.length)
      [ [1,0,0,0,0],
        [0,1,0,0,0],
        [0,0,1,0,0],
        [0,0,0,1,0],
        [0,0,0,0,1]].each do |el|
        assert_true(candidates.include? el)
      end

      candidates = PixeLogic.getCandidates(5, [1,1])
      assert_equal(6, candidates.length)
      [ [1,0,1,0,0],
        [1,0,0,1,0],
        [1,0,0,0,1],
        [0,1,0,1,0],
        [0,1,0,0,1],
        [0,0,1,0,1]].each do |el|
        assert_true(candidates.include? el)
      end

      candidates = PixeLogic.getCandidates(5, [3])
      assert_equal(3, candidates.length)
      [ [1,1,1,0,0],
        [0,1,1,1,0],
        [0,0,1,1,1] ].each do |el|
        assert_true(candidates.include? el)
      end

      candidates = PixeLogic.getCandidates(5, [1,3])      
      assert_equal(1, candidates.length)
      [[1,0,1,1,1]].each do |el|
        assert_true(candidates.include? el)
      end

      candidates = PixeLogic.getCandidates(5, [])
      assert_equal(1, candidates.length)
      [[0,0,0,0,0]].each do |el|
        assert_true(candidates.include? el)
      end

      candidates = PixeLogic.getCandidates(5, [0])
      assert_equal(1, candidates.length)
      [[0,0,0,0,0]].each do |el|
        assert_true(candidates.include? el)
      end

      candidates = PixeLogic.getCandidates(5, [3], [1, nil, nil, nil, nil])
      assert_equal(1, candidates.length)
      [ [1,1,1,0,0],
      ].each do |el|
        assert_true(candidates.include? el)
      end
      
      candidates = PixeLogic.getCandidates(5, [3], [0, nil, nil, nil, nil])
      assert_equal(2, candidates.length)
      [ [0,1,1,1,0],
        [0,0,1,1,1]].each do |el|
        assert_true(candidates.include? el)
      end
      
      candidates = PixeLogic.getCandidates(5, [3], [nil, nil, nil, 1, nil])
      assert_equal(2, candidates.length)
      [ [0,0,1,1,1],
        [0,1,1,1,0],
      ].each do |el|
        assert_true(candidates.include? el)
      end
      

    end

    def test02_GetProduct
      line = PixeLogic.getProductOfLine([ [0,0,1,1],
                                          [0,1,0,1]])
      assert_equal([0,0,0,1], line)

      ###
      line = PixeLogic.getProductOfLine([ [1,0,1,1,0],
                                          [1,0,0,1,1],
                                          [0,1,0,1,1]])
      assert_equal([0,0,0,1,0], line)

      ###
      line = PixeLogic.getProductOfLine([ [1,0,0,0,0],
                                          [0,1,0,0,0],
                                          [0,0,1,0,0],
                                          [0,0,0,1,0],
                                          [0,0,0,0,1]])
      assert_equal([0,0,0,0,0], line)


      ###
      line = PixeLogic.getProductOfLine([ [1,0,1,0,0],
                                          [1,0,0,1,0],
                                          [0,1,0,1,0],
                                          [0,1,0,1,0],
                                          [0,1,0,0,1],
                                          [0,0,1,0,1]])
      assert_equal([0,0,0,0,0], line)

      ###
      line = PixeLogic.getProductOfLine([ [1,1,1,0,0],
                                          [0,1,1,1,0],
                                          [0,0,1,1,1]])
      assert_equal([0,0,1,0,0], line)

      ###
      line = PixeLogic.getProductOfLine([[1,0,1,1,1]])
      assert_equal([1,0,1,1,1], line)
    end


    def test03_GetSum
      line = PixeLogic.getSumOfLine([ [0,0,1,1],
                                      [0,1,0,1]])
      assert_equal([0,1,1,1], line)
    end

    def test04_EliminateCandidates
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

    def test05_GetLine
      logic = PixeLogic.new({ :width  => 5,
                              :height => 5,
                              :hint_h => [[1], [1,1], [3],   [1,1,1], [5]],
                              :hint_v => [[2], [2,1], [1,3], [2,1],   [2]],
                              :blank  => [Point.new(4, 3)],
                              :dot    => [Point.new(3, 2)]
                            })

      line = logic.getFieldLine("v", 4)
      assert_equal([nil,nil,nil,0,nil], line)

      line = logic.getFieldLine("h", 3)
      assert_equal([nil,nil,nil,nil,0], line)

      line = logic.getFieldLine("v", 3)
      assert_equal([nil,nil,1,nil,nil], line)

      line = logic.getFieldLine("h", 2)
      assert_equal([nil,nil,nil,1,nil], line)
    end

    def test06_Occupancy
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

    def test07_Occupancy2
#      logic = PixeLogic.load("ex5x5.rb")

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


#    def testSolve5x5
#      logic = PixeLogic.new({ :width  => 5,
#                              :height => 5,
#                              :hint_h => [[1], [1,1], [3],   [1,1,1], [5]],
#                              :hint_v => [[2], [2,1], [1,3], [2,1],   [2]]
#                            })
#
#      logic.solve
#      # TODO 解の比較
#    end

#    def testSetup2
#      logic = PixeLogic.new({ :width  => 5,
#                              :height => 5,
#                              :hint_h => [[1], [1,1], [3],   [1,1,1], [5]],
#                              :hint_v => [[2], [2,1], [1,3], [2,1],   [2]]
#                            })
#
#      logic.setup2
#      ary = logic.scan_priority
#      assert_equal(logic.width + logic.height, ary.length)
#      puts ""
#      ary.each do |el|
#        k, v = el
#        puts "#{k.to_s} : #{v}"
#      end
#    end


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

 * 解候補計算に確定情報を渡し、不必要な探索をやめる
 * 開始前チェック、h,vの各ヒントのピクセル数が一致しなければ処理を中断する

 * 論理的に置けない場所に xを付ける



=end
