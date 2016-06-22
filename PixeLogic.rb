#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'pp'
require 'test/unit'
require 'logger'

# TODO スタックに優先度を付ける
# TODO USR1シグナルで内部状態をダンプ
# TODO ラインの走査方向  確定したドットの偏りを見て逆順にする

# ================================================================================
#  探索候補スタック
#  TODO 追加時にフィールド情報から優先度を算出、ソートした状態を保つ
# ================================================================================
class Stack
  def initialize(logic)
    @ary = []
    @logic = logic
#    @field = logic.field
  end

  def add(v)
#    return if @ary.include? v
    match = true
    @ary.each do |el|
      tgt, progress = el
      if v == tgt
        match = false
        break
      end
    end
    return unless match

    dir, n = v
    progress = @logic.getProgressOfLine(dir, n)

    el = [v, progress]

    @ary.push el
    @ary.sort { |a, b| a[1] <=> b[1] }
  end

  def get
    v, progress = @ary.shift
    v
  end

  def length
    @ary.length
  end
end


# ================================================================================
#
# ================================================================================
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

  def to_s
    return "[#{@x},#{@y}]"
  end
end


# ================================================================================
#
# ================================================================================
class Cfg
  attr_reader :width, :height, :hint_v, :hint_h

  def Width (v)
    @width = v
  end

  def Height (v)
    @height = v
  end

  def HintV(v)
    @hint_v = v
  end

  def HintH(v)
    @hint_h = v
  end
end


# ================================================================================
#
# ================================================================================
class PixeLogic
  attr_reader   :width, :height
  attr_reader   :hint_v, :hint_h
  attr_accessor :field
  attr_reader   :candidates_v, :candidates_h
  attr_reader   :loop_count
  attr_reader   :scan_priority

  attr_accessor :logger

  #
  #
  #
  def self.load(filename)
    @field = {}
    @dot_count = 0

    configfile = File.read(filename)

    cfg = Cfg.new
    cfg.instance_eval(configfile)

    logic = PixeLogic.new

    logic.instance_eval {
      @width  = cfg.width
      @height = cfg.height
      @hint_v = cfg.hint_v
      @hint_h = cfg.hint_h

      unless @width != nil && @height != nil && @hint_v != nil && hint_h != nil
        STDERR.puts "you must declare Width, Height, HintV, and HintH"
        exit
      end

      @candidates_v = Array.new(@width)
      @candidates_h = Array.new(@height)

      check_hints
    }

    return logic
  end

  #
  #
  #
  def initialize(info = nil)
    @logger = Logger.new(nil)

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

    raise "sum_v and sum_h not match" if sum_v != sum_h
  end

  #
  #
  #
  def setPixel(pt, v)
    raise ArgumentError, "pt == null" unless pt

    f_old = @field[pt]
    @field[pt] = v

    if    v == 1 && f_old != 1
      logger.debug "setPixel(#{pt.to_s}, 1)"
      @dot_count += 1
    elsif v != 1 && f_old == 1
      logger.debug "setPixel(#{pt.to_s}, 0)"
      @dot_count -= 1
    end
  end

  # 行・列の完成率を取得する
  # @param [String] dir "v" または "h"
  # @param [Integer] n 行、または列の番号
  # @return
  # @todo 高速化のためキャッシュする
  def getProgressOfLine(dir, n)
    line = getFieldLine(dir, n)
    hint = (dir=='v')? @hint_v[n] : @hint_h[n]

    pix_total = hint.inject(:+) # ドットの合計

    sum = 0
    line.each do |v|
      sum += 1 if v == 1
    end
    return sum / pix_total.to_f
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
  def getCandidatesOfLine(dir, n, base)
    ary = nil

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
    logger.debug "scan_line(#{dir},#{n})"

    dir_next = (dir == "h")? "v" : "h"
    x, y = n, n

    line_old   = getFieldLine(dir, n)
    line       = line_old.dup
    logger.debug "#{line_old.to_s}"

    candidates = getCandidatesOfLine(dir, n, line)

    if 1 < candidates.length
      logger.debug "複数の配置候補 (#{candidates.length})"
      new_candidates = PixeLogic.eliminateCandidates(line, candidates)

      if candidates.length != new_candidates.length
        logger.debug "candidates eliminated : #{candidates.length} -> #{new_candidates.length}"
        if dir == "v"
          @candidates_v[n] = new_candidates
        else
          @candidates_h[n] = new_candidates
        end

        candidates = new_candidates
      end
    end

    if candidates.length == 1
      logger.debug "配置候補が一つだけ → 確定"
      line = candidates[0]

      # 新規に確定したピクセルに対してスキャンを登録する (ドット、空白ともに)
      line.each_with_index do |p, idx|
        next if line_old[idx] != nil

        logger.debug "新しい探索対象 #{dir_next},#{idx}"
        @scan_stack.add [dir_next, idx]

        if dir == "v"
          y = idx
        else
          x = idx
        end

        setPixel(Point.new(x, y), p)
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

        logger.debug "新しい探索対象 #{dir_next},#{idx}"
        @scan_stack.add [dir_next, idx]

        if dir == "v"
          y = idx
        else
          x = idx
        end

        setPixel(Point.new(x,y), 1)
      end

      # 論理和をとり、 0のところは空白で確定する
      line = PixeLogic.getSumOfLine(new_candidates)
      line.each_with_index do |p, idx|
        next if line_old[idx] == 0
        next if p != 0

        logger.debug "新しい探索対象 #{dir_next},#{idx}"
        @scan_stack.add [dir_next, idx]

        if dir == "v"
          y = idx
        else
          x = idx
        end

        setPixel(Point.new(x,y), 0)

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
  def setup
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

    logger.debug "scan_priority"
    @scan_priority.each do |v|
      logger.debug v.to_s
    end
  end

  #
  #
  #
  def solve
    @scan_stack = Stack.new(self)
    @loop_count = 0

    # 有力そうな候補(占有率の高い列)を先に登録
    setup
    @scan_priority.each do |ary|
      item, priority = ary

      # 0.5以下は確定するピクセルが無いので登録しても意味が無い
      if priority >= 0.7
        logger.debug "new scan line #{item.to_s}"
        @scan_stack.add item
      end
    end

    # 前詰め、後詰めで確定するピクセルの探索
    sweepHeadAndTailJustified

    public_send_if_defined(:solve_start)

    while 0 < @scan_stack.length
      public_send_if_defined(:loop_start)

      @current_dir, @current_n = @scan_stack.get

      break if @current_dir == nil

      scan_line(@current_dir, @current_n)

      public_send_if_defined(:loop_end)
      break if solve_completed?
      @loop_count += 1
    end

    public_send_if_defined(:solve_end)
  end

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
  end

  # 前詰め後詰めで確定するピクセルを探す
  def sweepHeadAndTailJustified
    logger.debug "sweepHeadAndTailJustified"

    # 水平方向
    @hint_h.each_with_index do |hint, y|
      line = PixeLogic.sweepLine(@width, hint)
      line.each_with_index do |v, x|
        if v == 1
          setPixel(Point.new(x, y), 1)
          @scan_stack.add ["v", x]
        end

      end
    end

    # 垂直方向
    @hint_v.each_with_index do |hint, x|
      line = PixeLogic.sweepLine(@height, hint)
      line.each_with_index do |v, y|
        if v == 1
          setPixel(Point.new(x, y), 1) if v == 1
          @scan_stack.add ["h", y]
        end
      end
    end
  end

  # ================================================================================
  # クラスメソッド
  # ================================================================================
  class << self

    #
    # @param
    # @param
    # @return
    def sweepLine(length, hint)
      numPix = 0
      hint.each do |v|
        numPix += v
      end

      # pp hint.to_s

      line0 = Array.new(length, 1)
      line1 = Array.new(length, 1)

      # 前詰め
      x = 0
      hint.each do |val|
        x += val
        if x < length
          line0[x] = 0
          x += 1
        end
      end
      (x...length).each do
        line0[x] = 0
        x += 1
      end

      # 後詰め
      x = length - 1
      hint.reverse.each do |val|
        x -= val
        line1[x] = 0 if 0 <= x
        x -= 1
      end
      (0..x).each do
        line1[x] = 0
        x -= 1
      end

      result = Array.new(length, 0)
      # 前方
      i=0
      while line0[i] == 1
        result[i] = (line1[i] == 1)? 1 : 0
        i += 1
      end

      # 後方
      i = length - 1
      while line1[i] == 1
        result[i] = (line0[i] == 1)? 1 : 0
        i -= 1
      end

      result
    end


    # 候補の算出
    # width = 5, ary = [1]に対して、以下の配列を返す
    # [[1,0,0,0,0],
    #  [0,1,0,0,0],
    #  [0,0,1,0,0],
    #  [0,0,0,1,0],
    #  [0,0,0,0,1]]
    # @param Integer width 行・列の長さ
    # @param [Array] pix ヒントの数字配列
    # @param  [Array] base 確定した配置情報。 長さは width
    # @return [Array] 解候補の配列
    def getCandidates(width, hint, base=nil)
      raise ArgumentError, "invalid argument"  if width == 0 || hint == nil

      return [ Array.new(width, 0) ] if hint.length == 0 || (hint.length==1 && hint[0] == 0)

      spc        = Array.new(hint.length) {|n| (n==0) ? 0 : 1 }
      candidates = []
      line0      = Array.new(width, nil)
      self.gc_f1(width, 0, spc, hint, line0, base) { |line|
        candidates << line
      }

      candidates.uniq
    end

    # getCandidatesの補助関数
    #
    # @param
    # @param
    # @return
    def gc_f1(width, n, spc, pix, line, base = nil, &block)
      raise ArgumentError, "Bad Argument" if spc == nil
      raise ArgumentError, "Bad Argument" if pix == nil
      raise ArgumentError, "Bad Argument" if width != line.length

      num_elements = spc.length

      if num_elements == n
        # 再帰処理終了
        line.length.times do |idx|
          line[idx] = 0 if line[idx] == nil
        end

        if block_given?
          match = compare_candidate(line, base)
          block.call line.dup if match
        end
        return
      end

      # spc_count <- 空白の数上限
      spc_count = width
      num_elements.times do |idx|
        spc_count -= spc[idx] if idx != n
        spc_count -= pix[idx]
      end

      # line上の最初の未定義のインデックス
      idx      = 0
      idx     += 1  while line[idx] != nil

      idx_bak  = idx
      line_bak = line.dup  # dupしたほうが早い。 50x50で 2秒程度の差がでる
      spc_bak  = spc[n]

      while spc[n] <= spc_count
        spc[n].times do
          line[idx] = 0
          idx += 1
        end

        pix[n].times do
          line[idx] = 1
          idx += 1
        end

        # 途中でも適合しないことが確実なら探索を終わらせる
        if compare_candidate(line, base)
          gc_f1(width, n+1, spc, pix, line, base, &block)
        end

        line    = line_bak.dup
#        (idx_bak ... line.length).each do |i|
#          line[i] = nil
#        end
        idx     = idx_bak
        spc[n] += 1
      end

      spc[n] = spc_bak
    end

    def compare_candidate(field_fixed, base = nil)
      return true if base == nil


      count = [field_fixed.length, base.length].min

      count.times do |i|
        next unless base[i] != nil && field_fixed[i] != nil

        if base[i] != field_fixed[i]
          return false
        end
      end

      true
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

  class PointTest < Test::Unit::TestCase
    def test00_Init0
      p0 = Point.new
      assert_equal(p0.x, 0)
      assert_equal(p0.y, 0)
    end

    def test01_Init1
      p1 = Point.new(1, -2)
      assert_equal(p1.x,  1)
      assert_equal(p1.y, -2)
    end

    def test03_Equal
      p0 = Point.new
      p1 = Point.new(0,0)
      p2 = Point.new(1,2)
      assert_equal(p0, p1)
      assert_not_equal(p0, p2)
    end

    def test04_Hash
      a = Point.new(1,1)
      b = Point.new(1,1)

      h = {}
      h[a] = -99
      assert_equal(-99, h[b])

    end

  end

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

#      4686825通り...
#      candidates = PixeLogic.getCandidates(50, [5,1,2,7,1,1,3,2,2])
#      puts candidates.length
#      candidates.each do |el|
#        puts el.to_s
#      end
      # 50, [1,1,1,8,2,2,11],

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
  end

end
