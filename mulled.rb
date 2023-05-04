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

def rev puzzle
  puzzle.split('|').map{|s| s.reverse}.join('|')
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
  line           = '                                                                          '
  if wdb.filename.empty?
    wdb.execute("COMMIT") rescue nil
    ddb = Extralite::Database.new(filename)
    if ! ddb.tables.include?("puzzles")
      STDERR.puts "\r#{line}\r-- Gravando banco de dados #{filename} #{perc}-- "
      wdb.backup(ddb)
    elsif ddb.query("SELECT * FROM puzzles WHERE solved = 1 LIMIT 1").first.nil?
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
  else
    STDERR.puts "\r#{line}\r-- Gravando banco de dados #{filename} #{perc}-- "
    wdb.execute("COMMIT") rescue nil
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

def solvex puzzle
  arry  = movex puzzle
  arry |= movex(puzzle.reverse).map{|s| s.reverse}
  arry |= movex(trans(puzzle)).map{|s| trans(s)}
  arry |= movex(trans(puzzle).reverse).map{|s| trans(s.reverse)}
end

def movex puzzle
  arry = []
  j = puzzle.size
  j.times do |i|
    c1 = puzzle.slice(-(i + 1), i + 1)
    c2 = c1.sub(/^([xo]*o)-/,"-\\1")
    if c1 != c2
      arry |= [ puzzle.slice(0, j - i - 1) + c2 ]
    end
  end
  arry
end

def trans puzzle
  puzzle.split('|').map{|s| s.chars}.transpose.map{|s| s.join}.join('|')
end

def gen_blocked sol
  lr = sol.split("|").first.size
  ud = sol.split("|").size
  lri = []
  udi = []
  sol.split("|").each{|s| s.size.times{|i| lri += [i] if s[i] == "o"}}
  trans(sol).split("|").each{|s| s.size.times{|i| udi += [i] if s[i] == "o"}}
  l  = lri.min
  r  = lri.max
  u  = udi.min
  d  = udi.max
  a  = []
  lr.times do |i|
    ud.times do |j|
      line1 = "x" * lr + "|"
      line2 = "x" * i + "o" + "x" * (lr - i - 1) + "|"
      line3 = "x" * (i + 1) + "." * (lr - i - 1) + "|"
      line4 = "." * (i) + "x" * (lr - i) + "|"
      if sol[j * (lr + 1) + i] == "."
        a += [ line1 * j + line2 + line3 * (ud - j - 1) ] if j < u && i < l
        a += [ line1 * j + line2 + line4 * (ud - j - 1) ] if j < u && i > r
        a += [ line3 * j + line2 + line1 * (ud - j - 1) ] if j > d && i < l
        a += [ line4 * j + line2 + line1 * (ud - j - 1) ] if j > d && i > r
      end
    end
  end
  sol.size.times{|i| a.map!{|d| d[0, i] + " " + d[i + 1, sol.size]} if sol[i] == " "}
  a.map{|s| s.slice(0,sol.size)}
end

def calc_solution wdb, puzzle, id = 0
  line           = '                                                                          '
  STDERR.puts "\r#{line}\r"
  puts "-- Puzzle: \"#{puzzle}\" --"
  if id == 0
    solution = [ wdb.query("SELECT * FROM puzzles WHERE solved = 1 LIMIT 1").first ]
  else
    solution = [ wdb.query("SELECT * FROM puzzles WHERE id = ?", id).first ]
  end
  while solution.first[:id] > 1
    solution = [ wdb.query("SELECT * FROM puzzles WHERE id = ?", solution.first[:ref]).first ] + solution
  end
  solution
end

def calc_middle_solution xdb, wdb
  solution = [ xdb.query("SELECT * FROM puzzle_xs WHERE solved = 1 LIMIT 1").first ]
  while solution.last[:iteract] > 0
    solution += [ xdb.query("SELECT * FROM puzzle_xs WHERE id = ?", solution.last[:ref]).first ]
  end
  solution.first[:ref] = wdb.query("SELECT * FROM puzzles WHERE item = ? LIMIT 1", solution.first[:item]).first[:id]
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

# Main program

require 'extralite'
require 'optparse'

line           = '                                                                          '
filename       = ''
puzzle         = nil
deadends       = []
deadends_fixed = []
quiet          = false
nomemory       = true
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

  parser.on('-m', '--memory', 'Usar o banco de dados em memória (ignorado se não houver nome de arquivo).') do |m|
    nomemory = false
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
  xdb = Extralite::Database.new("")
else
  tdb = Extralite::Database.new(filename)
  if nomemory || tdb.tables.include?("puzzles") && tdb.query("SELECT * FROM puzzles WHERE solved = 1 LIMIT 1").any?
    wdb = tdb
    xdb = Extralite::Database.new(filename + "x")
  else
    wdb = Extralite::Database.new("")
    xdb = Extralite::Database.new("")
    tdb.backup(wdb)
    tdb.close
    tdb = Extralite::Database.new(filename + "x")
    tdb.backup(xdb)
    tdb.close
  end
end

# Cria banco de dados se são existir
unless wdb.tables.include?("puzzles")
  STDERR.puts "-- Criando banco de dados --"
  wdb.execute("CREATE TABLE        puzzles (id INTEGER PRIMARY KEY, ref INTEGER, item TEXT, solved BOOL)")
  wdb.execute("CREATE UNIQUE INDEX puzzle_item_index   ON puzzles(item)")
  wdb.execute("CREATE UNIQUE INDEX puzzle_id_index     ON puzzles(id)")
  wdb.execute("CREATE        INDEX puzzle_ref_index    ON puzzles(ref)")
  wdb.execute("CREATE        INDEX puzzle_solved_index ON puzzles(solved)")
  wdb.execute("CREATE TABLE        deadends (id INTEGER PRIMARY KEY, item TEXT)")
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
if ! noexec
  iteract = 0
  iteract_index = 1
  last_iteract_index = 1
  while now = wdb.query("SELECT id FROM puzzles WHERE ref > ? LIMIT 1", iteract_index).first
    iteract += 1
    STDERR.puts "-- Iteração: #{iteract} (#{now[:id] - 1 - iteract_index}) --" if ! quiet
    last_iteract_index = iteract_index
    iteract_index = now[:id] - 1
  end
  STDERR.puts "" if ! quiet
end

# Declara variáveis
sol             = wdb.query("SELECT item FROM deadends WHERE id = 1").first[:item]
sol.size.times{|i| deadends_fixed.map!{|d| d[0, i] + " " + d[i + 1, sol.size]} if sol[i] == " "}
current_puzzle  = wdb.query("SELECT * FROM puzzles WHERE id = (SELECT ref FROM puzzles WHERE id = (SELECT MAX(id) FROM puzzles))").first
solved          = false
trap            = false
deadends_fixed |= deadends.map{|n| (sol[0, n] + "x" + sol[n+1, sol.size]).gsub(/[-o]/, ".")} | gen_fixed_deadends(sol) | gen_blocked(sol.gsub(/-/, "."))
filename        = db_dump_filename filename
deadends_fixed.select!{|d| d.size == sol.size}
solution        = []
norev           = puzzle == rev(puzzle) ? true : false
noflip          = puzzle == flip(puzzle) ? true : false
noturn          = puzzle == puzzle.reverse ? true : false
t1              = Time.now

# Grava deadends
deadends_fixed.each do |d|
  wdb.execute("INSERT INTO deadends(item) VALUES (?)", d) unless wdb.query("SELECT id FROM deadends WHERE item = ? LIMIT 1", d).any?
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

Signal.trap('INT') {
  trap = true
}

# Calcula novos itens
# Meet me in the middle
if middle
  # Cria tabelas para meet me in the middle
  unless xdb.tables.include?("puzzle_xs")
    xdb.execute("CREATE TABLE        puzzle_xs (id INTEGER PRIMARY KEY, ref INTEGER, item TEXT, solved BOOL, iteract INTEGER)")
    xdb.execute("CREATE UNIQUE INDEX puzzle_xs_item_index    ON puzzle_xs(item)")
    xdb.execute("CREATE INDEX        puzzle_xs_solved_index  ON puzzle_xs(solved)")
    xdb.execute("CREATE INDEX        puzzle_xs_iteract_index ON puzzle_xs(iteract)")
  end

  # Recupera qual iteração paramos
  biteract = xdb.query("SELECT max(iteract) as iteract from puzzle_xs").first[:iteract]
  if biteract.nil? || biteract == 0
    xdb.execute("DELETE FROM puzzle_xs") if biteract == 0
    arry = [ sol.gsub(/-/, "x") ]
    t = wdb.query("Select item from puzzles where id=1").first[:item].gsub(/[^-]/,"").size
    t.times do |n|
      print "\r#{line}\r-- Gerando soluções (%d/%d) --" % [n + 1, t]
      arry1 = []
      arry.first.size.times do |i|
        arry1 += arry.select{|p| p[i] == "x"}.map{|p| p.slice(0, i) + "-" + p.slice(i + 1, p.size - 1)}
      end
      arry = n == 0 ? arry1.select{|p| p.match?(/o-|-o/) || trans(p).match?(/o-|-o/)} : arry1.uniq
    end
    STDERR.puts "\r#{line}\r-- Populando Meet in the Middle --"
    xdb.execute("BEGIN")
    arry.each do |p|
      xdb.execute("INSERT INTO puzzle_xs(ref, item, solved, iteract) VALUES (1, ?, 0, 0)", p)
    end
    xdb.execute("COMMIT")
    STDERR.puts "-- Iteração: 0 (%d) --" % xdb.query("SELECT max(id) AS count FROM puzzle_xs").first[:count]
    biteract = 1
  else
    biteract.times do |b|
      STDERR.puts "-- Iteração: %d (%d) --" % [b, xdb.query("SELECT count(id) AS count FROM puzzle_xs where iteract = ?", b).first[:count]]
    end
  end

  current_puzzle  = xdb.query("SELECT * FROM puzzle_xs WHERE id = (SELECT ref FROM puzzle_xs WHERE id = (SELECT MAX(id) FROM puzzle_xs))").first
  last_biteract_index, biteract_index = xdb.query("SELECT MIN(id) - 1, MAX(id) FROM puzzle_xs WHERE iteract = ?", biteract - 1).first.values
  solved = xdb.query("SELECT id FROM puzzle_xs WHERE solved = 1 LIMIT 1").any?

  # Test if solved from biteract_index
  STDERR.puts "\r#{line}\r-- Testing if already solved --"
  i = biteract_index
  j = xdb.query("SELECT MAX(id) AS id FROM puzzle_xs").first[:id]
  while i < j
    i += 1
    if wdb.query("SELECT id FROM puzzles WHERE item = ? and id <= ?", xdb.query("SELECT item FROM puzzle_xs WHERE id = ?", i).first[:item], iteract_index).any?
      xdb.execute("UPDATE puzzle_xs SET solved = 1 WHERE id = ?", i)
      solved = true
    end
  end

  # Main loop
  xdb.execute("BEGIN")
  until solved do
    # Dump database each 200.000 ids
    if current_puzzle[:id] % 1000 == 0
      n = (current_puzzle[:id] % 100000 / 1000)
      STDERR.print "\r#{line}\r-- Calculando %d%% -- " % (n == 0 ? 100 : n)
      if current_puzzle[:id] % 100000 == 0
        xdb.execute("COMMIT")
        iteract_percentage = (current_puzzle[:id] - last_biteract_index) * 100 / (biteract_index - last_biteract_index) + 1
        dump_database wdb, filename, solved, append, (quiet ? "" : "%d%% " % iteract_percentage)
        xdb.execute("BEGIN")
      end
    end

    if trap
      xdb.execute("COMMIT")
      dump_database xdb, filename, solved, append
      exit
    end

    # Feedback, plus exists if too many iteractions
    unless quiet
      if current_puzzle[:id] > biteract_index
        last_biteract_index = biteract_index
        biteract_index = xdb.query("SELECT MAX(id) AS id FROM puzzle_xs").first[:id]
        STDERR.puts "\r#{line}\r-- Iteração: #{biteract} (#{biteract_index - current_puzzle[:id] + 1}) #{"%.2f" % - (t1 - (t1 = Time.now))}s -- "
        biteract += 1
      end
      if biteract > 50
        STDERR.puts "Muitas iterações. Sem solução?"
        exit
      end
    end

    # Writes new states
    xdb.execute_multi("INSERT INTO puzzle_xs(ref, item, solved, iteract) VALUES (?, ?, ?, ?)", solvex(current_puzzle[:item]).
      select{|s| xdb.query("SELECT id FROM puzzle_xs WHERE item = ? LIMIT 1", s).empty?}.
      map{|s| [ current_puzzle[:id], s, solved = wdb.query("SELECT id FROM puzzles where item = ? AND id <= ? LIMIT 1", s, iteract_index).any?, biteract ]})
    current_puzzle  = xdb.query("SELECT * FROM puzzle_xs WHERE id = ?", current_puzzle[:id] + 1).first
  end
  xdb.execute("COMMIT")

  # Mostra solução
  solution = calc_middle_solution xdb, wdb
  ref = solution.shift[:ref]
  solution = calc_solution(wdb, puzzle, ref) + solution
  show_solution solution
  dump_database xdb, filename, solved, append
else
  solved = wdb.query("SELECT id FROM puzzles WHERE solved = 1 LIMIT 1").any?
  deadends_fixeds = /#{deadends_fixed.map{|s| s.gsub(/\|/, ".")}.join("|")}/
  biteract = xdb.tables.include?("puzzle_xs") ? xdb.query("SELECT max(iteract) as iteract from puzzle_xs").first[:iteract] : 0
  if biteract > 0 && xdb.query("SELECT id FROM puzzle_xs WHERE solved = 1 LIMIT 1").any?
    STDERR.puts "\r#{line}\r-- Solved in the middle --"
    solution = calc_middle_solution xdb, wdb
    ref = solution.shift[:ref]
    solution = calc_solution(wdb, puzzle, ref) + solution
    show_solution solution
    dump_database wdb, filename, solved, append
    exit

    # Test if solved from iteract_index
    STDERR.puts "\r#{line}\r-- Testing if already solved --"
    i = iteract_index
    j = wdb.query("SELECT MAX(id) AS id FROM puzzles").first[:id]
    while i < j
      i += 1
      if xdb.query("SELECT id FROM puzzle_xs WHERE item = ? and iteract <= ?", wdb.query("SELECT item FROM puzzles WHERE id = ?", i).first[:item], biteract - 1).any?
        wdb.execute("UPDATE puzzles SET solved = 1 WHERE id = ?", i)
        solved = true
      end
    end
  end

  # Main loop
  wdb.execute("BEGIN")
  until solved do
    # Dump database each 200.000 ids
    if current_puzzle[:id] % 1000 == 0
      n = (current_puzzle[:id] % 100000 / 1000)
      STDERR.print "\r#{line}\r-- Calculando %d%% -- " % (n == 0 ? 100 : n)
      if current_puzzle[:id] % 100000 == 0
        wdb.execute("COMMIT")
        iteract_percentage = (current_puzzle[:id] - last_iteract_index) * 100 / (iteract_index - last_iteract_index) + 1
        dump_database wdb, filename, solved, append, (quiet ? "" : "%d%% " % iteract_percentage)
        wdb.execute("BEGIN")
      end
    end

    if trap
      wdb.execute("COMMIT")
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
    arry = solve(current_puzzle[:item]).
      reject{|s|
        s.match?(deadends_fixeds) ||
        (norev && wdb.query("SELECT id FROM puzzles WHERE item = ? LIMIT 1", rev(s)).any?) ||
        (noturn && wdb.query("SELECT id FROM puzzles WHERE item = ? LIMIT 1", s.reverse).any?) ||
        (noflip && wdb.query("SELECT id FROM puzzles WHERE item = ? LIMIT 1", flip(s)).any?)
      }.
      select{|s| wdb.query("SELECT id FROM puzzles WHERE item = ? LIMIT 1", s).empty?}.
      map{|s| [ current_puzzle[:id], s, sol == s.gsub(/x/,"-") ? solved = true : false ]}
    wdb.execute_multi("INSERT INTO puzzles(ref, item, solved) VALUES (?, ?, ?)", arry)
    if biteract > 0
      ids = xdb.query("SELECT id FROM puzzle_xs WHERE item in ('#{arry.map{|a| a[1]}.join("','")}') and iteract <= ?", biteract - 1)
      if ids.any?
        STDERR.puts "\r#{line}\r-- Solved in the middle --"
        xdb.execute "UPDATE puzzle_xs SET solved = 1 WHERE id IN (#{ids.map{|a| a[:id]}.join(",")})"
        wdb.execute("COMMIT")

        solution = calc_middle_solution xdb, wdb
        ref = solution.shift[:ref]
        solution = calc_solution(wdb, puzzle, ref) + solution
        show_solution solution
        dump_database wdb, filename, solved, append
        exit
      end
    end
    current_puzzle  = wdb.query("SELECT * FROM puzzles WHERE id = ?", current_puzzle[:id] + 1).first
  end
  wdb.execute("COMMIT")

  # Mostra solução
  solution = calc_solution wdb, puzzle
  show_solution solution
  dump_database wdb, filename, solved, append
end
