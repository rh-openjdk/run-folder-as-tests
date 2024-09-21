# small library which can generate tap comaptible files
# If you want to stream as you run, you will need to fale header total infomration
# start your output or each sub suite with `tapHeader total meta1 meta2 .. metaN` call. only totla is mandatory
# print individual tests with `tapTestStart ok/not ok, numerical id and title` (three) params
# print details by `tapLine id content`
# or by `tapFromFile id alias`  where each file is head/grep/tail or message that it do nto exists is printed (alilas is wildchar or human readabel explanation of file)
# close each test by `tapTestEnd`



## First mandatroy argument is number of tests
## all others are strings, written in as header metadata
function tapHeader() {
  local counter=0
  for var in "$@" ; do
    let counter=$counter+1
    if [ $counter -eq 1 ] ; then
      echo "1..$var"
    else
      echo "# $var"
    fi
  done
}

function tapTestStart() {
  local ok="$1"
  local id="$2"
  local title="$3"
  if [ "$ok" == "ok" ] ; then
    echo "ok $id - $title"
  else
    echo "not ok $id - $title"
  fi
  echo "  ---"
}

function tapTestEnd() {
  echo "  ..."
}

function tapLine() {
  local id="$1"
  local line="$2"
  echo "    $id: $line"
}

function tapFromFile() {
  local file="$1"
  local alilas="$2"
  if [ ! -e "$file" ]; then
    tapLine "$file/$alilas" "do not exists"
  else
    echo "    head $file/$alilas:"
    echo "      |"
    head "$file" -n 10 | while IFS= read -r line; do
      line=`echo $line | sed 's/^\s*\|\s*$//g'`
      echo "        $line"
    done
    echo "    grep $file/$alilas:"
    echo "      |"
    grep -n -i -e fail -e error -e "not ok" -B 0 -A 0 $file| while IFS= read -r line; do
      line=`echo $line | sed 's/^\s*\|\s*$//g'`
      echo "        $line"
    done
    echo "    tail $file/$alilas:"
    echo "      |"
    tail "$file" -n 10 | while IFS= read -r line; do
      line=`echo $line | sed 's/^\s*\|\s*$//g'`
      echo "        $line"
    done
  fi
}

function tapFromWholeFile() {
  local file="$1"
  local alilas="$2"
  if [ ! -e "$file" ]; then
    tapLine "$file/$alilas" "do not exists"
  else
    echo "    cat $file/$alilas:"
    echo "      |"
    cat $file| while IFS= read -r line; do
      line=`echo $line | sed 's/^\s*\|\s*$//g'`
      echo "        $line"
    done
  fi
}
