@echo off
yasm memtimer.asm -o memtimer.bin
yasm onetimer.asm -o onetimer.bin
yasm mtd.asm -o mtd.com -l mtd.lst
yasm refresh_timer.asm -o refresh_timer.bin -l refresh_timer.lst
yasm refresh_one.asm -o refresh_one.bin
