
// @Name   : main.c 
//
// @Author : Yukang Chen (moorekang@gmail.com)
// @Date   : 2012-01-03 17:33:50
//
// @Brief  : The kernel main entry point

#include <asm.h>
#include <cpu.h>
#include <screen.h>
#include <string.h>
#include <page.h>
#include <kheap.h>
#include <hd.h>
#include <test.h>
#include <task.h>
#include <time.h>

u32 init_esp_start;

void kmain(u32 init_stack)
{
    init_esp_start = init_stack;
    
    init_video();
    puts_color_str("Booting Panda OS ...\n", 0x0B);
    puts_color_str("Welcome ...\n", 0x0A);
    
    cli();
    
    time_init();    
    gdt_init();
    idt_init();
    timer_init();
    kb_init();
    mm_init();
    init_hd();
//    init_task();
    
    sti();

    int init = 0;
    while(1) {
        if(!init) {
            init = 1;
            printk("kernel running ...\n");
        }
    }
}
