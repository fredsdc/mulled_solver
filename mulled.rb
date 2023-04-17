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

def trans puzzle
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

# Dump memory database
def dump_database filename, solved
  if filename == ":memory:" && ! solved
    filename = 'db_dump'
    File.delete(filename) if File.exist?(filename)
  end
  if filename != ":memory:" && ::ActiveRecord::Base.connection_config[:database] == ":memory:"
    ddb = SQLite3::Database.new(filename)
    if ddb.table_info('puzzles').empty? || ddb.execute('select * from puzzles where solved="t"').empty?
      STDERR.puts "-- Gravando banco de dados --"
      sdb = ::ActiveRecord::Base.connection.raw_connection
      b = SQLite3::Backup.new(ddb, 'main', sdb, 'main')
      b.step(-1)
      b.finish
    end
  end
end

# Loads to memory database
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

# Main program

require 'sqlite3'
require 'optparse'
require 'active_record'

filename = ':memory:'
puzzle = nil
deadends = []
quiet = false
nomemory = false

opt = OptionParser.new do |parser|
  parser.on('-h', '--help', 'Mostra este help.') do |h|
    puts parser
    exit
  end

  parser.on('-d', '--db NAME', 'Nome do arquivo do banco de dados.') do |n|
    filename = n
  end

  parser.on('-m', '--no-mem', 'Não usar o banco de dados em memória (ignorado se não houver nome de arquivo).') do |m|
    nomemory = true
  end

  parser.on('-e', '--ends string', 'String para marcar espaços onde uma bola preta impede a solução.') do |e|
    deadends = e.enum_for(:scan,/x/).map{ Regexp.last_match.begin(0) }
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
else
  ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database  => filename)
  # Continuar?
  ddb = SQLite3::Database.new('db_dump')
  if ddb.table_info('puzzles').present? && ddb.execute('select item from puzzles where id < 2') ==
       [[puzzle.gsub(/[xo]/,"-").gsub(/[XO_]/,"o")], [puzzle.gsub(/X/, "x").gsub(/O/, "o").gsub(/_/, "-")]]
    load_database 'db_dump'
  end
end

# Cria banco de dados se são existir
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
    STDERR.puts "Não encontrei o puzzle!"
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

# Recupera qual iteração paramos
unless quiet
  iteract = 0
  iteract_index = 1
  while now = Puzzle.where("id != ? and ref >= ?", 1, iteract_index).first
    iteract += 1
    iteract_index = now.id
    STDERR.puts "-- Iteração: #{iteract} (#{now.id - now.ref}) --"
  end
end

# Feedback
STDERR.puts "-- Calculando --"
show_solving(puzzle)

# Começa o cálculo
sol      = Puzzle.first.item
current_puzzle   = Puzzle.find(Puzzle.last.ref)
solved   = false

Signal.trap('INT') {
  dump_database filename, solved
  exit
}

if Puzzle.where(solved: true).empty?
  # Main loop
  until solved do
    solve(current_puzzle.item).each do |s|
      if sol == s.gsub(/x/,"-")
        solved = true
        Puzzle.new(ref: current_puzzle.id, item: s, solved: solved).save
      else
        if Puzzle.where(:item => s).empty?
          Puzzle.new(ref: current_puzzle.id, item: s, solved: false).save
        end
      end
      unless quiet
        if current_puzzle.id >= iteract_index
          iteract += 1
          iteract_index = Puzzle.last.id
          STDERR.puts "-- Iteração: #{iteract} (#{iteract_index - current_puzzle.id}) --"
        end
      end
    end
    begin
      current_puzzle = current_puzzle.next
    end while deadends.map{|n| current_puzzle.item[n] == "x"}.any?
  end
end

show_solution puzzle
dump_database filename, solved
