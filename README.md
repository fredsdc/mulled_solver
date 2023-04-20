# mulled_solver
Brute force solve Mulled puzzles (mulled if a free Hako puzzle game for Android)

<pre>
Usage: mulled [options]
    -h, --help                       Mostra este help.
    -d, --db NAME                    Nome do arquivo do banco de dados.
    -e, --ends string                String para marcar espaços onde uma bola preta impede a solução.
    -f, --fixed-end string           Strings para marcar espaços onde uma bola preta impede a solução.
    -m, --no-mem                     Não usar o banco de dados em memória (ignorado se não houver nome de arquivo).
    -n, --no-exec                    Não executer.
    -q, --quiet                      Iterações quietas.
    -p, --puzzle string              String que descreve o puzzle (para novos puzzles).
        "o" para bola branca
        "x" para bola preta
        "-" para espaço livre
        "|" para uma nova linha
        "O", "X", "_" para indicar os objetivos
</pre>

Programmed in ruby. Text in portuguese.

Example:

<pre>
./mulled.rb -p "__- o|-X_ o|-  -x|-xxx-|o -xo" | tee s03.18
</pre>
