#!/bin/bash
BOOT="./boot"
KERNEL="./kernel"
INCLUDE="./inc"
NASM="nasm -f elf -g"
CFLAGS="-Wall -nostdinc -fno-builtin -fno-stack-protector -finline-functions -finline-functions-called-once -I./inc/ "
BOCHS="bochs"

if [ `uname` = "Linux" ]; then
    GCC="gcc "
    ON_GCC="gcc"
    LD="ld"
    OBJCPY="objcopy"
    #QEMU="/usr/local/bin/qemu-system-i386 "
    QEMU="qemu "
    BOCHS_CONF="./.bochs_linux"
else
    # on Mac
    GCC="/usr/local/gcc-4.5.2-for-linux32/bin/i586-pc-linux-gcc "
    ON_GCC="clang "
    LD="/usr/local/gcc-4.5.2-for-linux32/bin/i586-pc-linux-ld "
    OBJCPY="/usr/local/gcc-4.5.2-for-linux32/bin/i586-pc-linux-objcopy"
    OBJDUMP="/usr/local/gcc-4.5.2-for-linux32/bin/i586-pc-linux-objdump"
    QEMU="/usr/local/Cellar/qemu/1.2.1/bin/qemu-system-i386"
    BOCHS_CONF="./.bochs_mac"
fi

OBJDIR="./objs"
TOOL="./tool"
USEROBJDIR="./objs/usr"

do_clean() {
    echo "clean up"
    rm -rf a.img hd.img bochsout.txt $OBJDIR/ ./tool/mkfs.exe;
}

do_compile() {
    if [ ! -d "$OBJDIR" ]; then
	mkdir $OBJDIR;
    fi

    echo "building boot"
    flist=`cd $BOOT/; ls *.s;`
    for f in $flist;
    do
	cmd="$NASM $BOOT/$f -o $OBJDIR/${f/.s/.O}"
	echo $cmd; `$cmd`
    done
    
    echo "building kernel"
    flist=`cd $KERNEL/; ls *.s;`
    `cd ../`
    for f in $flist;
    do
	cmd="$NASM $KERNEL/$f -o $OBJDIR/${f/.s/.o}"
	echo $cmd ; `$cmd`
	if [ $? -ne 0 ]
	then exit;
	fi
    done


    flist=`cd $KERNEL/; ls *.c;`
    `cd ../`
    for f in $flist;
    do
	cmd="$GCC $CFLAGS -c $KERNEL/$f -o $OBJDIR/${f/.c/.o}"
            #echo $cmd;
	`$cmd`;
	if [ $? -ne 0 ]
	then exit;
	fi
    done

    mkdir ./objs/usr;
    $GCC -I./inc -DUSR -fno-builtin -fno-stack-protector -nostdinc -c ./usr/string.c -o $USEROBJDIR/string.o;
    $GCC -I./inc -DUSR -fno-builtin -fno-stack-protector -nostdinc  -c ./usr/init.c -o $USEROBJDIR/init.o;
    $GCC -I./inc -fno-builtin -fno-stack-protector -nostdinc -c ./usr/clib.c -o $USEROBJDIR/clib.o;
    $GCC -I./inc -fno-builtin -fno-stack-protector -nostdinc -c ./usr/sh.c -o $USEROBJDIR/sh.o;

    $NASM -f elf ./usr/entry.s -o $USEROBJDIR/entry.o;
    $LD $USEROBJDIR/entry.o $USEROBJDIR/clib.o  $USEROBJDIR/string.o $USEROBJDIR/init.o  -e _start -o $USEROBJDIR/init -T $TOOL/user.ld;
    $LD $USEROBJDIR/entry.o $USEROBJDIR/clib.o  $USEROBJDIR/string.o $USEROBJDIR/sh.o  -e _start -o $USEROBJDIR/sh -T $TOOL/user.ld;

    do_link;
}

do_link() {
    echo "linking ..."
    cd  $OBJDIR;
    $LD boot.O -o boot.bin -T ../$TOOL/boot.ld;
    $LD setup.O -o setup.bin -T ../$TOOL/setup.ld;

    #head.O must puted at first
    objs=`ls *.o`
    #cmd="$LD head.O $objs -b binary initcode -o kernel.bin -T ../$TOOL/kernel.ld"
    $LD -m elf_i386 -T ../$TOOL/kernel.ld -o kernel.elf head.O $objs;

    #$OBJDUMP -t kernel.bin | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > kernel.sym
    $OBJCPY -R .pdr -R .comment -R .note -S -O binary kernel.elf kernel.bin;

    if [ $? -ne 0 ]
    then
	echo "link error!"
	exit
    else
	echo "making a.img"
	cmd="cat boot.bin setup.bin kernel.bin > ../a.img"
	echo $cmd; cat boot.bin setup.bin kernel.bin > ../a.img;
	ls -lh kernel.bin;
	cd ../;
    fi
}

do_prepare_hd() {
    `$ON_GCC ./tool/mkfs.c -o ./tool/mkfs.exe`
    rm -rf hd.img;
    echo "making hard disk"
    #bximage hd.img -hd -mode=flat -size=10 -q;
    cp $USEROBJDIR/init $USEROBJDIR/sh ./;
    ./tool/mkfs.exe hd.img README init sh;
    rm -rf init;
    #fi
}

do_all() {
    do_clean && do_compile ;
    do_prepare_hd;
    if [ -f "a.img" ]
    then
        if [ $1 == "qemu" ] 
        then 
	    #$QEMU -no-kqemu -fda a.img -hda hd.img -m 128 -localtime -d exec,cpu,pcall;
            #$QEMU -fda a.img -hda fs.img -localtime -m 128;
	    $QEMU -hdb hd.img -fda a.img -localtime -m 128;

        else
     	    $BOCHS -f $BOCHS_CONF -q;
        fi
    fi
}

do_commit() {
    cmd="git commit -a -m\"$log\""
    echo $cmd
    do_clean;
    git add .;
    git commit -a -m"$log"
    git push;
}

show_help() {
    echo "-clean|x   : do clean"
    echo "-compile|c : do compile"
    echo "-all|a     : do above two, and run simulation"
    echo "-commit|u  : do git commit"
    echo "-line|l    : do count code line :)"
}

do_wc_line() {
    find ./ -name *.[chs] -or -name *.asm| xargs cat | wc -l;
}

while [ $# -gt 0 ]
do
    case $1 in
        -all|-a)     do_all "qemu";  exit 0;;
        -clean|-x)   do_clean;       exit 0;;
        -compile|-c) do_clean;       do_compile; exit 0;;
        -commit |-u) shift; log=$1;  do_commit;  exit 0;;
        -line |-l)   do_wc_line;     exit 0;;
        -qemu|-q)    do_all "qemu";  exit 0;;
        -bochs|-b)   do_all "bochs"; exit 0;
    esac
    shift
done


do_all "qemu";
show_help;
