#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
INITIAL_DIR="$(pwd)"

die () {
    echo >&2 "$@"
    exit 1
}
[ $# -eq 2 ] || [ $# -eq 1 ] || die "Usage: $0 filename [count]"

if [ $# -eq 2 ]; then
  ACTUAL_LINES=$($SCRIPT_DIR/internal/goodtobad.sh "$1" "$2")
  tail -$ACTUAL_LINES "$1" >process.partial 2>/dev/null || die "Invalid arguments"
  set -- "process.partial"
fi

IGNOREREVS="#|compileError|EmptyCommit|NoCoverage"

FIRSTREV=$(grep -v '#' $1|head -1|awk 'BEGIN { FS="," } ; { print $1}')
LASTREV=$(tail -1 $1|awk 'BEGIN { FS="," } ; { print $1}')
FIRSTREVDATE="Unknown"
LASTREVDATE="Unknown"

#find the dates using brute force
for DIR in repos/*; do
  cd $DIR
  if git rev-parse $FIRSTREV &>/dev/null && git rev-parse $LASTREV &>/dev/null; then
    FIRSTREVDATE=$(git show --pretty=%ci $FIRSTREV|head -1)
    LASTREVDATE=$(git show --pretty=%ci $LASTREV|head -1)
    break
  fi
  cd ../..
done

echo "Looking at revisions $FIRSTREV - $LASTREV ($FIRSTREVDATE - $LASTREVDATE)"

cd "$INITIAL_DIR"

echo -n "+++Empty revisions: "
grep EmptyCommit $1|wc -l
echo

echo -n "+++Compile errors: "
grep compileError $1|wc -l
echo

echo -n "+++Good revisions: "
egrep -v "$IGNOREREVS" $1|wc -l
echo

echo -n "+++Test failures: "
grep SomeTestFailed $1|wc -l
echo

echo -n "+++Merges: "
egrep -v -e "$IGNOREREVS" $1 |grep ',True'|wc -l
echo

echo -n "+++Added/modified ELOC: "
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $7+$8 }'|paste -sd+ |bc
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $7+$8 }'|sort -n | $SCRIPT_DIR/statistics.pl
echo

echo -n "+++Covered lines: "
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $7 }'|paste -sd+ |bc
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $7 }'|sort -n | $SCRIPT_DIR/statistics.pl
echo

echo -n "+++Not covered lines: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { print $8 }'|paste -sd+ |bc
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $8 }'|sort -n | $SCRIPT_DIR/statistics.pl
echo

echo -n "+++Affected files: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { print $24 }'|paste -sd+ |bc
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $24 }'|sort -n | $SCRIPT_DIR/statistics.pl
echo

echo -n "+++Affected executable files: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { print $25 }'|paste -sd+ |bc
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $25 }'|sort -n | $SCRIPT_DIR/statistics.pl
echo

echo -n "+++Revisions affecting 0 files: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { print $24 }'|grep '^0$'|wc -l
echo

echo -n "+++Revisions affecting only test files: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($24 == $26 && $26 > 0) print 1 }'|wc -l
echo

echo -n "+++Revisions affecting only executable files: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($24 == $25 && $25 > 0) print 1 }'|wc -l
echo

echo -n "+++Revisions affecting executable or test files: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($25 > 0 || $26 > 0) print 1 }'|wc -l
echo

echo -n "+++Revisions adding executable code or affecting test files: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($7 > 0 || $8 > 0 || $26 > 0) print 1 }'|wc -l
echo

echo -n "+++Revisions affecting only test files without increasing coverage: "
>tmp
for R in $(egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($24 == $26) { print $1 } }')
do
  grep -B1 $R $1|awk 'BEGIN { FS="," } ; { print $3 }' | { read -r first; read -r second
    if [[ $first == $second ]]; then
      echo $R >> tmp
    fi
  }
done
cat tmp | wc -l
cat tmp
echo

echo -n "+++Revisions affecting only test files decreasing coverage: "
>tmp
for R in $(egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($24 == $26) { print $1 } }')
do
  grep -B1 $R $1|awk 'BEGIN { FS="," } ; { print $3 }' | { read -r first; read -r second
    if [[ $first -gt $second ]]; then
      echo $R >> tmp
    fi
  }
done
cat tmp |wc -l
cat tmp
echo

echo -n "+++Hunks: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { print $22 }'|paste -sd+ |bc
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $22 }'|sort -n | $SCRIPT_DIR/statistics.pl
echo

echo -n "+++Hunks w/ context 3: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { print $27 }'|paste -sd+ |bc
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $27 }'|sort -n | $SCRIPT_DIR/statistics.pl
echo

echo -n "+++Executable hunks: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { print $23 }'|paste -sd+ |bc
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $23 }'|sort -n | $SCRIPT_DIR/statistics.pl
echo

echo -n "+++Executable hunks w/ context 3: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { print $28 }'|paste -sd+ |bc
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $28 }'|sort -n | $SCRIPT_DIR/statistics.pl
echo

for (( B=10; B<20; B++ )); do
  echo -n "Covered lines from previous $(($B-9)) patches: "
  egrep -v "$IGNOREREVS" $1|awk "BEGIN { FS=\",\" } ; { print \$$B }"|paste -sd+ |bc
done
echo

echo -n "+++Revisions contribuiting to latent patch coverage@1: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { print $10 }'|grep -v '^0$'|wc -l
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $10 }'|grep -v '^0$'|sort -n | $SCRIPT_DIR/statistics.pl
echo

echo -n "+++Revisions contribuiting to latent patch coverage@10: "
egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { print $19 }'|grep -v '^0$'|wc -l
egrep -v "$IGNOREREVS" $1 |awk 'BEGIN { FS="," } ; { print $19 }'|grep -v '^0$'|sort -n | $SCRIPT_DIR/statistics.pl
echo

echo -n "+++Contribuition of revisions containing only test files to latent patch coverage@10: "
REVS=$( egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($19 > 0 && $24-$26 == 0) print $19 }'|wc -l )
LCOV=$( egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($19 > 0 && $24-$26 == 0) print $19 }'|paste -sd+|bc )
echo "$REVS revisions = $LCOV lines"

echo -n "+++Contribuition of revisions containing some test files to latent patch coverage@10: "
REVS=$( egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($19 > 0 && $26 > 0 && $24 > $26) print $19 }'|wc -l )
LCOV=$( egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($19 > 0 && $26 > 0 && $24 > $26) print $19 }'|paste -sd+|bc )
echo "$REVS revisions = $LCOV lines"

echo -n "+++Contribuition of revisions containing no test files to latent patch coverage@10: "
REVS=$( egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($19 > 0 && $26 == 0) print $19 }'|wc -l )
LCOV=$( egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($19 > 0 && $26 == 0) print $19 }'|paste -sd+|bc )
ACTUAL=$( egrep -v "$IGNOREREVS" $1|awk 'BEGIN { FS="," } ; { if ($19 > 0 && $26 == 0) print $1 }' |tr '\r\n' ' ')
echo "$REVS revisions = $LCOV lines ($ACTUAL)"

rm -f tmp process.partial
