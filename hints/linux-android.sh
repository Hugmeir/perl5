# set -x

userelocatableinc='define'

# On Android the shell is /system/bin/sh:
targetsh='/system/bin/sh'

# Down with locales!
# https://github.com/android/platform_bionic/blob/master/libc/CAVEATS
d_locconv='undef'
d_setlocale='undef'
d_setlocale_r='undef'
i_locale='undef'

# Bionic defines several stubs that just warn and return NULL
# https://gitorious.org/0xdroid/bionic/blobs/70b2ef0ec89a9c9d4c2d4bcab728a0e72bafb18e/libc/bionic/stubs.c
# https://android.googlesource.com/platform/bionic/+/master/libc/bionic/stubs.cpp

# If they warn with 'FIX' or 'Android', assume they are the stubs
# we want to avoid.

# These are all stubs as well, but the core doesn't use them:
# getusershell setusershell endusershell

# This script UU/archname.cbu will get 'called-back' by Configure.
cat > UU/archname.cbu <<'EOCBU'
# egrep pattern to detect a stub warning on Android.
# Right now we're checking for:
# Android 2.x: FIX ME! implement FUNC
# Android 4.x: FUNC is not implemented on Android
android_stub='FIX|Android'

cat > try.c << 'EOM'
#include <netdb.h>
int main() { (void) getnetbyname("foo"); return(0); }
EOM
$cc $ccflags try.c -o try
android_warn=`$run ./try 2>&1 | $egrep "$android_stub"`
if test "X$android_warn" != X; then
   d_getnbyname="$undef"
fi

cat > try.c << 'EOM'
#include <netdb.h>
int main() { (void) getnetbyaddr((uint32_t)1, AF_INET); return(0); }
EOM
$cc $ccflags try.c -o try
android_warn=`$run ./try 2>&1 | $egrep "$android_stub"`
if test "X$android_warn" != X; then
   d_getnbyaddr="$undef"
fi

cat > try.c << 'EOM'
#include <stdio.h>
#include <mntent.h>
#include <unistd.h>
int main() { (void) getmntent(stdout); return(0); }
EOM
$cc $ccflags try.c -o try
android_warn=`$run ./try 2>&1 | $egrep "$android_stub"`
if test "X$android_warn" != X; then
   d_getmntent="$undef"
fi

cat > try.c << 'EOM'
#include <netdb.h>
int main() { (void) getprotobyname("foo"); return(0); }
EOM
$cc $ccflags try.c -o try
android_warn=`$run ./try 2>&1 | $egrep "$android_stub"`
if test "X$android_warn" != X; then
   d_getpbyname="$undef"
fi

cat > try.c << 'EOM'
#include <netdb.h>
int main() { (void) getprotobynumber(1); return(0); }
EOM
$cc $ccflags try.c -o try
android_warn=`$run ./try 2>&1 | $egrep "$android_stub"`
if test "X$android_warn" != X; then
   d_getpbynumber="$undef"
fi

cat > try.c << 'EOM'
#include <sys/types.h>
#include <pwd.h>
int main() { endpwent(); return(0); }
EOM
$cc $ccflags try.c -o try
android_warn=`$run ./try 2>&1 | $egrep "$android_stub"`
if test "X$android_warn" != X; then
   d_endpwent="$undef"
fi

cat > try.c << 'EOM'
#include <unistd.h>
int main() { (void) ttyname(STDIN_FILENO); return(0); }
EOM
$cc $ccflags try.c -o try
android_warn=`$run ./try 2>&1 | $egrep "$android_stub"`
if test "X$android_warn" != X; then
   d_ttyname="$undef"
fi

EOCBU

case "$src" in
    /*) run=$src/Cross/run
            targetmkdir=$src/Cross/mkdir
            to=$src/Cross/to
            from=$src/Cross/from
            ;;
    *)  pwd=`test -f ../Configure && cd ..; pwd`
            run=$pwd/Cross/run
            targetmkdir=$pwd/Cross/mkdir
            to=$pwd/Cross/to
            from=$pwd/Cross/from
               ;;
esac
    
targetrun=adb-shell
targetto=adb-push
targetfrom=adb-pull
run=$run-$targetrun
to=$to-$targetto
from=$from-$targetfrom

cat >$run <<EOF
#!/bin/sh
doexit="echo \\\$?"
env=''
case "\$1" in
-cwd)
  shift
  cwd=\$1
  shift
  ;;
esac
case "\$1" in
-env)
  shift
  env=\$1
  shift
  ;;
esac
case "\$cwd" in
'') cwd=$targetdir ;;
esac
case "\$env" in
'') env="echo "
esac
exe=\$1
shift
args=\$@
$to \$exe > /dev/null 2>&1

# send copy results to /dev/null as otherwise it outputs speed stats which gets in our way.
# sometimes there is no $?, I dunno why? we then get Cross/run-adb-shell: line 39: exit: XX: numeric argument required
foo=\`adb -s $targethost shell "sh -c '(cd \$cwd && \$env ; \$exe \$args) > $targetdir/output.stdout ; \$doexit '"\`
# We get back Ok\r\n on android for some reason, grrr:
$from output.stdout
result=\`cat output.stdout\`
rm output.stdout
result=\`echo "\$result" | sed -e 's|\r||g'\`
foo=\`echo \$foo | sed -e 's|\r||g'\`
# Also, adb doesn't exit with the commands exit code, like ssh does, double-grr
echo "\$result"
exit \$foo

EOF
chmod a+rx $run

cat >$targetmkdir <<EOF
#!/bin/sh
adb -s $targethost shell "mkdir -p \$@"
EOF
chmod a+rx $targetmkdir

cat >$to <<EOF
#!/bin/sh
for f in \$@
do
  case "\$f" in
  /*)
    $targetmkdir \`dirname \$f\`
    adb -s $targethost push \$f \$f            || exit 1
    ;;
  *)
    $targetmkdir $targetdir/\`dirname \$f\`
    (adb -s $targethost push \$f $targetdir/\$f < /dev/null 2>&1) || exit 1
    ;;
  esac
done
exit 0
EOF
chmod a+rx $to

cat >$from <<EOF
#!/bin/sh
for f in \$@
do
  $rm -f \$f
  (adb -s $targethost pull $targetdir/\$f . > /dev/null 2>&1) || exit 1
done
exit 0
EOF
chmod a+rx $from

