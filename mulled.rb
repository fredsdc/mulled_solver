#!/usr/bin/env ruby

# Functions

def fixed_deadends sol
  arry = {}
  arry[0] = sol.match?(/^o/) ? sol.gsub(/o/, "-").sub(/^-/, "x") : nil
  arry[1] = sol.match?(/^-o/) ? sol.gsub(/o/, "-").sub(/^--/, "xx") : nil if arry[0].nil?
  arry[2] = sol.match?(/^-[^|]*\|o/) ? sol.gsub(/o/, "-").sub(/-/, "x").sub(/\|-/, "|x") : nil if arry[0].nil?
  arry[3] = sol.match?(/^--o/) ? sol.gsub(/o/, "-").sub(/^---/, "xxx") : nil if arry[1].nil?
  arry[4] = sol.match?(/^-[^|]*\|-[^|]*\|o/) ? sol.gsub(/o/, "-").sub(/-/, "x").sub(/\|-/, "|x").sub(/\|-/, "|x") : nil if arry[2].nil?
  arry[5] = sol.match?(/^--[^|]*\|-o/) ? sol.gsub(/o/, "-").sub(/--/, "xx").sub(/\|--/, "|xx") : nil if arry[1].nil? && arry[2].nil?
  arry[6] = sol.match?(/^---[^|]*\|--o/) ? sol.gsub(/o/, "-").sub(/---/, "xxx").sub(/\|---/, "|xxx") : nil if arry[3].nil? && arry[5].nil?
  arry[7] = sol.match?(/^--[^|]*\|--[^|]*\|-o/) ? sol.gsub(/o/, "-").sub(/--/, "xx").sub(/\|--/, "|xx").sub(/\|--/, "|xx") : nil if arry[4].nil? && arry[5].nil?
  arry[8] = sol.match?(/^---[^|]*\|---[^|]*\|--o/) ? sol.gsub(/o/, "-").sub(/---/, "xxx").sub(/\|---/, "|xxx").sub(/\|---/, "|xxx") : nil if arry[6].nil? && arry[7].nil?
  arry.values.compact
end

def gen_fixed_deadends sol
  arry  = fixed_deadends sol
  arry |= fixed_deadends(sol.reverse).map{|s| s.reverse}
  arry |= fixed_deadends(flip(sol)).map{|s| flip(s)}
  arry |= fixed_deadends(flip(sol).reverse).map{|s| flip(s.reverse)}
  arry.uniq.map{|s| s.gsub(/-/, ".")}
end

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

def trans puzzle
  puzzle.split('|').map{|s| s.chars}.transpose.map{|s| s.join}.join('|')
end

def flip puzzle
  puzzle.split('|').reverse.join('|')
end

def test_blocked puzzle sol
  sol.size.times{|i| puzzle = puzzle[0,i] + "O" + puzzle[i+1,sol.size] if puzzle[i] == "o" && sol[i] == "o"}
  blocked(puzzle) || blocked(puzzle.reverse) || blocked(flip(puzzle)) || blocked(flip(puzzle.reverse))
end

def blocked puzzle
  puzzle.match?(/^[x|]*o[^-o]*\|/) && p.split("|").map{|x| x[0,(p.index("o") + 1) % (p.index("|") + 1)]}.join.match?(/^x*ox*$/) ? true : false
end

def recover_puzzle
  s  = ""
  c1 = Deadend.first.item
  c2 = Puzzle.first.item
  c1.size.times do |i|
    s += c1[i] == "o" ? c2[i].sub(/x/,"X").sub(/o/,"O").sub(/-/,"_") : c2[i]
  end
  s
end

def show_solving puzzle
  STDERR.puts "-- Problema: --"
  STDERR.puts ""
  STDERR.puts [ puzzle.gsub(/X/,"x").gsub(/O/,"o").gsub(/_/,"-").split("|"),
         puzzle.gsub(/[xo]/,"-").gsub(/[XO_]/,"o").split("|") ].transpose.
       map{|l| l.join("  →  ").sub(/ *$/, "")}.join("\n")
  STDERR.puts ""
end

def show_solution puzzle
  STDERR.puts ""
  puts "-- Puzzle: \"#{puzzle}\" --"
  solution = [ Puzzle.where(solved: true).first ]
  while solution.first.id > 1
    solution = [ Puzzle.find(solution.first.ref) ] + solution
  end

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

# Dump memory database
def dump_database filename, solved
  if ::ActiveRecord::Base.connection_config[:database] == ":memory:"
    ddb = SQLite3::Database.new(filename)
    if ddb.table_info('puzzles').empty?
      STDERR.puts "-- Gravando banco de dados #{filename} --"
      sdb = ::ActiveRecord::Base.connection.raw_connection
      b = SQLite3::Backup.new(ddb, 'main', sdb, 'main')
      b.step(-1)
      b.finish
    else
      statussdb = [ Deadend.last.id, Puzzle.last.id ]
      statusddb = [ ddb.execute("SELECT * FROM deadends WHERE id=(SELECT max(id) FROM deadends)")[0][0], ddb.execute("SELECT * FROM puzzles WHERE id=(SELECT max(id) FROM puzzles)")[0][0] ]
      if statussdb[0] > statusddb[0] || statussdb[1] > statusddb[1]
        STDERR.puts "-- Atualizando banco de dados #{filename} --"
        ddb.transaction
        Deadend.where("id > ?", statusddb[0]).
          each{|i| ddb.execute "INSERT INTO deadends(id, item) VALUES (#{i.id}, '#{i.item}')"}
        Puzzle.where("id > ?", statusddb[1]).
          each{|i| ddb.execute "INSERT INTO puzzles(id, ref, item, solved) VALUES (#{i.id}, #{i.ref}, '#{i.item}', '#{i.solved}')"}
        ddb.commit
      end
    end
    ddb.close
  end
end

# Loads database from file to memory
def load_database filename
  if ::ActiveRecord::Base.connection_config[:database] == ":memory:"
    STDERR.puts "-- Carregando banco de dados --"
    sdb = ::ActiveRecord::Base.connection.raw_connection
    ddb = SQLite3::Database.open(filename)
    b = SQLite3::Backup.new(sdb, 'main', ddb, 'main')
    b.step(-1)
    b.finish
  end
end

# Finds next available db_dump_# filename
def db_dump_filename filename
  if filename == ":memory:"
    filename = 'db_dump_'
    index=0
    while File.exist?(filename + index.to_s)
      index += 1
    end
    filename += index.to_s
  end
  File.open(filename, "a") {}
  filename
end

# Main program

require 'sqlite3'
require 'optparse'
require 'active_record'

filename = ':memory:'
puzzle = nil
deadends = []
deadends_fixed = []
quiet = false
nomemory = false
noexec = false

# Parse options
opt = OptionParser.new do |parser|
  parser.on('-h', '--help', 'Mostra este help.') do |h|
    puts parser
    exit
  end

  parser.on('-d', '--db NAME', 'Nome do arquivo do banco de dados.') do |n|
    filename = n
  end

  parser.on('-e', '--ends string', 'String para marcar espaços onde uma bola preta impede a solução.') do |e|
    deadends = e.enum_for(:scan,/x/).map{ Regexp.last_match.begin(0) }
  end

  parser.on('-f', '--fixed-end string', 'Strings para marcar espaços onde uma bola preta impede a solução.') do |e|
    deadends_fixed |= [ e.gsub(/[^.|oxOX_ -]/, '') ]
  end

  parser.on('-m', '--no-mem', 'Não usar o banco de dados em memória (ignorado se não houver nome de arquivo).') do |m|
    nomemory = true
  end

  parser.on('-n', '--no-exec', 'Não executer.') do |m|
    noexec = true
  end

  parser.on('-q', '--quiet', 'Iterações quietas.') do |q|
    quiet = true
  end

  parser.on('-p', '--puzzle string', 'String que descreve o puzzle (para novos puzzles).
        "o" para bola branca
        "x" para bola preta
        "-" para espaço livre
        "|" para uma nova linha
        "O", "X", "_" para indicar os objetivos') do |h|
    puzzle = h
  end
end

begin
  opt.parse!
rescue
  # do nothing
end

# Qual banco de dados?
if filename != ":memory:"
  ddb = SQLite3::Database.new(filename)
  if nomemory || ddb.table_info('puzzles').present? && ddb.execute('select * from puzzles where solved="t"').present?
    ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database  => filename)
  else
    ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database  => ':memory:')
    load_database filename
  end
  ddb.close
else
  ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database  => filename)
end

# Cria banco de dados se são existir
if ! ActiveRecord::Base.connection.table_exists? 'puzzles'
  STDERR.puts "-- Criando banco de dados --"
  ActiveRecord::Base.connection.execute("CREATE TABLE puzzles (id INTEGER PRIMARY KEY, ref INTEGER, item TEXT, solved BOOL);")
  ActiveRecord::Base.connection.execute("CREATE TABLE deadends (id INTEGER PRIMARY KEY, item TEXT);")
  ActiveRecord::Base.connection.execute("CREATE UNIQUE INDEX item_index ON puzzles(item);")
else
  STDERR.puts "-- Abrindo banco de dados --"
end

# Existe um puzzle para resolver?
class Puzzle < ActiveRecord::Base
  def next
    Puzzle.where("id > ?", self.id).first || self
  end
end

class Deadend < ActiveRecord::Base
end

# Popula o puzzle no banco de dados
if Puzzle.first.nil?
  if puzzle.nil?
    STDERR.puts "Não encontrei o puzzle!"
    opt.parse %w[--help]
  else
    STDERR.puts "-- Populando banco de dados --"
    Deadend.new(item: puzzle.gsub(/[xo]/,"-").gsub(/[XO_]/,"o")).save
    Puzzle.new(ref: 1, item: puzzle.gsub(/X/, "x").gsub(/O/, "o").gsub(/_/, "-"), solved: false).save
  end
else
  STDERR.puts "-- Recuperando puzzle e deadends do banco de dados --"
  puzzle = recover_puzzle
  deadends_fixed |= Deadend.all.pluck(:item).drop(1)
end

# Recupera qual iteração paramos
if ! quiet && ! noexec
  iteract = 0
  iteract_index = 1
  while now = Puzzle.where("id > 1 and ref > ?", iteract_index).first
    iteract += 1
    STDERR.puts "-- Iteração: #{iteract} (#{now.id - 1 - iteract_index}) --"
    iteract_index = now.id - 1
  end
  STDERR.puts ""
end

# Declara variáveis
sol             = Deadend.first.item
sol.size.times{|i| deadends_fixed.map!{|d| d[0, i] + " " + d[i + 1, sol.size]} if sol[i] == " "}
current_puzzle  = Puzzle.find(Puzzle.last.ref)
solved          = false
trap            = false
deadends_fixed |= deadends.map{|n| (sol[0, n] + "x" + sol[n+1, sol.size]).gsub(/[-o]/, ".")} | gen_fixed_deadends(sol)
filename        = db_dump_filename filename
deadends_fixed.select!{|d| d.size == sol.size}
t1              = Time.now

# Grava deadends
deadends_fixed.each do |d|
  Deadend.new(item: d).save unless Deadend.where(item: d).any?
end

# Feedback
STDERR.puts "-- Puzzle: \"#{puzzle}\" --"
show_solving(puzzle)
if deadends_fixed.any?
  STDERR.puts "-- Deadends: --"
  STDERR.puts ""
  STDERR.puts deadends_fixed.map{|s| s.split("|")}.transpose.map{|a| a.join("  ")}
  STDERR.puts ""
end
exit if noexec

Signal.trap('INT') {
  trap = true
}

# Calcula novos itens
STDERR.puts "-- Calculando --"
if Puzzle.where(solved: true).empty?
  deadends_fixed.map!{|s| s.gsub(/\|/, ".")}

  # Main loop
  until solved do
    # Dump database each 200.000 ids
    if current_puzzle.id % 200000 == 0
      dump_database filename, solved
    end

    if trap
      dump_database filename, solved
      exit
    end

    # Feedback, plus exists if too many iteractions
    unless quiet
      if current_puzzle.id > iteract_index
        iteract += 1
        iteract_index = Puzzle.last.id
        STDERR.puts "-- Iteração: #{iteract} (#{iteract_index - current_puzzle.id + 1}) #{"%.2f" % - (t1 - (t1 = Time.now))}s --"
      end
      if iteract > 50
        STDERR.puts "Muitas iterações. Sem solução?"
        exit
      end
    end

    # Writes new not deadend states
    solve(current_puzzle.item).each do |s|
      unless deadends_fixed.map{|d| s.gsub(/\|/, ".").match?(d)}.any?
        Puzzle.new(ref: current_puzzle.id, item: s, solved: sol == s.gsub(/x/,"-") ? solved = true : false).save unless Puzzle.where(item: s).any?
      end
    end
    current_puzzle = current_puzzle.next
  end
end

# Mostra solução
show_solution puzzle
dump_database filename, solved
