
// @Name   : timer.c 
//
// @Author : Yukang Chen (moorekang@gmail.com)
// @Date   : 2012-01-05 22:46:52
//
// @Brief  :

#include <system.h>
#include <string.h>
#include <asm.h>
#include <time.h>
#include <timer.h>
#include <task.h>

u32 get_sys_ticks(void)
{
    acquire_lock(&timer.lock);
    u32 ticks = timer.ticks;
    release_lock(&timer.lock);
    return ticks;
}

static void timer_callback(void)
{
    acquire_lock(&timer.lock);
    timer.ticks++;
    do_wakeup(&timer);
    release_lock(&timer.lock);
    if (timer.ticks%18 == 0) {
        cli();
        update_time();
        sti();
        //print_time_local();
    }
#if 1
    if(timer.ticks%10 == 0){
        sched();
    }
#endif
}

void timer_init() {
    puts("[time] .... ");
    // Firstly, register our timer callback.
    memset(&timer, 0, sizeof(timer));
    init_lock(&timer.lock, "timer");
    irq_enable(0);
    irq_install_handler(32, (isq_t)(&timer_callback));

    // The value we send to the PIT is the value to divide it's input clock
    // (1193180 Hz) by, to get our required frequency. Important to note is
    // that the divisor must be small enough to fit into 16-bits.
    u32 divisor = 1193180 / 100;

    // Send the command byte.
    outb(0x43, 0x36);

    // Divisor has to be sent byte-wise, so split here into upper/lower bytes.
    u8 l = (u8)(divisor & 0xFF);
    u8 h = (u8)(divisor>>8);

    // Send the frequency divisor.
    outb(0x40, l);
    outb(0x40, h);
    done();
}


/* This will continuously loop until the given time has
*  been reached */
void timer_wait(int wait) {
    unsigned long end_tic;

    end_tic = timer.ticks + wait;
    while(timer.ticks < end_tic);
}
