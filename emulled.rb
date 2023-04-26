#!/usr/bin/env ruby

# Functions

def recover_puzzle wdb
  s  = ""
  c1 = wdb.query("SELECT item FROM deadends WHERE id=1").first[:item]
  c2 = wdb.query("SELECT item FROM puzzles WHERE id=1").first[:item]
  c1.size.times do |i|
    s += c1[i] == "o" ? c2[i].sub(/x/,"X").sub(/o/,"O").sub(/-/,"_") : c2[i]
  end
  s
end

def gen_fixed_deadends sol
  arry  = fixed_deadends sol
  arry |= fixed_deadends(sol.reverse).map{|s| s.reverse}
  arry |= fixed_deadends(flip(sol)).map{|s| flip(s)}
  arry |= fixed_deadends(flip(sol).reverse).map{|s| flip(s.reverse)}
  arry.uniq.map{|s| s.gsub(/-/, ".")}
end

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

def flip puzzle
  puzzle.split('|').reverse.join('|')
end

# Finds next available db_dump_# filename
def db_dump_filename filename
  if filename.empty?
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

def show_solving puzzle
  STDERR.puts "-- Problema: --"
  STDERR.puts ""
  STDERR.puts [ puzzle.gsub(/X/,"x").gsub(/O/,"o").gsub(/_/,"-").split("|"),
    puzzle.gsub(/[xo]/,"-").gsub(/[XO_]/,"o").split("|") ].transpose.
    map{|l| l.join("  →  ").sub(/ *$/, "")}.join("\n")
  STDERR.puts ""
end

# Dump memory database
def dump_database wdb, filename, solved, append, perc = ''
  if wdb.filename.empty?
    ddb = Extralite::Database.new(filename)
    if ! ddb.tables.include?("puzzles")
      STDERR.puts "\r#{line}\r-- Gravando banco de dados #{filename} #{perc}-- "
      wdb.backup(ddb)
    elsif wdb.query("SELECT * FROM puzzles WHERE solved in (1, 't')").first.nil?
      if append
        statusddb = [ ddb.query("SELECT MAX(id) AS id FROM deadends").first[:id], ddb.query("SELECT MAX(id) AS id FROM puzzles").first[:id] ]
        statuswdb = [ wdb.query("SELECT MAX(id) AS id FROM deadends").first[:id], wdb.query("SELECT MAX(id) AS id FROM puzzles").first[:id] ]
        STDERR.puts "\r#{line}\r-- Atualizando banco de dados #{filename} #{perc}-- "
        ddb.execute("BEGIN")
        ddb.execute_multi("INSERT INTO deadends(item) VALUES (?)",
                          wdb.query("SELECT * FROM deadends WHERE id > ?", statusddb[0]).map{|d| [d[:item]]}.flatten) if statuswdb[0] > statusddb[0]
        ddb.execute_multi("INSERT INTO puzzles(ref, item, solved) VALUES (?, ?, ?)",
                          wdb.query("SELECT * FROM puzzles WHERE id > ?", statusddb[1]).map{|d| [d[:ref], d[:item], d[:solved]]}) if statuswdb[1] > statusddb[1]
        ddb.execute("COMMIT")
      else
        STDERR.puts "\r#{line}\r-- Gravando banco de dados #{filename} #{perc}-- "
        wdb.backup(ddb)
      end
    end
    ddb.close
  end
end

def solve puzzle
  arry  = move puzzle
  arry |= move(puzzle.reverse).map{|s| s.reverse}
  arry |= move(trans(puzzle)).map{|s| trans(s)}
  arry |= move(trans(puzzle).reverse).map{|s| trans(s.reverse)}
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

def trans puzzle
  puzzle.split('|').map{|s| s.chars}.transpose.map{|s| s.join}.join('|')
end

def calc_solution wdb, puzzle, id = 0
  STDERR.puts "\r#{line}\r"
  puts "-- Puzzle: \"#{puzzle}\" --"
  if id == 0
    solution = [ wdb.query("SELECT * FROM puzzles WHERE solved in (1, 't')").first ]
  else
    solution = [ wdb.query("SELECT * FROM puzzles WHERE id = ?", id).first ]
  end
  while solution.first[:id] > 1
    solution = [ wdb.query("SELECT * FROM puzzles WHERE id = ?", solution.first[:ref]).first ] + solution
  end
  solution
end

def calc_middle_solution wdb
  solution = [ wdb.query("SELECT * FROM puzzle_ms WHERE solved in (1, 't')").first ]
  while solution.first[:iteract] > 0
    solution = [ wdb.query("SELECT * FROM puzzle_ms WHERE id = ?", solution.first[:ref]).first ] + solution
  end
  solution
end

def show_solution solution
  puts "-- Solução: --"
  string = ""
  w = solution.first[:item].split('|').first.size
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
    puts solution.shift(n).map{|x| x[:item].split('|')}.transpose.map{|l| l.join("  ").sub(/ *$/, "")}.join("\n")
    puts ""
  end
end

def iteract_backs wdb, iteract
  wdb.execute("BEGIN")
  wdb.query("select item from backs where iteract = ?", iteract).each do |i|
    wdb.execute_multi("INSERT INTO backs(item, iteract) VALUES (?, ?)",
      solve(i[:item].gsub(/_/, "-")).map {|s| [s.gsub(/-/, "_"), iteract + 1]})
  end
  wdb.execute("COMMIT")
  iteract + 1
end

# Main program

require 'extralite'
require 'optparse'

line           = '                                                                          '
filename       = ''
puzzle         = nil
deadends       = []
deadends_fixed = []
quiet          = false
nomemory       = false
noexec         = false
append         = false
middle         = false
reset          = false

# Parse options
opt = OptionParser.new do |parser|
  parser.on('-h', '--help', 'Mostra este help.') do |h|
    puts parser
    exit
  end

  parser.on('-a', '--append', 'Incrementar arquivo gravado.') do |n|
    append = true
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

  parser.on('-x', '--meet-middle', 'Meet me in the middle.') do |q|
    middle = true
  end

  parser.on('-z', '--reset-meet-middle', 'Reset meet me in the middle.') do |q|
    reset = true
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
if filename.empty?
  wdb = Extralite::Database.new("")
else
  tdb = Extralite::Database.new(filename)
  if nomemory || tdb.tables.include?("puzzles") && tdb.query("SELECT * FROM puzzles WHERE solved = 1").any?
    wdb = tdb
  else
    wdb = Extralite::Database.new("")
    tdb.backup(wdb)
    tdb.close
  end
end

# Cria banco de dados se são existir
unless wdb.tables.include?("puzzles")
  STDERR.puts "-- Criando banco de dados --"
  wdb.execute("CREATE TABLE puzzles (id INTEGER PRIMARY KEY, ref INTEGER, item TEXT, solved BOOL)")
  wdb.execute("CREATE UNIQUE INDEX puzzle_item_index   ON puzzles(item)")
  wdb.execute("CREATE UNIQUE INDEX puzzle_id_index     ON puzzles(id)")
  wdb.execute("CREATE        INDEX puzzle_ref_index    ON puzzles(ref)")
  wdb.execute("CREATE        INDEX puzzle_solved_index ON puzzles(solved)")
  wdb.execute("CREATE TABLE deadends (id INTEGER PRIMARY KEY, item TEXT)")
else
  STDERR.puts "-- Abrindo banco de dados --"
end

# Popula o puzzle no banco de dados
if wdb.query("SELECT id FROM puzzles where id=1").empty?
  if puzzle.nil?
    STDERR.puts "Não encontrei o puzzle!"
    opt.parse %w[--help]
  else
    STDERR.puts "-- Populando banco de dados --"
    wdb.execute("INSERT INTO deadends(item) VALUES (?)", puzzle.gsub(/[xo]/,"-").gsub(/[XO_]/,"o"))
    wdb.execute("INSERT INTO puzzles(ref, item, solved) VALUES (1, ?, 0)", puzzle.gsub(/X/, "x").gsub(/O/, "o").gsub(/_/, "-"))
  end
else
  STDERR.puts "-- Recuperando puzzle e deadends do banco de dados --"
  puzzle = recover_puzzle wdb
  deadends_fixed |= wdb.query("SELECT item FROM deadends WHERE id > 1").map{|i| i[:item]}
end

# Recupera qual iteração paramos
if ! quiet && ! noexec
  iteract = 0
  iteract_index = 1
  last_iteract_index = 1
  while now = wdb.query("SELECT id FROM puzzles WHERE ref > ? LIMIT 1", iteract_index).first
    iteract += 1
    STDERR.puts "-- Iteração: #{iteract} (#{now[:id] - 1 - iteract_index}) --"
    last_iteract_index = iteract_index
    iteract_index = now[:id] - 1
  end
  STDERR.puts ""
end

# Declara variáveis
sol             = wdb.query("SELECT item FROM deadends WHERE id = 1").first[:item]
sol.size.times{|i| deadends_fixed.map!{|d| d[0, i] + " " + d[i + 1, sol.size]} if sol[i] == " "}
current_puzzle  = wdb.query("SELECT * FROM puzzles WHERE id = (SELECT ref FROM puzzles WHERE id = (SELECT MAX(id) FROM puzzles))").first
solved          = false
trap            = false
deadends_fixed |= deadends.map{|n| (sol[0, n] + "x" + sol[n+1, sol.size]).gsub(/[-o]/, ".")} | gen_fixed_deadends(sol)
filename        = db_dump_filename filename
deadends_fixed.select!{|d| d.size == sol.size}
solution        = []
t1              = Time.now

# Grava deadends
deadends_fixed.each do |d|
  wdb.execute("INSERT INTO deadends(item) VALUES (?)", d) unless wdb.query("SELECT id FROM deadends WHERE item = ?", d).any?
end

# Feedback
STDERR.puts "-- Puzzle: \"#{puzzle}\" --"
show_solving puzzle
if deadends_fixed.any?
  STDERR.puts "-- Deadends: --"
  STDERR.puts ""
  STDERR.puts deadends_fixed.sort.reverse.map{|s| s.split("|")}.transpose.map{|a| a.join("  ")}
  STDERR.puts ""
end
exit if noexec

# Calcula novos itens
STDERR.print "\r#{line}\r-- Calculando %d%% -- " % (current_puzzle[:id] % 200000 / 2000 + 1) unless middle
if wdb.query("SELECT id FROM puzzles WHERE solved = 1").empty?
  deadends_fixed.map!{|s| s.gsub(/\|/, ".")}

  # Meet me in the middle
  if middle
    # Cria tabelas para meet me in the middle
    unless wdb.tables.include?("backs")
      wdb.execute("CREATE TABLE        backs (id INTEGER PRIMARY KEY, item TEXT, iteract INTEGER)")
      wdb.execute("CREATE INDEX        backs_item_index        ON backs(item)")
      wdb.execute("INSERT INTO         backs(item, iteract)    VALUES (?, 0)", sol.gsub(/-/, "_"))
      wdb.execute("CREATE TABLE        puzzle_ms (id INTEGER PRIMARY KEY, ref INTEGER, item TEXT, citem TEXT, solved BOOL, iteract INTEGER)")
      wdb.execute("CREATE UNIQUE INDEX puzzle_ms_item_index    ON puzzle_ms(item)")
      wdb.execute("CREATE INDEX        puzzle_ms_citem_index   ON puzzle_ms(citem)")
      wdb.execute("CREATE INDEX        puzzle_ms_iteract_index ON puzzle_ms(iteract)")
      wdb.execute("CREATE INDEX        puzzle_ms_solved_index  ON puzzle_ms(solved)")
    end

    if reset
      wdb.execute("DELETE FROM backs WHERE id > 1")
      wdb.execute("DELETE FROM puzzle_ms")
    end

    i = wdb.query("SELECT COUNT(id) AS count FROM puzzle_ms WHERE iteract = 99").first[:count]
    if i < (iteract_index - last_iteract_index)
      # index_now = índice do item anterior
      index_now = last_iteract_index + i
      turn = (iteract_index - last_iteract_index) / 100 + 1
      while index_now < iteract_index
        STDERR.print "\r#{line}\r-- Populando %d%% -- " % ((index_now - last_iteract_index) / turn)
        top = (index_now + turn) > iteract_index ? iteract_index : (index_now + turn)
        wdb.execute("BEGIN")
        wdb.execute_multi("INSERT INTO puzzle_ms(ref, item, citem, solved, iteract) VALUES (?, ?, ?, ?, 99)",
          wdb.query("SELECT * FROM puzzles WHERE id > ? and id <= ?", index_now, top).
            map{|i| [i[:ref], i[:item], i[:item].gsub(/[x-]/, "_"), i[:solved]]})
        wdb.execute("COMMIT")
        index_now += turn
      end
    end

    # Recupera qual iteração paramos
    biteract = wdb.query("SELECT max(iteract) as iteract from backs").first[:iteract]
    biteract = iteract_backs(wdb, biteract) if biteract == 0

    solved = wdb.query("SELECT id FROM puzzle_ms WHERE solved = 1").any?
    while ! solved
      # Feedback
      STDERR.puts "\r#{line}\r-- Iteração %d (%d items) -- " % biteract, wdb.query("SELECT COUNT(id) FROM backs WHERE iteract = ?", biteract)

      # # Populate first iteraction of puzzle_ms
      wdb.execute("DELETE FROM puzzle_ms WHERE iteract < 99")
      wdb.query("SELECT p.* FROM backs b LEFT JOIN puzzle_ms p ON b.item = p.citem WHERE b.iteract = ? and p.iteract = 99", biteract).each do |i|
        wdb.execute("INSERT INTO puzzle_ms(ref, item, citem, solved, iteract) VALUES (?, ?, ?, ?, 0)", i[:id], i[:item], i[:citem], i[:solved])
      end
      miteract=0

      # Feedback
      STDERR.print "\r#{line}\r-- Procurando solução -- "

      while biteract > 0
        biteract -= 1
        wdb.query("SELECT * FROM puzzle_ms WHERE iteract = ?", miteract).each do |i|
          wdb.execute_multi("INSERT INTO puzzle_ms(ref, item, citem, solved, iteract) VALUES (?, ?, ?, ?, ?)",
            solve(i[:item]).
              reject{|s| deadends_fixed.map{|d| s.gsub(/\|/, ".").match?(d)}.any? ||
                wdb.query("SELECT id FROM backs where item = ? and iteract = ? limit 1", s.gsub(/[x-]/, "_"), biteract).empty?}.
              map{|s| [ i[:id], s, s.gsub(/[x-]/, "_"), sol == s.gsub(/x/,"-") ? solved = true : false, miteract + 1 ]}.
              select{|i| wdb.query("SELECT id FROM puzzle_ms WHERE item = ?", i[1]).empty?})
        end
        miteract += 1
      end

      solved = wdb.query("SELECT id FROM puzzle_ms WHERE solved = 1").any?
      unless solved
        STDERR.print "\r#{line}\r-- Preparando iteração -- "
        biteract = wdb.query("SELECT max(iteract) as iteract from backs").first[:iteract]
        biteract = iteract_backs(wdb, biteract)
      end
    end

    # Mostra solução
    dump_database wdb, filename, solved, append
    solution = calc_middle_solution wdb
    ref = solution.shift[:ref]
    solution = calc_solution(wdb, puzzle, ref) + solution
    show_solution solution
    exit
  end

  Signal.trap('INT') {
    trap = true
  }

  # Main loop
  until solved do
    # Dump database each 200.000 ids
    if current_puzzle[:id] % 2000 == 0
      STDERR.print "\r#{line}\r-- Calculando %d%% -- " % (current_puzzle[:id] % 200000 / 2000)
      if current_puzzle[:id] % 200000 == 0
        iteract_percentage = (current_puzzle[:id] - last_iteract_index) * 100 / (iteract_index - last_iteract_index) + 1
        dump_database wdb, filename, solved, append, (quiet ? "" : "%d%% " % iteract_percentage)
      end
    end

    if trap
      dump_database wdb, filename, solved, append
      exit
    end

    # Feedback, plus exists if too many iteractions
    unless quiet
      if current_puzzle[:id] > iteract_index
        iteract += 1
        last_iteract_index = iteract_index
        iteract_index = wdb.query("SELECT MAX(id) AS id FROM puzzles").first[:id]
        STDERR.puts "\r#{line}\r-- Iteração: #{iteract} (#{iteract_index - current_puzzle[:id] + 1}) #{"%.2f" % - (t1 - (t1 = Time.now))}s -- "

      end
      if iteract > 50
        STDERR.puts "Muitas iterações. Sem solução?"
        exit
      end
    end

    # Writes new not deadend states
    wdb.execute("BEGIN")
    wdb.execute_multi("INSERT INTO puzzles(ref, item, solved) VALUES (?, ?, ?)",
      solve(current_puzzle[:item]).reject{|s| deadends_fixed.map{|d| s.gsub(/\|/, ".").match?(d)}.any?}.
        map{|s| [ current_puzzle[:id], s, sol == s.gsub(/x/,"-") ? solved = true : false ]}.
        select{|i| wdb.query("SELECT id FROM puzzles WHERE item = ?", i[1]).empty?})
    wdb.execute("COMMIT")
    current_puzzle  = wdb.query("SELECT * FROM puzzles WHERE id = ?", current_puzzle[:id] + 1).first
  end
end

# Mostra solução
dump_database wdb, filename, solved, append
solution = calc_solution wdb, puzzle
show_solution solution
