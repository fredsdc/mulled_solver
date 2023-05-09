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

def calc_middle_solution idb, wdb
  solution = [ idb.query("SELECT * FROM puzzle_es WHERE solved = 1 LIMIT 1").first ]
  while solution.last[:iteract] > 0
    solution += [ idb.query("SELECT * FROM puzzle_es WHERE id = ?", solution.last[:ref]).first ]
  end
  solution.reverse
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

def iteract_backs edb, iteract
  edb.execute("BEGIN")
  j = /-/
  l = /_/
  k = iteract + 1
  edb.query("SELECT item FROM backs WHERE iteract = ?", iteract).each do |i|
    arry = solve(i[:item].gsub(l, "-")).
      map!{|s| [s.gsub(j, "_"), k]}.
      reject{|s| edb.query("SELECT id FROM backs WHERE item = ? AND iteract = ? LIMIT 1", s[0], k).any?}
    edb.execute_multi("INSERT INTO backs(item, iteract) VALUES (?, ?)", arry)
  end
  edb.execute("COMMIT")
  k
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
  if nomemory || tdb.tables.include?("puzzles") && tdb.query("SELECT * FROM puzzles WHERE solved = 1").any?
    wdb = tdb
    edb = Extralite::Database.new(filename + "e")
    idb = Extralite::Database.new(filename + "i")
  else
    wdb = Extralite::Database.new("")
    edb = Extralite::Database.new("")
    tdb.backup(wdb)
    tdb.close
    tdb = Extralite::Database.new(filename + "e")
    tdb.backup(edb)
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
  STDERR.puts "\"" + deadends_fixed.sort.reverse.join("\"\n\"") + "\""
  STDERR.puts ""
  STDERR.puts deadends_fixed.sort.reverse.map{|s| s.split("|")}.transpose.map{|a| a.join("  ")}
  STDERR.puts ""
end
exit if noexec

Signal.trap('INT') {
  trap = true
}

# Calcula novos itens
deadends_fixeds = /#{deadends_fixed.map{|s| s.gsub(/\|/, ".")}.join("|")}/

# Reseta edb se diferente da última iteração
if edb.tables.include?("puzzle_es")
  n = edb.query("SELECT ref FROM puzzle_es WHERE id = 1").first
  if ! n.nil? && n[:ref] != last_iteract_index + 1
    puts "clear"
    File.new(edb.filename, "w").close
  end
end

# Cria tabelas para meet me in the middle
unless edb.tables.include?("backs")
  edb.execute("CREATE TABLE        backs (id INTEGER PRIMARY KEY, item TEXT, iteract INTEGER)")
  edb.execute("CREATE INDEX        backs_item_index        ON backs(item)")
  edb.execute("CREATE INDEX        backs_iteract_index     ON backs(iteract)")
  edb.execute("INSERT INTO         backs(item, iteract)    VALUES (?, 0)", sol.gsub(/-/, "_"))
end
unless edb.tables.include?("puzzle_es")
  edb.execute("CREATE TABLE        puzzle_es (id INTEGER PRIMARY KEY, ref INTEGER, item TEXT, citem TEXT, solved BOOL)")
  edb.execute("CREATE INDEX        puzzle_es_citem_index   ON puzzle_es(citem)")
end

# Popula cópia da última iteração
i = edb.query("SELECT max(id) AS count FROM puzzle_es").first[:count] || 0
if i < (iteract_index - last_iteract_index)
  # index_now = índice do item anterior
  index_now = last_iteract_index + i
  turn = (iteract_index - last_iteract_index) / 100 + 1
  while index_now < iteract_index
    STDERR.print "\r#{line}\r-- Populando %d%% -- " % ((index_now - last_iteract_index) / turn)
    top = (index_now + turn) > iteract_index ? iteract_index : (index_now + turn)
    edb.execute("BEGIN")
    wdb.query("SELECT * FROM puzzles WHERE id > ? and id <= ?", index_now, top).each do |i|
      edb.execute("INSERT INTO puzzle_es(ref, item, citem, solved) VALUES (?, ?, ?, ?)",
      i[:id], i[:item], i[:item].gsub(/[x-]/, "_"), i[:solved])
    end
    edb.execute("COMMIT")
    exit if trap
    index_now += turn
  end
end

# Recupera qual iteração paramos
biteract = edb.query("SELECT max(iteract) as iteract from backs").first[:iteract]
biteract = iteract_backs(edb, biteract) if biteract == 0

if wdb.query("SELECT id FROM puzzles WHERE solved = 1 LIMIT 1").any?
  puts "\r#{line}\n-- Already solved, use muddle.rb to show solution --"
  exit
end

solved = idb.tables.include?("puzzles") ? idb.query("SELECT id FROM puzzle_es WHERE solved = 1 LIMIT 1").any? : false

# Main loop
until solved do
  # Feedback
  STDERR.puts "\r#{line}\r-- Iteração %d (%d items) -- " % [biteract, edb.query("SELECT COUNT(id) AS count FROM backs WHERE iteract = ?", biteract).first[:count]]

  # # Populate first iteraction of puzzle_es

  File.new(idb.filename, "w").close
  idb.execute("CREATE TABLE        puzzle_es (id INTEGER PRIMARY KEY, ref INTEGER, item TEXT, solved BOOL, iteract INTEGER)")
  idb.execute("CREATE INDEX        puzzle_es_item_index    ON puzzle_es(item)")
  idb.execute("CREATE INDEX        puzzle_es_iteract_index ON puzzle_es(iteract)")
  idb.execute("CREATE INDEX        puzzle_es_solved_index  ON puzzle_es(solved)")

  STDERR.print "\r#{line}\r-- Populando solução (0/%d) -- " % biteract
  j = edb.query("SELECT max(id) as id FROM puzzle_es").first[:id]

  idb.execute("BEGIN")
  edb.query("SELECT p.ref, p.item FROM backs b JOIN puzzle_es p ON b.item = p.citem WHERE b.iteract = ?", biteract).each do |i|
    idb.execute("INSERT INTO puzzle_es(ref, item, solved, iteract) VALUES (?, ?, 0, 0)", i[:ref], i[:item])
  end
  idb.execute("COMMIT")
  miteract=0

  while biteract > 0
    if trap
      dump_database edb, edb.filename, solved, append
      exit
    end

    STDERR.print "\r#{line}\r-- Procurando solução (%d/%d) (%d items) -- " % [miteract + 1, miteract + biteract, (idb.query("SELECT MAX(id) - MIN(id) + 1 as count FROM puzzle_es WHERE iteract = ?", miteract).first[:count] || 0)]
    biteract -= 1

    idb.execute("BEGIN")
    idb.query("SELECT * FROM puzzle_es WHERE iteract = ?", miteract).each do |i|
      arry = solve(i[:item]).
        reject{|s|
          s.match?(deadends_fixeds) ||
          edb.query("SELECT id FROM backs WHERE item = ? AND iteract = ? LIMIT 1", s.gsub(/[x-]/, "_"), biteract).empty? ||
          (norev && idb.query("SELECT id FROM puzzle_es WHERE item = ? LIMIT 1", rev(s)).any?) ||
          (norev && wdb.query("SELECT id FROM puzzles WHERE item = ? LIMIT 1", rev(s)).any?) ||
          (noturn && idb.query("SELECT id FROM puzzle_es WHERE item = ? LIMIT 1", s.reverse).any?) ||
          (noturn && wdb.query("SELECT id FROM puzzles WHERE item = ? LIMIT 1", s.reverse).any?) ||
          (noflip && idb.query("SELECT id FROM puzzle_es WHERE item = ? LIMIT 1", flip(s)).any?) ||
          (noflip && wdb.query("SELECT id FROM puzzles WHERE item = ? LIMIT 1", flip(s)).any?) ||
          idb.query("SELECT id FROM puzzle_es WHERE item = ? LIMIT 1", s).any? ||
          wdb.query("SELECT id FROM puzzles WHERE item = ? LIMIT 1", s).any?
        }.
        map{|s| [ i[:id], s, sol == s.gsub(/x/,"-") ? solved = true : false, miteract + 1 ]}
      idb.execute_multi("INSERT INTO puzzle_es(ref, item, solved, iteract) VALUES (?, ?, ?, ?)", arry)
    end
    idb.execute("COMMIT")
    miteract += 1
  end

  solved = idb.query("SELECT id FROM puzzle_es WHERE solved = 1").any?
  unless solved
    STDERR.print "\r#{line}\r-- Preparando iteração -- "
    biteract = iteract_backs(edb, miteract)
  end
end

# Mostra solução
solution = calc_middle_solution idb, wdb
ref = solution.shift[:ref]
solution = calc_solution(wdb, puzzle, ref) + solution
show_solution solution
dump_database wdb, filename, solved, append
