#!/usr/bin/env ruby

# Functions

def move puzzle
  arry = []
  puzzle.size.times do |i|
    c1 = puzzle.slice(0, i + 1)
    c2 = c1.sub(/-([xo]*o)$/,"\\1-")
    if c1 != c2
      arry |= [ c2 + puzzle.slice(i + 1, puzzle.size) ]
    end
  end
  arry
end

def solve puzzle
  arry  = move puzzle
  arry |= move(puzzle.reverse).map{|s| s.reverse}
  arry |= move(trans(puzzle)).map{|s| trans(s)}
  arry |= move(trans(puzzle).reverse).map{|s| trans(s.reverse)}
end

def trans(puzzle)
  puzzle.split('|').map{|s| s.chars}.transpose.map{|s| s.join}.join('|')
end

def recover_puzzle
  s  = ""
  c1 = Puzzle.find(0).item
  c2 = Puzzle.find(1).item
  c1.size.times do |i|
    s += c1[i] == "o" ? c2[i].sub(/x/,"X").sub(/o/,"O").sub(/-/,"_") : c2[i]
  end
  s
end

def show_solving(puzzle)
  STDERR.puts "-- Problema: --"
  STDERR.puts [ puzzle.gsub(/X/,"x").gsub(/O/,"o").gsub(/_/,"-").split("|"),
         puzzle.gsub(/[xo]/,"-").gsub(/[XO_]/,"o").split("|") ].transpose.
       map{|l| l.join("  →  ").sub(/ *$/, "")}.join("\n")
end

def show_solution
  solution = [ Puzzle.where(solved: true).first ]
  while solution.first.id > 1
    solution = [ Puzzle.find(solution.first.ref) ] + solution
  end

  # puts solution.map.with_index{|i,index| "---------------\n" + index.to_s +
  #   ":\n---------------\n" + i.item.gsub(/\|/,"\n")}.join("\n\n")

  puts "-- Solução: --"
  string = ""
  w = solution.first.item.split('|').first.size
  n = 150 / (w + 2)
  arry = []
  solution.size.times do |i|
    string += ("%-" + w.to_s + "s  ") % i.to_s
    if (i + 1) % n == 0
      arry += [ string ]
      string = ""
    end
  end
  arry += [ string ]
  while solution.size > 0
    puts arry.shift.sub(/ *$/, "")
    puts ""
    puts solution.shift(n).map{|x| x.item.split('|')}.transpose.map{|l| l.join("  ").sub(/ *$/, "")}.join("\n")
    puts ""
  end
end

def iteractions ( puzzle )
  i=0
  while puzzle.id > 1
    i += 1
    puzzle = Puzzle.find(puzzle.ref)
  end
  STDERR.puts "-- Iteractions: #{i.to_s} --"
end

# Main program

require 'sqlite3'
require 'optparse'
require 'active_record'

filename = ':memory:'
puzzle = nil
deadends = []
quiet = false
interact = 0
interact_index = 1

opt = OptionParser.new do |parser|
  parser.on('-h', '--help', 'Prints this help.') do |h|
    puts parser
    exit
  end

  parser.on('-d', '--db NAME', 'Database filename.') do |n|
    filename = n
  end

  parser.on('-e', '--ends string', 'Array of the puzzle (x marks deadend positions).') do |e|
    deadends = e.enum_for(:scan,/x/).map{ Regexp.last_match.begin(0) }
  end

  parser.on('-q', '--quiet', 'Quiet iteractions.') do |q|
    quiet = true
  end

  parser.on('-p', '--puzzle string', 'Array of the puzzle (for new puzzles).
        use "o" for white ball
        use "x" for black ball
        use "-" for empty space
        use "|" for a new row
        use "O", "X", "_" to indicate ending positions') do |h|
    puzzle = h
  end
end

begin
  opt.parse!
rescue
  # do nothing
end

# Cria banco de dados se são existir
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database  => filename)
if ! ActiveRecord::Base.connection.table_exists? 'puzzles'
  STDERR.puts "-- Criando banco de dados --"
  ActiveRecord::Base.connection.execute("CREATE TABLE puzzles (id INTEGER PRIMARY KEY, ref INTEGER, item TEXT, solved BOOL);")
  ActiveRecord::Base.connection.execute("CREATE INDEX item_index ON puzzles(item);")
else
  STDERR.puts "-- Abrindo banco de dados --"
end

# Existe um puzzle para resolver?
class Puzzle < ActiveRecord::Base
  def next
    Puzzle.where("id > ?", self.id).first || self
  end
end

# Popula o puzzle no banco de dados
if Puzzle.first.nil?
  if puzzle.nil?
    STDERR.puts 'No puzzle given!'
    opt.parse %w[--help]
  else
    STDERR.puts "-- Populando banco de dados --"
    Puzzle.new(id:0, ref: 0, item: puzzle.gsub(/[xo]/,"-").gsub(/[XO_]/,"o"), solved: false).save
    Puzzle.new(id:1, ref: 1, item: puzzle.gsub(/X/, "x").gsub(/O/, "o").gsub(/_/, "-"), solved: false).save
  end
else
  STDERR.puts "-- Recuperando puzzle do banco de dados --"
  puzzle = recover_puzzle
end

# Feedback
STDERR.puts "-- Calculando --"
show_solving(puzzle)
puts "-- Puzzle: \"#{puzzle}\" --"

# Começa o cálculo
sol      = Puzzle.first.item
puzzle   = Puzzle.find(Puzzle.last.ref)
solved   = false

if Puzzle.where(solved: true).empty?
  # Main loop
  until solved do
    solve(puzzle.item).each do |s|
      if sol == s.gsub(/x/,"-")
        solved = true
        Puzzle.new(ref: puzzle.id, item: s, solved: solved).save
      else
        if Puzzle.where(:item => s).empty?
          Puzzle.new(ref: puzzle.id, item: s, solved: false).save
        end
      end
      unless quiet
        if puzzle.id >= interact_index
          interact += 1
          interact_index = Puzzle.last.id
          STDERR.puts "-- Iteraction: #{interact} (#{interact_index - puzzle.id}) --"
        end
      end
    end
    begin
      puzzle = puzzle.next
    end while deadends.map{|n| puzzle.item[n] == "x"}.any?
  end
end

show_solution
